from __future__ import annotations

from pathlib import Path
import math

import numpy as np

N = 128
NUM_TESTS = 5
SEED = 1234
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS

VECTOR_DIR = Path("vectors")
INPUT_PATH = VECTOR_DIR / "fft128_inputs.hex"
EXPECTED_PATH = VECTOR_DIR / "fft128_expected.hex"
NUMPY_PATH = VECTOR_DIR / "fft128_numpy_reference.csv"
TWIDDLE_RE_PATH = VECTOR_DIR / "fft128_twiddle_re.hex"
TWIDDLE_IM_PATH = VECTOR_DIR / "fft128_twiddle_im.hex"


def wrap_signed(value: int, bits: int) -> int:
    """Wrap an integer to a signed two's-complement value of the given width."""
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def hex_signed(value: int, bits: int) -> str:
    """Format a signed integer as fixed-width two's-complement hexadecimal."""
    digits = (bits + 3) // 4
    return f"{value & ((1 << bits) - 1):0{digits}x}"


def q17(value: np.ndarray | float) -> np.ndarray:
    """Quantize floating-point values to signed 8-bit Q1.7 integer codes."""
    return np.clip(np.round(np.asarray(value) * SCALE), -128, 127).astype(np.int16)


def bit_reverse7(value: int) -> int:
    result = 0
    for bit in range(7):
        result |= ((value >> bit) & 1) << (6 - bit)
    return result


def load_twiddle_file(path: Path) -> np.ndarray:
    values: list[int] = []
    with path.open("r", encoding="utf-8") as file:
        for line in file:
            token = line.strip()
            if token:
                values.append(wrap_signed(int(token, 16), 8))

    if len(values) != N // 2:
        raise ValueError(f"Expected 64 entries in {path}, found {len(values)}")

    return np.asarray(values, dtype=np.int64)


def rtl_butterfly(
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
    twiddle_re: int,
    twiddle_im: int,
) -> tuple[int, int, int, int]:
    """Mirror the fixed-width arithmetic in two_point_dft exactly."""
    x0_i = wrap_signed(x0_i, 16)
    x0_q = wrap_signed(x0_q, 16)
    x1_i = wrap_signed(x1_i, 16)
    x1_q = wrap_signed(x1_q, 16)
    twiddle_re = wrap_signed(twiddle_re, 8)
    twiddle_im = wrap_signed(twiddle_im, 8)

    # Four signed 8x16 products stored in 24 bits.
    product_rr = wrap_signed(twiddle_re * x1_i, 24)
    product_iq = wrap_signed(twiddle_im * x1_q, 24)
    product_rq = wrap_signed(twiddle_re * x1_q, 24)
    product_ii = wrap_signed(twiddle_im * x1_i, 24)

    # Complex product add/subtract stored in 25 bits with 14 fractional bits.
    tw_x1_re_wide = wrap_signed(product_rr - product_iq, 25)
    tw_x1_im_wide = wrap_signed(product_rq + product_ii, 25)

    # Arithmetic right shift restores seven fractional bits.
    tw_x1_re_scaled = wrap_signed(tw_x1_re_wide >> FRAC_BITS, 25)
    tw_x1_im_scaled = wrap_signed(tw_x1_im_wide >> FRAC_BITS, 25)

    # The RTL forms 26-bit butterfly temporaries, then retains bits [15:0].
    x0_out_i = wrap_signed(x0_i + tw_x1_re_scaled, 26)
    x0_out_q = wrap_signed(x0_q + tw_x1_im_scaled, 26)
    x1_out_i = wrap_signed(x0_i - tw_x1_re_scaled, 26)
    x1_out_q = wrap_signed(x0_q - tw_x1_im_scaled, 26)

    return (
        wrap_signed(x0_out_i, 16),
        wrap_signed(x0_out_q, 16),
        wrap_signed(x1_out_i, 16),
        wrap_signed(x1_out_q, 16),
    )


def fft128_rtl_model(
    input_i: np.ndarray,
    input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """Run the same bit-reversed-input, iterative radix-2 DIT schedule as RTL."""
    if input_i.shape != (N,) or input_q.shape != (N,):
        raise ValueError("FFT128 model requires exactly 128 complex samples")

    ram_i = np.zeros(N, dtype=np.int64)
    ram_q = np.zeros(N, dtype=np.int64)

    # Scheduler writes natural-order input into bit-reversed RAM addresses.
    for sample_index in range(N):
        address = bit_reverse7(sample_index)
        ram_i[address] = wrap_signed(int(input_i[sample_index]), 16)
        ram_q[address] = wrap_signed(int(input_q[sample_index]), 16)

    for stage in range(7):
        half_size = 1 << stage
        group_size = 2 << stage

        for group_base in range(0, N, group_size):
            for j in range(half_size):
                addr0 = group_base + j
                addr1 = addr0 + half_size
                twiddle_index = j << (6 - stage)

                x0_i = int(ram_i[addr0])
                x0_q = int(ram_q[addr0])
                x1_i = int(ram_i[addr1])
                x1_q = int(ram_q[addr1])

                if twiddle_index == 0:
                    # Exact unity proxy used by the scheduler:
                    # W=-1 and x1=-x1, so W*x1 equals the original x1.
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = -128
                    twiddle_im = 0
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])

                X0_i, X0_q, X1_i, X1_q = rtl_butterfly(
                    x0_i,
                    x0_q,
                    x1_i,
                    x1_q,
                    twiddle_re,
                    twiddle_im,
                )

                ram_i[addr0] = X0_i
                ram_q[addr0] = X0_q
                ram_i[addr1] = X1_i
                ram_q[addr1] = X1_q

    return ram_i.astype(np.int16), ram_q.astype(np.int16)


