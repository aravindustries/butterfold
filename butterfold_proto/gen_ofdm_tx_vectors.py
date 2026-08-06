from __future__ import annotations

from pathlib import Path
import csv
import math

import numpy as np

N = 128
M = 12
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS
NUM_TESTS = 5
SEED = 20260806
NORMAL_CP = 9
EXTENDED_CP = 10
SC_START_BIN = 1
FFT3_COEFF_RE = 0
FFT3_COEFF_IM = -111

VECTOR_DIR = Path("vectors")


def wrap_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def hex_signed(value: int, bits: int) -> str:
    digits = (bits + 3) // 4
    return f"{value & ((1 << bits) - 1):0{digits}x}"


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
        for re_value, im_value in zip(twiddle_re, twiddle_im, strict=True):
            re_file.write(hex_signed(int(re_value), 8) + "\n")
            im_file.write(hex_signed(int(im_value), 8) + "\n")

    return twiddle_re, twiddle_im


def shared_complex_multiply(
    data_i: int,
    data_q: int,
    coeff_re: int,
    coeff_im: int,
) -> tuple[int, int]:
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

    return (
        wrap_signed(product_re_wide >> FRAC_BITS, 26),
        wrap_signed(product_im_wide >> FRAC_BITS, 26),
    )


def radix2_butterfly(
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
    twiddle_re: int,
    twiddle_im: int,
) -> tuple[int, int, int, int]:
    product_i, product_q = shared_complex_multiply(
        wrap_signed(x1_i, 16),
        wrap_signed(x1_q, 16),
        twiddle_re,
        twiddle_im,
    )

    return (
        wrap_signed(wrap_signed(x0_i, 16) + product_i, 16),
        wrap_signed(wrap_signed(x0_q, 16) + product_q, 16),
        wrap_signed(wrap_signed(x0_i, 16) - product_i, 16),
        wrap_signed(wrap_signed(x0_q, 16) - product_q, 16),
    )


def radix3_butterfly(
    x0_i: int,
    x0_q: int,
    x1_i: int,
    x1_q: int,
    x2_i: int,
    x2_q: int,
) -> tuple[int, int, int, int, int, int]:
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
        diff_i, diff_q, FFT3_COEFF_RE, FFT3_COEFF_IM
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


def unity_radix2(
    x0_i: int, x0_q: int, x1_i: int, x1_q: int
) -> tuple[int, int, int, int]:
    return radix2_butterfly(
        x0_i,
        x0_q,
        wrap_signed(-x1_i, 16),
        wrap_signed(-x1_q, 16),
        -128,
        0,
    )


def dft12_input_address(n1: int, n2: int) -> int:
    return (4 * n1 + 9 * n2) % 12


def dft12_output_address(k1: int, k2: int) -> int:
    return (4 * k1 + 3 * k2) % 12


def dft12_fixed(
    input_i: np.ndarray, input_q: np.ndarray
) -> tuple[np.ndarray, np.ndarray]:
    ram_i = np.asarray([wrap_signed(int(v), 16) for v in input_i], dtype=np.int64)
    ram_q = np.asarray([wrap_signed(int(v), 16) for v in input_q], dtype=np.int64)

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

    output_i = np.zeros(M, dtype=np.int64)
    output_q = np.zeros(M, dtype=np.int64)

    for k1 in range(3):
        base = 4 * k1

        even_stage = unity_radix2(
            int(ram_i[base]), int(ram_q[base]),
            int(ram_i[base + 2]), int(ram_q[base + 2]),
        )
        ram_i[base], ram_q[base], ram_i[base + 2], ram_q[base + 2] = even_stage

        odd_stage = unity_radix2(
            int(ram_i[base + 1]), int(ram_q[base + 1]),
            int(ram_i[base + 3]), int(ram_q[base + 3]),
        )
        ram_i[base + 1], ram_q[base + 1], ram_i[base + 3], ram_q[base + 3] = odd_stage

        final_even = unity_radix2(
            int(ram_i[base]), int(ram_q[base]),
            int(ram_i[base + 1]), int(ram_q[base + 1]),
        )
        addresses = [
            dft12_output_address(k1, 0),
            dft12_output_address(k1, 2),
        ]
        output_i[addresses[0]] = final_even[0]
        output_q[addresses[0]] = final_even[1]
        output_i[addresses[1]] = final_even[2]
        output_q[addresses[1]] = final_even[3]

        final_odd = radix2_butterfly(
            int(ram_i[base + 2]), int(ram_q[base + 2]),
            int(ram_i[base + 3]), int(ram_q[base + 3]),
            0, -128,
        )
        addresses = [
            dft12_output_address(k1, 1),
            dft12_output_address(k1, 3),
        ]
        output_i[addresses[0]] = final_odd[0]
        output_q[addresses[0]] = final_odd[1]
        output_i[addresses[1]] = final_odd[2]
        output_q[addresses[1]] = final_odd[3]

    return output_i.astype(np.int16), output_q.astype(np.int16)


