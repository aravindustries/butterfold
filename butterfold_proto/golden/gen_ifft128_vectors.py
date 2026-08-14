from __future__ import annotations

from pathlib import Path
import math

import numpy as np

N = 128
NUM_TESTS = 5
SEED = 5678
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS

VECTOR_DIR = Path("vectors")
INPUT_PATH = VECTOR_DIR / "ifft128_inputs.hex"
EXPECTED_PATH = VECTOR_DIR / "ifft128_expected.hex"
NUMPY_PATH = VECTOR_DIR / "ifft128_numpy_reference.csv"
TWIDDLE_RE_PATH = VECTOR_DIR / "fft128_twiddle_re.hex"
TWIDDLE_IM_PATH = VECTOR_DIR / "fft128_twiddle_im.hex"


def wrap_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def hex_signed(value: int, bits: int) -> str:
    digits = (bits + 3) // 4
    return f"{value & ((1 << bits) - 1):0{digits}x}"


def q17(value: np.ndarray | float) -> np.ndarray:
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
    """Mirror two_point_dft fixed-width arithmetic exactly."""
    x0_i = wrap_signed(x0_i, 16)
    x0_q = wrap_signed(x0_q, 16)
    x1_i = wrap_signed(x1_i, 16)
    x1_q = wrap_signed(x1_q, 16)
    twiddle_re = wrap_signed(twiddle_re, 8)
    twiddle_im = wrap_signed(twiddle_im, 8)

    product_rr = wrap_signed(twiddle_re * x1_i, 24)
    product_iq = wrap_signed(twiddle_im * x1_q, 24)
    product_rq = wrap_signed(twiddle_re * x1_q, 24)
    product_ii = wrap_signed(twiddle_im * x1_i, 24)

    tw_x1_re_wide = wrap_signed(product_rr - product_iq, 25)
    tw_x1_im_wide = wrap_signed(product_rq + product_ii, 25)

    tw_x1_re_scaled = wrap_signed(tw_x1_re_wide >> FRAC_BITS, 25)
    tw_x1_im_scaled = wrap_signed(tw_x1_im_wide >> FRAC_BITS, 25)

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


def ifft128_rtl_model(
    input_i: np.ndarray,
    input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """Mirror the scheduler's bit-reversed-input radix-2 IFFT128 schedule."""
    if input_i.shape != (N,) or input_q.shape != (N,):
        raise ValueError("IFFT128 model requires exactly 128 complex samples")

    ram_i = np.zeros(N, dtype=np.int64)
    ram_q = np.zeros(N, dtype=np.int64)

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
                    # Desired inverse twiddle is +1. Use W=-1 and -x1.
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = -128
                    twiddle_im = 0
                elif int(twiddle_im_rom[twiddle_index]) == -128:
                    # Desired inverse twiddle is +j at index 32. Use W=-j
                    # and -x1 so that (-j)*(-x1) = (+j)*x1.
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = wrap_signed(-int(twiddle_im_rom[twiddle_index]), 8)

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

    # Conventional IFFT normalization: divide by 128 after all seven stages.
    output_i = np.asarray([wrap_signed(int(value) >> 7, 16) for value in ram_i], dtype=np.int16)
    output_q = np.asarray([wrap_signed(int(value) >> 7, 16) for value in ram_q], dtype=np.int16)
    return output_i, output_q


def make_test_inputs(rng: np.random.Generator) -> list[tuple[np.ndarray, np.ndarray]]:
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    # Test 0: constant spectrum. IFFT should concentrate at time sample zero.
    const_i = np.full(N, 64, dtype=np.int16)
    const_q = np.zeros(N, dtype=np.int16)
    tests.append((const_i, const_q))

    # Test 1: complex constant spectrum.
    complex_const_i = np.full(N, 16, dtype=np.int16)
    complex_const_q = np.full(N, -8, dtype=np.int16)
    tests.append((complex_const_i, complex_const_q))

    # Test 2: a single occupied spectral bin exercises inverse twiddle signs.
    one_bin_i = np.zeros(N, dtype=np.int16)
    one_bin_q = np.zeros(N, dtype=np.int16)
    one_bin_i[7] = 127
    one_bin_q[7] = 32
    tests.append((one_bin_i, one_bin_q))

    # Tests 3 and 4: random full-range Q1.7 spectra.
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
    total_bins = 0

    with (
        INPUT_PATH.open("w", encoding="utf-8") as input_file,
        EXPECTED_PATH.open("w", encoding="utf-8") as expected_file,
        NUMPY_PATH.open("w", encoding="utf-8") as numpy_file,
    ):
        numpy_file.write("test,sample,reference_real,reference_imag,rtl_real,rtl_imag\n")

        for test_index, (input_i, input_q) in enumerate(tests):
            output_i, output_q = ifft128_rtl_model(
                input_i,
                input_q,
                twiddle_re_rom,
                twiddle_im_rom,
            )

            for sample_index in range(N):
                input_file.write(
                    hex_signed(int(input_i[sample_index]), 8)
                    + hex_signed(int(input_q[sample_index]), 8)
                    + "\n"
                )

            for sample_index in range(N):
                expected_file.write(
                    hex_signed(int(output_i[sample_index]), 16)
                    + hex_signed(int(output_q[sample_index]), 16)
                    + "\n"
                )

            quantized_input = (
                input_i.astype(np.float64)
                + 1j * input_q.astype(np.float64)
            ) / SCALE
            numpy_reference = np.fft.ifft(quantized_input)
            rtl_complex = (
                output_i.astype(np.float64)
                + 1j * output_q.astype(np.float64)
            ) / SCALE

            error = rtl_complex - numpy_reference
            total_squared_error += float(np.sum(np.abs(error) ** 2))
            maximum_error = max(maximum_error, float(np.max(np.abs(error))))
            total_bins += N

            for sample_index in range(N):
                numpy_file.write(
                    f"{test_index},{sample_index},"
                    f"{numpy_reference[sample_index].real:.12g},"
                    f"{numpy_reference[sample_index].imag:.12g},"
                    f"{rtl_complex[sample_index].real:.12g},"
                    f"{rtl_complex[sample_index].imag:.12g}\n"
                )

    rms_complex_error = math.sqrt(total_squared_error / total_bins)

    print(f"Generated {NUM_TESTS} IFFT128 tests")
    print(f"Input vectors:       {INPUT_PATH}")
    print(f"Bit-accurate golden: {EXPECTED_PATH}")
    print(f"NumPy comparison:    {NUMPY_PATH}")
    print(f"RMS complex error versus np.ifft: {rms_complex_error:.6f}")
    print(f"Maximum complex error versus np.ifft: {maximum_error:.6f}")


if __name__ == "__main__":
    main()