def make_test_inputs(rng: np.random.Generator) -> list[tuple[np.ndarray, np.ndarray]]:
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    # Test 0: real impulse. Every output bin should be identical.
    impulse_i = np.zeros(N, dtype=np.int16)
    impulse_q = np.zeros(N, dtype=np.int16)
    impulse_i[0] = 64  # +0.5
    tests.append((impulse_i, impulse_q))

    # Test 1: complex DC input. Only bin zero should be large ideally.
    dc_i = np.full(N, 16, dtype=np.int16)   # +0.125
    dc_q = np.full(N, -8, dtype=np.int16)   # -0.0625
    tests.append((dc_i, dc_q))

    # Test 2: quantized complex tone at bin 7.
    n = np.arange(N)
    tone = 0.5 * np.exp(1j * 2.0 * math.pi * 7 * n / N)
    tests.append((q17(tone.real), q17(tone.imag)))

    # Tests 3 and 4: random full-range Q1.7 complex samples.
    while len(tests) < NUM_TESTS:
        random_i = q17(rng.uniform(-1.0, 1.0, size=N))
        random_q = q17(rng.uniform(-1.0, 1.0, size=N))
        tests.append((random_i, random_q))

    return tests


def main() -> None:
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    if not TWIDDLE_RE_PATH.exists() or not TWIDDLE_IM_PATH.exists():
        raise FileNotFoundError(
            "Generate fft128_twiddle_re.hex and fft128_twiddle_im.hex first"
        )

    twiddle_re_rom = load_twiddle_file(TWIDDLE_RE_PATH)
    twiddle_im_rom = load_twiddle_file(TWIDDLE_IM_PATH)

    rng = np.random.default_rng(SEED)
    tests = make_test_inputs(rng)

    total_squared_error = 0.0
    maximum_error = 0.0
    total_components = 0

    with (
        INPUT_PATH.open("w", encoding="utf-8") as input_file,
        EXPECTED_PATH.open("w", encoding="utf-8") as expected_file,
        NUMPY_PATH.open("w", encoding="utf-8") as numpy_file,
    ):
        numpy_file.write("test,bin,reference_real,reference_imag,rtl_real,rtl_imag\n")

        for test_index, (input_i, input_q) in enumerate(tests):
            output_i, output_q = fft128_rtl_model(
                input_i,
                input_q,
                twiddle_re_rom,
                twiddle_im_rom,
            )

            # Each input line is one complex 8-bit sample: IIQQ.
            for sample_index in range(N):
                input_file.write(
                    hex_signed(int(input_i[sample_index]), 8)
                    + hex_signed(int(input_q[sample_index]), 8)
                    + "\n"
                )

            # Each expected line is one complex 16-bit output bin: IIIIQQQQ.
            for bin_index in range(N):
                expected_file.write(
                    hex_signed(int(output_i[bin_index]), 16)
                    + hex_signed(int(output_q[bin_index]), 16)
                    + "\n"
                )

            quantized_input = (
                input_i.astype(np.float64)
                + 1j * input_q.astype(np.float64)
            ) / SCALE
            numpy_reference = np.fft.fft(quantized_input)
            rtl_complex = (
                output_i.astype(np.float64)
                + 1j * output_q.astype(np.float64)
            ) / SCALE

            error = rtl_complex - numpy_reference
            total_squared_error += float(np.sum(np.abs(error) ** 2))
            maximum_error = max(maximum_error, float(np.max(np.abs(error))))
            total_components += N

            for bin_index in range(N):
                numpy_file.write(
                    f"{test_index},{bin_index},"
                    f"{numpy_reference[bin_index].real:.12g},"
                    f"{numpy_reference[bin_index].imag:.12g},"
                    f"{rtl_complex[bin_index].real:.12g},"
                    f"{rtl_complex[bin_index].imag:.12g}\n"
                )

    rms_complex_error = math.sqrt(total_squared_error / total_components)

    print(f"Generated {NUM_TESTS} FFT128 tests")
    print(f"Input vectors:       {INPUT_PATH}")
    print(f"Bit-accurate golden: {EXPECTED_PATH}")
    print(f"NumPy comparison:    {NUMPY_PATH}")
    print(f"RMS complex error versus np.fft: {rms_complex_error:.6f}")
    print(f"Maximum complex error versus np.fft: {maximum_error:.6f}")


if __name__ == "__main__":
    main()
