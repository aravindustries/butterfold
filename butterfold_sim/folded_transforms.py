from __future__ import annotations

import numpy as np


def _is_power_of_two(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


def _bit_reverse_indices(n: int) -> np.ndarray:
    bits = int(np.log2(n))
    idx = np.arange(n, dtype=np.uint32)
    rev = np.zeros_like(idx)
    for _ in range(bits):
        rev = (rev << 1) | (idx & 1)
        idx >>= 1
    return rev.astype(np.int64)


def radix2_fft(values: np.ndarray, inverse: bool = False) -> np.ndarray:
    n = len(values)
    if not _is_power_of_two(n):
        raise ValueError(f"radix2_fft requires power-of-two length, got {n}")

    x = np.asarray(values, dtype=np.complex128).copy()
    x = x[_bit_reverse_indices(n)]

    sign = 1.0 if inverse else -1.0
    m = 2
    while m <= n:
        half = m // 2
        tw = np.exp(sign * 2j * np.pi * np.arange(half) / m)
        for start in range(0, n, m):
            top = x[start : start + half].copy()
            bottom = x[start + half : start + m].copy()
            t = tw * bottom
            x[start : start + half] = top + t
            x[start + half : start + m] = top - t
        m *= 2

    if inverse:
        x /= n
    return x


def radix2_ifft(values: np.ndarray) -> np.ndarray:
    return radix2_fft(values, inverse=True)


def direct_dft(values: np.ndarray, inverse: bool = False) -> np.ndarray:
    x = np.asarray(values, dtype=np.complex128)
    n = len(x)
    idx = np.arange(n)
    sign = 1.0 if inverse else -1.0
    mat = np.exp(sign * 2j * np.pi * np.outer(idx, idx) / n)
    out = mat @ x
    if inverse:
        out /= n
    return out


def mixed_radix_12(values: np.ndarray, inverse: bool = False) -> np.ndarray:
    x = np.asarray(values, dtype=np.complex128)
    if len(x) != 12:
        raise ValueError("mixed_radix_12 requires exactly 12 points")

    # Numerical golden for the 3x4 kernel while cycle model tracks staged costs.
    # This keeps waveform correctness exact until an RTL-matched FSM schedule is plugged in.
    return direct_dft(x, inverse=inverse)


def mixed_radix_dft(values: np.ndarray, inverse: bool = False) -> np.ndarray:
    n = len(values)
    if n == 12:
        return mixed_radix_12(values, inverse=inverse)
    return direct_dft(values, inverse=inverse)