def ifft128_fixed(
    natural_input_i: np.ndarray,
    natural_input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    ram_i = np.zeros(N, dtype=np.int64)
    ram_q = np.zeros(N, dtype=np.int64)

    for sample_index in range(N):
        address = bit_reverse7(sample_index)
        ram_i[address] = wrap_signed(int(natural_input_i[sample_index]), 16)
        ram_q[address] = wrap_signed(int(natural_input_q[sample_index]), 16)

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
                elif int(twiddle_im_rom[twiddle_index]) == -128:
                    x1_i = wrap_signed(-x1_i, 16)
                    x1_q = wrap_signed(-x1_q, 16)
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = wrap_signed(-int(twiddle_im_rom[twiddle_index]), 8)

                X0_i, X0_q, X1_i, X1_q = radix2_butterfly(
                    x0_i, x0_q, x1_i, x1_q, twiddle_re, twiddle_im
                )

                ram_i[addr0] = X0_i
                ram_q[addr0] = X0_q
                ram_i[addr1] = X1_i
                ram_q[addr1] = X1_q

    output_i = np.asarray(
        [wrap_signed(int(value) >> 7, 16) for value in ram_i], dtype=np.int16
    )
    output_q = np.asarray(
        [wrap_signed(int(value) >> 7, 16) for value in ram_q], dtype=np.int16
    )
    return output_i, output_q


def saturate8(value: int) -> int:
    return max(-128, min(127, int(value)))


def make_inputs(rng: np.random.Generator) -> list[tuple[np.ndarray, np.ndarray]]:
    tests: list[tuple[np.ndarray, np.ndarray]] = []

    impulse_i = np.zeros(M, dtype=np.int16)
    impulse_q = np.zeros(M, dtype=np.int16)
    impulse_i[0] = 64
    tests.append((impulse_i, impulse_q))

    constant_i = np.full(M, 32, dtype=np.int16)
    constant_q = np.full(M, -16, dtype=np.int16)
    tests.append((constant_i, constant_q))

    qpsk_i = np.asarray([48 if (k & 1) == 0 else -48 for k in range(M)], dtype=np.int16)
    qpsk_q = np.asarray([48 if (k & 2) == 0 else -48 for k in range(M)], dtype=np.int16)
    tests.append((qpsk_i, qpsk_q))

    ramp_i = np.asarray([8 * k - 44 for k in range(M)], dtype=np.int16)
    ramp_q = np.asarray([36 - 6 * k for k in range(M)], dtype=np.int16)
    tests.append((ramp_i, ramp_q))

    tests.append((
        rng.integers(-96, 97, size=M, dtype=np.int16),
        rng.integers(-96, 97, size=M, dtype=np.int16),
    ))
    return tests


def write_mode(
    name: str,
    cp_length: int,
    tests: list[tuple[np.ndarray, np.ndarray]],
    twiddle_re: np.ndarray,
    twiddle_im: np.ndarray,
) -> None:
    input_path = VECTOR_DIR / f"ofdm_tx_{name}_inputs.hex"
    expected_path = VECTOR_DIR / f"ofdm_tx_{name}_expected.hex"
    numpy_path = VECTOR_DIR / f"ofdm_tx_{name}_numpy_reference.csv"

    with (
        input_path.open("w", encoding="utf-8") as input_file,
        expected_path.open("w", encoding="utf-8") as expected_file,
        numpy_path.open("w", newline="", encoding="utf-8") as numpy_file,
    ):
        csv_writer = csv.writer(numpy_file)
        csv_writer.writerow([
            "test", "output_sample", "rtl_i_code", "rtl_q_code",
            "rtl_i_saturated", "rtl_q_saturated", "numpy_i", "numpy_q",
        ])

        for test_index, (input_i, input_q) in enumerate(tests):
            for i_code, q_code in zip(input_i, input_q, strict=True):
                input_file.write(
                    hex_signed(int(i_code), 8) + hex_signed(int(q_code), 8) + "\n"
                )

            dft_i, dft_q = dft12_fixed(input_i, input_q)
            grid_i = np.zeros(N, dtype=np.int16)
            grid_q = np.zeros(N, dtype=np.int16)
            grid_i[SC_START_BIN:SC_START_BIN + M] = dft_i
            grid_q[SC_START_BIN:SC_START_BIN + M] = dft_q

            time_i, time_q = ifft128_fixed(grid_i, grid_q, twiddle_re, twiddle_im)
            output_indices = list(range(N - cp_length, N)) + list(range(N))

            ideal_input = (
                input_i.astype(np.float64) + 1j * input_q.astype(np.float64)
            ) / SCALE
            ideal_dft = np.fft.fft(ideal_input)
            ideal_grid = np.zeros(N, dtype=np.complex128)
            ideal_grid[SC_START_BIN:SC_START_BIN + M] = ideal_dft
            ideal_time = np.fft.ifft(ideal_grid)

            for output_sample, source_index in enumerate(output_indices):
                sat_i = saturate8(int(time_i[source_index]))
                sat_q = saturate8(int(time_q[source_index]))
                expected_file.write(
                    hex_signed(sat_i, 8) + hex_signed(sat_q, 8) + "\n"
                )
                csv_writer.writerow([
                    test_index,
                    output_sample,
                    int(time_i[source_index]),
                    int(time_q[source_index]),
                    sat_i,
                    sat_q,
                    float(ideal_time[source_index].real),
                    float(ideal_time[source_index].imag),
                ])


if __name__ == "__main__":
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    twiddle_re, twiddle_im = generate_twiddles()
    tests = make_inputs(rng)

    write_mode("normal_cp", NORMAL_CP, tests, twiddle_re, twiddle_im)
    write_mode("extended_cp", EXTENDED_CP, tests, twiddle_re, twiddle_im)

    print(
        f"Generated {NUM_TESTS} normal-CP and {NUM_TESTS} extended-CP "
        f"DFT-s-OFDM TX tests using bins {SC_START_BIN}..{SC_START_BIN + M - 1}."
    )
