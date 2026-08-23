from __future__ import annotations

from pathlib import Path
import math

import numpy as np

N = 64
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS

NUM_TWO_POINT_TESTS = 8
NUM_FFT64_TESTS = 5
NUM_IFFT64_TESTS = 5
SEED = 20260805

CMD_FFT2 = 0x40
CMD_FFT64 = 0x41
CMD_IFFT64 = 0x42
CMD_IFFT2 = 0x43

VECTOR_DIR = Path("vectors")


def wrap_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def hex_signed(value: int, bits: int) -> str:
    digits = (bits + 3) // 4
    return f"{value & ((1 << bits) - 1):0{digits}x}"


def q17(value: np.ndarray | float) -> np.ndarray:
    scaled = np.round(np.asarray(value, dtype=np.float64) * SCALE)
    return np.clip(scaled, -128, 127).astype(np.int16)


def bit_reverse6(value: int) -> int:
    result = 0
    for bit in range(6):
        result |= ((value >> bit) & 1) << (5 - bit)
    return result


def generate_twiddles() -> tuple[np.ndarray, np.ndarray]:
    twiddle_re = np.zeros(N // 2, dtype=np.int64)
    twiddle_im = np.zeros(N // 2, dtype=np.int64)

    for k in range(N // 2):
        angle = -2.0 * math.pi * k / N
        twiddle_re[k] = max(-128, min(127, round(math.cos(angle) * SCALE)))
        twiddle_im[k] = max(-128, min(127, round(math.sin(angle) * SCALE)))

    with (
        (VECTOR_DIR / "fft64_twiddle_re.hex").open("w", encoding="utf-8") as re_file,
        (VECTOR_DIR / "fft64_twiddle_im.hex").open("w", encoding="utf-8") as im_file,
    ):
        for re, im in zip(twiddle_re, twiddle_im, strict=True):
            re_file.write(hex_signed(int(re), 8) + "\n")
            im_file.write(hex_signed(int(im), 8) + "\n")

    return twiddle_re, twiddle_im


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

    X0_i = wrap_signed(x0_i + tw_x1_re_scaled, 16)
    X0_q = wrap_signed(x0_q + tw_x1_im_scaled, 16)
    X1_i = wrap_signed(x0_i - tw_x1_re_scaled, 16)
    X1_q = wrap_signed(x0_q - tw_x1_im_scaled, 16)

    return X0_i, X0_q, X1_i, X1_q


def two_point_model(
    command: int,
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
) -> tuple[int, int, int, int]:
    # Exact unity proxy used by the scheduler: x1 is negated and W=-1.
    result = rtl_butterfly(
        wrap_signed(x0_i, 16),
        wrap_signed(x0_q, 16),
        wrap_signed(-x1_i, 16),
        wrap_signed(-x1_q, 16),
        -128,
        0,
    )

    if command == CMD_IFFT2:
        return tuple(wrap_signed(value >> 1, 16) for value in result)

    if command != CMD_FFT2:
        raise ValueError(f"Unsupported two-point command: 0x{command:02x}")

    return result


def transform64_model(
    input_i: np.ndarray,
    input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
    inverse: bool,
) -> tuple[np.ndarray, np.ndarray]:
    ram_i = np.zeros(N, dtype=np.int64)
    ram_q = np.zeros(N, dtype=np.int64)

    for sample_index in range(N):
        address = bit_reverse6(sample_index)
        ram_i[address] = wrap_signed(int(input_i[sample_index]), 16)
        ram_q[address] = wrap_signed(int(input_q[sample_index]), 16)

    for stage in range(6):
        half_size = 1 << stage
        group_size = 2 << stage

        for group_base in range(0, N, group_size):
            for j in range(half_size):
                addr0 = group_base + j
                addr1 = addr0 + half_size
                twiddle_index = j << (5 - stage)

                x0_i = int(ram_i[addr0])
                x0_q = int(ram_q[addr0])
                x1_i = int(ram_i[addr1])
                x1_q = int(ram_q[addr1])

                if twiddle_index == 0:
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = -128
                    twiddle_im = 0
                elif inverse and int(twiddle_im_rom[twiddle_index]) == -128:
                    # Desired inverse twiddle is +j. Use (-j)*(-x1).
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                    if inverse:
                        twiddle_im = wrap_signed(-twiddle_im, 8)

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

    if inverse:
        ram_i = np.asarray([wrap_signed(int(value) >> 6, 16) for value in ram_i])
        ram_q = np.asarray([wrap_signed(int(value) >> 6, 16) for value in ram_q])

    return ram_i.astype(np.int16), ram_q.astype(np.int16)


def make_two_point_tests(rng: np.random.Generator):
    directed = [
        (CMD_FFT2, 64, -32, 32, 16),
        (CMD_IFFT2, 64, -32, 32, 16),
        (CMD_FFT2, -128, 127, 127, -128),
        (CMD_IFFT2, -128, 127, 127, -128),
    ]

    tests = list(directed)
    while len(tests) < NUM_TWO_POINT_TESTS:
        command = CMD_FFT2 if len(tests) % 2 == 0 else CMD_IFFT2
        values = rng.integers(-128, 128, size=4, dtype=np.int16)
        tests.append((command, *(int(value) for value in values)))
    return tests


def make_fft64_tests(rng: np.random.Generator):
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    impulse_i = np.zeros(N, dtype=np.int16)
    impulse_q = np.zeros(N, dtype=np.int16)
    impulse_i[0] = 64
    tests.append((impulse_i, impulse_q))

    dc_i = np.full(N, 16, dtype=np.int16)
    dc_q = np.full(N, -8, dtype=np.int16)
    tests.append((dc_i, dc_q))

    n = np.arange(N)
    tone = 0.5 * np.exp(1j * 2.0 * math.pi * 7 * n / N)
    tests.append((q17(tone.real), q17(tone.imag)))

    while len(tests) < NUM_FFT64_TESTS:
        tests.append((
            q17(rng.uniform(-1.0, 1.0, size=N)),
            q17(rng.uniform(-1.0, 1.0, size=N)),
        ))

    return tests


def make_ifft64_tests(rng: np.random.Generator):
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    constant_i = np.full(N, 64, dtype=np.int16)
    constant_q = np.zeros(N, dtype=np.int16)
    tests.append((constant_i, constant_q))

    complex_constant_i = np.full(N, 16, dtype=np.int16)
    complex_constant_q = np.full(N, -8, dtype=np.int16)
    tests.append((complex_constant_i, complex_constant_q))

    one_bin_i = np.zeros(N, dtype=np.int16)
    one_bin_q = np.zeros(N, dtype=np.int16)
    one_bin_i[7] = 127
    one_bin_q[7] = 32
    tests.append((one_bin_i, one_bin_q))

    while len(tests) < NUM_IFFT64_TESTS:
        tests.append((
            q17(rng.uniform(-1.0, 1.0, size=N)),
            q17(rng.uniform(-1.0, 1.0, size=N)),
        ))

    return tests


def write_two_point_vectors(tests) -> None:
    with (
        (VECTOR_DIR / "two_point_commands.hex").open("w", encoding="utf-8") as command_file,
        (VECTOR_DIR / "two_point_inputs.hex").open("w", encoding="utf-8") as input_file,
        (VECTOR_DIR / "two_point_expected.hex").open("w", encoding="utf-8") as expected_file,
    ):
        for command, x0_i, x0_q, x1_i, x1_q in tests:
            result = two_point_model(command, x0_i, x0_q, x1_i, x1_q)
            command_file.write(hex_signed(command, 8) + "\n")
            input_file.write(
                hex_signed(x0_i, 8)
                + hex_signed(x0_q, 8)
                + hex_signed(x1_i, 8)
                + hex_signed(x1_q, 8)
                + "\n"
            )
            expected_file.write("".join(hex_signed(value, 16) for value in result) + "\n")


def write_block_vectors(prefix: str, tests, tw_re, tw_im, inverse: bool) -> None:
    input_path = VECTOR_DIR / f"{prefix}_inputs.hex"
    expected_path = VECTOR_DIR / f"{prefix}_expected.hex"
    numpy_path = VECTOR_DIR / f"{prefix}_numpy_reference.csv"

    squared_error = 0.0
    max_error = 0.0
    total_bins = 0

    with (
        input_path.open("w", encoding="utf-8") as input_file,
        expected_path.open("w", encoding="utf-8") as expected_file,
        numpy_path.open("w", encoding="utf-8") as numpy_file,
    ):
        numpy_file.write("test,index,reference_real,reference_imag,rtl_real,rtl_imag\n")

        for test_index, (input_i, input_q) in enumerate(tests):
            output_i, output_q = transform64_model(
                input_i,
                input_q,
                tw_re,
                tw_im,
                inverse=inverse,
            )

            for i_value, q_value in zip(input_i, input_q, strict=True):
                input_file.write(
                    hex_signed(int(i_value), 8)
                    + hex_signed(int(q_value), 8)
                    + "\n"
                )

            for i_value, q_value in zip(output_i, output_q, strict=True):
                expected_file.write(
                    hex_signed(int(i_value), 16)
                    + hex_signed(int(q_value), 16)
                    + "\n"
                )

            quantized_input = (
                input_i.astype(np.float64) + 1j * input_q.astype(np.float64)
            ) / SCALE
            reference = np.fft.ifft(quantized_input) if inverse else np.fft.fft(quantized_input)
            rtl_output = (
                output_i.astype(np.float64) + 1j * output_q.astype(np.float64)
            ) / SCALE
            error = rtl_output - reference
            squared_error += float(np.sum(np.abs(error) ** 2))
            max_error = max(max_error, float(np.max(np.abs(error))))
            total_bins += N

            for index in range(N):
                numpy_file.write(
                    f"{test_index},{index},"
                    f"{reference[index].real:.12g},{reference[index].imag:.12g},"
                    f"{rtl_output[index].real:.12g},{rtl_output[index].imag:.12g}\n"
                )

    rms_error = math.sqrt(squared_error / total_bins)
    print(f"{prefix}: RMS complex error={rms_error:.6f}, max={max_error:.6f}")


def main() -> None:
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    twiddle_re, twiddle_im = generate_twiddles()

    two_point_tests = make_two_point_tests(rng)
    fft64_tests = make_fft64_tests(rng)
    ifft64_tests = make_ifft64_tests(rng)

    write_two_point_vectors(two_point_tests)
    write_block_vectors("fft64", fft64_tests, twiddle_re, twiddle_im, inverse=False)
    write_block_vectors("ifft64", ifft64_tests, twiddle_re, twiddle_im, inverse=True)

    print(f"Generated {NUM_TWO_POINT_TESTS} mixed FFT2/IFFT2 tests")
    print(f"Generated {NUM_FFT64_TESTS} FFT64 tests")
    print(f"Generated {NUM_IFFT64_TESTS} IFFT64 tests")


if __name__ == "__main__":
    main()
