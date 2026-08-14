from __future__ import annotations

from pathlib import Path
import math
import csv

import numpy as np

N = 128
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS
NUM_TESTS = 4
SEED = 20260806
NORMAL_CP = 9
EXTENDED_CP = 10

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


def fft128_fixed(
    input_i: np.ndarray,
    input_q: np.ndarray,
    twiddle_re_rom: np.ndarray,
    twiddle_im_rom: np.ndarray,
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
                else:
                    twiddle_re = int(twiddle_re_rom[twiddle_index])
                    twiddle_im = int(twiddle_im_rom[twiddle_index])

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

    return ram_i.astype(np.int16), ram_q.astype(np.int16)


def saturate8(value: int) -> int:
    return max(-128, min(127, int(value)))


def make_useful_blocks(rng: np.random.Generator) -> list[tuple[np.ndarray, np.ndarray]]:
    blocks: list[tuple[np.ndarray, np.ndarray]] = []

    # Impulse: all FFT bins should contain the same value.
    impulse_i = np.zeros(N, dtype=np.int16)
    impulse_q = np.zeros(N, dtype=np.int16)
    impulse_i[0] = 64
    blocks.append((impulse_i, impulse_q))

    # Low-amplitude complex tone at bin 7.
    n = np.arange(N)
    tone = 0.20 * np.exp(1j * 2.0 * np.pi * 7 * n / N)
    tone_i = np.clip(np.round(tone.real * SCALE), -128, 127).astype(np.int16)
    tone_q = np.clip(np.round(tone.imag * SCALE), -128, 127).astype(np.int16)
    blocks.append((tone_i, tone_q))

    # Low-amplitude random block to exercise twiddles without widespread saturation.
    blocks.append((
        rng.integers(-16, 17, size=N, dtype=np.int16),
        rng.integers(-16, 17, size=N, dtype=np.int16),
    ))

    # High DC block deliberately exercises silent output saturation.
    blocks.append((
        np.full(N, 64, dtype=np.int16),
        np.full(N, -48, dtype=np.int16),
    ))

    return blocks


def write_mode(
    name: str,
    cp_length: int,
    useful_blocks: list[tuple[np.ndarray, np.ndarray]],
    rng: np.random.Generator,
    twiddle_re: np.ndarray,
    twiddle_im: np.ndarray,
) -> None:
    input_path = VECTOR_DIR / f"ofdm_rx_{name}_inputs.hex"
    expected_path = VECTOR_DIR / f"ofdm_rx_{name}_expected.hex"
    numpy_path = VECTOR_DIR / f"ofdm_rx_{name}_numpy_reference.csv"

    with (
        input_path.open("w", encoding="utf-8") as input_file,
        expected_path.open("w", encoding="utf-8") as expected_file,
        numpy_path.open("w", newline="", encoding="utf-8") as numpy_file,
    ):
        csv_writer = csv.writer(numpy_file)
        csv_writer.writerow([
            "test", "bin", "rtl_i_code", "rtl_q_code",
            "rtl_i_saturated", "rtl_q_saturated",
            "numpy_i", "numpy_q",
        ])

        for test_index, (useful_i, useful_q) in enumerate(useful_blocks):
            cp_i = rng.integers(-128, 128, size=cp_length, dtype=np.int16)
            cp_q = rng.integers(-128, 128, size=cp_length, dtype=np.int16)

            for i_code, q_code in zip(cp_i, cp_q, strict=True):
                input_file.write(
                    hex_signed(int(i_code), 8) + hex_signed(int(q_code), 8) + "\n"
                )
            for i_code, q_code in zip(useful_i, useful_q, strict=True):
                input_file.write(
                    hex_signed(int(i_code), 8) + hex_signed(int(q_code), 8) + "\n"
                )

            fft_i, fft_q = fft128_fixed(
                useful_i,
                useful_q,
                twiddle_re,
                twiddle_im,
            )
            numpy_fft = np.fft.fft(
                useful_i.astype(np.float64) / SCALE
                + 1j * useful_q.astype(np.float64) / SCALE
            )

            for bin_index in range(N):
                sat_i = saturate8(int(fft_i[bin_index]))
                sat_q = saturate8(int(fft_q[bin_index]))
                expected_file.write(
                    hex_signed(sat_i, 8) + hex_signed(sat_q, 8) + "\n"
                )
                csv_writer.writerow([
                    test_index,
                    bin_index,
                    int(fft_i[bin_index]),
                    int(fft_q[bin_index]),
                    sat_i,
                    sat_q,
                    float(numpy_fft[bin_index].real),
                    float(numpy_fft[bin_index].imag),
                ])


if __name__ == "__main__":
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    twiddle_re, twiddle_im = generate_twiddles()
    blocks = make_useful_blocks(rng)

    write_mode(
        "normal_cp",
        NORMAL_CP,
        blocks,
        rng,
        twiddle_re,
        twiddle_im,
    )
    write_mode(
        "extended_cp",
        EXTENDED_CP,
        blocks,
        rng,
        twiddle_re,
        twiddle_im,
    )

    print(f"Generated {NUM_TESTS} normal-CP and {NUM_TESTS} extended-CP OFDM_RX tests.")
