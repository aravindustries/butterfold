from __future__ import annotations

from pathlib import Path
import math

import numpy as np

N = 128
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS

NUM_TWO_POINT_TESTS = 8
NUM_FFT3_TESTS = 8
NUM_DFT12_TESTS = 8
NUM_FFT128_TESTS = 5
NUM_IFFT128_TESTS = 5
SEED = 20260805

CMD_FFT2 = 0x40
CMD_FFT128 = 0x41
CMD_IFFT128 = 0x42
CMD_IFFT2 = 0x43
CMD_FFT3 = 0x44
CMD_DFT12 = 0x45

FFT3_COEFF_RE = 0
FFT3_COEFF_IM = -111  # round(-sqrt(3)/2 * 128)

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


def bit_reverse7(value: int) -> int:
    result = 0
    for bit in range(7):
        result |= ((value >> bit) & 1) << (6 - bit)
    return result


def generate_twiddles() -> tuple[np.ndarray, np.ndarray]:
    twiddle_re = np.zeros(N // 2, dtype=np.int64)
    twiddle_im = np.zeros(N // 2, dtype=np.int64)

    for k in range(N // 2):
        angle = -2.0 * math.pi * k / N
        twiddle_re[k] = max(-128, min(127, round(math.cos(angle) * SCALE)))
        twiddle_im[k] = max(-128, min(127, round(math.sin(angle) * SCALE)))

    with (
        (VECTOR_DIR / "fft128_twiddle_re.hex").open("w", encoding="utf-8") as re_file,
        (VECTOR_DIR / "fft128_twiddle_im.hex").open("w", encoding="utf-8") as im_file,
    ):
        for re, im in zip(twiddle_re, twiddle_im, strict=True):
            re_file.write(hex_signed(int(re), 8) + "\n")
            im_file.write(hex_signed(int(im), 8) + "\n")

    return twiddle_re, twiddle_im


def shared_complex_multiply(
    data_i: int,
    data_q: int,
    coeff_re: int,
    coeff_im: int,
) -> tuple[int, int]:
    """Mirror the mixed-radix core's 8x17 complex multiplier."""
    data_i = wrap_signed(data_i, 17)
    data_q = wrap_signed(data_q, 17)
    coeff_re = wrap_signed(coeff_re, 8)
    coeff_im = wrap_signed(coeff_im, 8)

    product_rr = wrap_signed(coeff_re * data_i, 25)
    product_iq = wrap_signed(coeff_im * data_q, 25)
    product_rq = wrap_signed(coeff_re * data_q, 25)
    product_ii = wrap_signed(coeff_im * data_i, 25)

    product_re_wide = wrap_signed(product_rr - product_iq, 26)
    product_im_wide = wrap_signed(product_rq + product_ii, 26)

    product_re_scaled = wrap_signed(product_re_wide >> FRAC_BITS, 26)
    product_im_scaled = wrap_signed(product_im_wide >> FRAC_BITS, 26)
    return product_re_scaled, product_im_scaled


def radix2_butterfly(
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
    twiddle_re: int,
    twiddle_im: int,
) -> tuple[int, int, int, int]:
    x0_i = wrap_signed(x0_i, 16)
    x0_q = wrap_signed(x0_q, 16)
    x1_i = wrap_signed(x1_i, 16)
    x1_q = wrap_signed(x1_q, 16)

    product_i, product_q = shared_complex_multiply(
        x1_i, x1_q, twiddle_re, twiddle_im
    )

    return (
        wrap_signed(x0_i + product_i, 16),
        wrap_signed(x0_q + product_q, 16),
        wrap_signed(x0_i - product_i, 16),
        wrap_signed(x0_q - product_q, 16),
    )


def radix3_butterfly(
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
    x2_i: int,
    x2_q: int,
) -> tuple[int, int, int, int, int, int]:
    """Mirror the fixed-point FFT3 identity used by the RTL."""
    x0_i = wrap_signed(x0_i, 16)
    x0_q = wrap_signed(x0_q, 16)
    x1_i = wrap_signed(x1_i, 16)
    x1_q = wrap_signed(x1_q, 16)
    x2_i = wrap_signed(x2_i, 16)
    x2_q = wrap_signed(x2_q, 16)

    sum_i = wrap_signed(x1_i + x2_i, 17)
    sum_q = wrap_signed(x1_q + x2_q, 17)
    diff_i = wrap_signed(x1_i - x2_i, 17)
    diff_q = wrap_signed(x1_q - x2_q, 17)

    half_sum_i = wrap_signed(sum_i >> 1, 17)
    half_sum_q = wrap_signed(sum_q >> 1, 17)

    product_i, product_q = shared_complex_multiply(
        diff_i,
        diff_q,
        FFT3_COEFF_RE,
        FFT3_COEFF_IM,
    )

    base_i = x0_i - half_sum_i
    base_q = x0_q - half_sum_q

    return (
        wrap_signed(x0_i + sum_i, 16),
        wrap_signed(x0_q + sum_q, 16),
        wrap_signed(base_i + product_i, 16),
        wrap_signed(base_q + product_q, 16),
        wrap_signed(base_i - product_i, 16),
        wrap_signed(base_q - product_q, 16),
    )


def two_point_model(
    command: int,
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
) -> tuple[int, int, int, int]:
    result = radix2_butterfly(
        x0_i,
        x0_q,
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


def transform128_model(
    input_i: np.ndarray,
    input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
    inverse: bool,
) -> tuple[np.ndarray, np.ndarray]:
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
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = -128
                    twiddle_im = 0
                elif inverse and int(twiddle_im_rom[twiddle_index]) == -128:
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                    if inverse:
                        twiddle_im = wrap_signed(-twiddle_im, 8)

                X0_i, X0_q, X1_i, X1_q = radix2_butterfly(
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
        ram_i = np.asarray([wrap_signed(int(value) >> 7, 16) for value in ram_i])
        ram_q = np.asarray([wrap_signed(int(value) >> 7, 16) for value in ram_q])

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


def make_fft3_tests(rng: np.random.Generator):
    directed = [
        (64, 0, 0, 0, 0, 0),       # impulse
        (32, -16, 32, -16, 32, -16), # DC
        (64, 0, -32, 55, -32, -55),  # approximate bin-1 tone
        (-128, 127, 127, -128, 0, 1),
    ]
    tests = list(directed)
    while len(tests) < NUM_FFT3_TESTS:
        values = rng.integers(-128, 128, size=6, dtype=np.int16)
        tests.append(tuple(int(value) for value in values))
    return tests


def dft12_input_address(n1: int, n2: int) -> int:
    """Good-Thomas input CRT map n=4*n1+9*n2 mod 12."""
    return (4 * n1 + 9 * n2) % 12


def dft12_output_address(k1: int, k2: int) -> int:
    """Good-Thomas output CRT map k=4*k1+3*k2 mod 12."""
    return (4 * k1 + 3 * k2) % 12


def unity_radix2(
    x0_i: int, x0_q: int, x1_i: int, x1_q: int
) -> tuple[int, int, int, int]:
    """Exact W=+1 using the RTL's W=-1, x1=-x1 proxy."""
    return radix2_butterfly(
        x0_i,
        x0_q,
        wrap_signed(-x1_i, 16),
        wrap_signed(-x1_q, 16),
        -128,
        0,
    )


def dft12_model(
    input_i: np.ndarray, input_q: np.ndarray
) -> tuple[np.ndarray, np.ndarray]:
    """Mirror the scheduler's 3x4 Good-Thomas fixed-point schedule."""
    ram_i = np.asarray([wrap_signed(int(v), 16) for v in input_i], dtype=np.int64)
    ram_q = np.asarray([wrap_signed(int(v), 16) for v in input_q], dtype=np.int64)

    # Four 3-point DFTs. B[k1,n2] is stored at 4*k1+n2.
    for n2 in range(4):
        addresses = [dft12_input_address(n1, n2) for n1 in range(3)]
        result = radix3_butterfly(
            int(ram_i[addresses[0]]), int(ram_q[addresses[0]]),
            int(ram_i[addresses[1]]), int(ram_q[addresses[1]]),
            int(ram_i[addresses[2]]), int(ram_q[addresses[2]]),
        )
        for k1 in range(3):
            ram_i[4 * k1 + n2] = result[2 * k1]
            ram_q[4 * k1 + n2] = result[2 * k1 + 1]

    output_i = np.zeros(12, dtype=np.int64)
    output_q = np.zeros(12, dtype=np.int64)

    # Three FFT4s, each realized by four radix-2 butterflies.
    for k1 in range(3):
        base = 4 * k1

        # First FFT4 stage: (a0,a2) and (a1,a3), both unity twiddles.
        a0 = unity_radix2(
            int(ram_i[base]), int(ram_q[base]),
            int(ram_i[base + 2]), int(ram_q[base + 2]),
        )
        ram_i[base], ram_q[base], ram_i[base + 2], ram_q[base + 2] = a0

        a1 = unity_radix2(
            int(ram_i[base + 1]), int(ram_q[base + 1]),
            int(ram_i[base + 3]), int(ram_q[base + 3]),
        )
        ram_i[base + 1], ram_q[base + 1], ram_i[base + 3], ram_q[base + 3] = a1

        # Final even bins k2=0 and k2=2 use unity.
        even = unity_radix2(
            int(ram_i[base]), int(ram_q[base]),
            int(ram_i[base + 1]), int(ram_q[base + 1]),
        )
        even_addresses = [
            dft12_output_address(k1, 0),
            dft12_output_address(k1, 2),
        ]
        output_i[even_addresses[0]] = even[0]
        output_q[even_addresses[0]] = even[1]
        output_i[even_addresses[1]] = even[2]
        output_q[even_addresses[1]] = even[3]

        # Final odd bins k2=1 and k2=3 use W4^1=-j.
        odd = radix2_butterfly(
            int(ram_i[base + 2]), int(ram_q[base + 2]),
            int(ram_i[base + 3]), int(ram_q[base + 3]),
            0, -128,
        )
        odd_addresses = [
            dft12_output_address(k1, 1),
            dft12_output_address(k1, 3),
        ]
        output_i[odd_addresses[0]] = odd[0]
        output_q[odd_addresses[0]] = odd[1]
        output_i[odd_addresses[1]] = odd[2]
        output_q[odd_addresses[1]] = odd[3]

    return output_i.astype(np.int16), output_q.astype(np.int16)


def make_dft12_tests(rng: np.random.Generator):
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    impulse_i = np.zeros(12, dtype=np.int16)
    impulse_q = np.zeros(12, dtype=np.int16)
    impulse_i[0] = 64
    tests.append((impulse_i, impulse_q))

    tests.append((
        np.full(12, 16, dtype=np.int16),
        np.full(12, -8, dtype=np.int16),
    ))

    n = np.arange(12)
    tone = 0.5 * np.exp(1j * 2.0 * math.pi * 5 * n / 12)
    tests.append((q17(tone.real), q17(tone.imag)))

    alternating_i = np.asarray([64 if n % 2 == 0 else -64 for n in range(12)], dtype=np.int16)
    tests.append((alternating_i, np.zeros(12, dtype=np.int16)))

    while len(tests) < NUM_DFT12_TESTS:
        tests.append((
            q17(rng.uniform(-1.0, 1.0, size=12)),
            q17(rng.uniform(-1.0, 1.0, size=12)),
        ))
    return tests


def write_dft12_vectors(tests) -> None:
    squared_error = 0.0
    max_error = 0.0
    total_bins = 0

    with (
        (VECTOR_DIR / "dft12_inputs.hex").open("w", encoding="utf-8") as input_file,
        (VECTOR_DIR / "dft12_expected.hex").open("w", encoding="utf-8") as expected_file,
        (VECTOR_DIR / "dft12_numpy_reference.csv").open("w", encoding="utf-8") as numpy_file,
    ):
        numpy_file.write("test,index,reference_real,reference_imag,rtl_real,rtl_imag\n")

        for test_index, (input_i, input_q) in enumerate(tests):
            output_i, output_q = dft12_model(input_i, input_q)

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
            reference = np.fft.fft(quantized_input)
            rtl_output = (
                output_i.astype(np.float64) + 1j * output_q.astype(np.float64)
            ) / SCALE
            error = rtl_output - reference
            squared_error += float(np.sum(np.abs(error) ** 2))
            max_error = max(max_error, float(np.max(np.abs(error))))
            total_bins += 12

            for index in range(12):
                numpy_file.write(
                    f"{test_index},{index},"
                    f"{reference[index].real:.12g},{reference[index].imag:.12g},"
                    f"{rtl_output[index].real:.12g},{rtl_output[index].imag:.12g}\n"
                )

    print(
        f"dft12: RMS complex error={math.sqrt(squared_error / total_bins):.6f}, "
        f"max={max_error:.6f}"
    )


def make_fft128_tests(rng: np.random.Generator):
    tests: list[tuple[np.ndarray, np.ndarray]] = []
    impulse_i = np.zeros(N, dtype=np.int16)
    impulse_q = np.zeros(N, dtype=np.int16)
    impulse_i[0] = 64
    tests.append((impulse_i, impulse_q))

    tests.append((np.full(N, 16, dtype=np.int16), np.full(N, -8, dtype=np.int16)))

    n = np.arange(N)
    tone = 0.5 * np.exp(1j * 2.0 * math.pi * 7 * n / N)
    tests.append((q17(tone.real), q17(tone.imag)))

    while len(tests) < NUM_FFT128_TESTS:
        tests.append((
            q17(rng.uniform(-1.0, 1.0, size=N)),
            q17(rng.uniform(-1.0, 1.0, size=N)),
        ))
    return tests


def make_ifft128_tests(rng: np.random.Generator):
    tests: list[tuple[np.ndarray, np.ndarray]] = []
    tests.append((np.full(N, 64, dtype=np.int16), np.zeros(N, dtype=np.int16)))
    tests.append((np.full(N, 16, dtype=np.int16), np.full(N, -8, dtype=np.int16)))

    one_bin_i = np.zeros(N, dtype=np.int16)
    one_bin_q = np.zeros(N, dtype=np.int16)
    one_bin_i[7] = 127
    one_bin_q[7] = 32
    tests.append((one_bin_i, one_bin_q))

    while len(tests) < NUM_IFFT128_TESTS:
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


def write_fft3_vectors(tests) -> None:
    squared_error = 0.0
    max_error = 0.0
    total_bins = 0

    with (
        (VECTOR_DIR / "fft3_inputs.hex").open("w", encoding="utf-8") as input_file,
        (VECTOR_DIR / "fft3_expected.hex").open("w", encoding="utf-8") as expected_file,
        (VECTOR_DIR / "fft3_numpy_reference.csv").open("w", encoding="utf-8") as numpy_file,
    ):
        numpy_file.write("test,index,reference_real,reference_imag,rtl_real,rtl_imag\n")

        for test_index, values in enumerate(tests):
            result = radix3_butterfly(*values)
            input_file.write("".join(hex_signed(value, 8) for value in values) + "\n")
            expected_file.write("".join(hex_signed(value, 16) for value in result) + "\n")

            samples = np.asarray([
                complex(values[0], values[1]),
                complex(values[2], values[3]),
                complex(values[4], values[5]),
            ]) / SCALE
            reference = np.fft.fft(samples)
            rtl = np.asarray([
                complex(result[0], result[1]),
                complex(result[2], result[3]),
                complex(result[4], result[5]),
            ]) / SCALE
            error = rtl - reference
            squared_error += float(np.sum(np.abs(error) ** 2))
            max_error = max(max_error, float(np.max(np.abs(error))))
            total_bins += 3

            for index in range(3):
                numpy_file.write(
                    f"{test_index},{index},"
                    f"{reference[index].real:.12g},{reference[index].imag:.12g},"
                    f"{rtl[index].real:.12g},{rtl[index].imag:.12g}\n"
                )

    print(
        "fft3: RMS complex error="
        f"{math.sqrt(squared_error / total_bins):.6f}, max={max_error:.6f}"
    )


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
            output_i, output_q = transform128_model(
                input_i, input_q, tw_re, tw_im, inverse=inverse
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

    print(
        f"{prefix}: RMS complex error={math.sqrt(squared_error / total_bins):.6f}, "
        f"max={max_error:.6f}"
    )


def main() -> None:
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    twiddle_re, twiddle_im = generate_twiddles()
    two_point_tests = make_two_point_tests(rng)
    fft3_tests = make_fft3_tests(rng)
    dft12_tests = make_dft12_tests(rng)
    fft128_tests = make_fft128_tests(rng)
    ifft128_tests = make_ifft128_tests(rng)

    write_two_point_vectors(two_point_tests)
    write_fft3_vectors(fft3_tests)
    write_dft12_vectors(dft12_tests)
    write_block_vectors("fft128", fft128_tests, twiddle_re, twiddle_im, inverse=False)
    write_block_vectors("ifft128", ifft128_tests, twiddle_re, twiddle_im, inverse=True)

    print(f"Generated {NUM_TWO_POINT_TESTS} mixed FFT2/IFFT2 tests")
    print(f"Generated {NUM_FFT3_TESTS} FFT3 tests")
    print(f"Generated {NUM_DFT12_TESTS} DFT12 tests")
    print(f"Generated {NUM_FFT128_TESTS} FFT128 tests")
    print(f"Generated {NUM_IFFT128_TESTS} IFFT128 tests")


if __name__ == "__main__":
    main()
