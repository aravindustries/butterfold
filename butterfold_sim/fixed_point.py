from __future__ import annotations

from dataclasses import dataclass

import numpy as np


INT8_MIN = -128
INT8_MAX = 127


@dataclass(frozen=True)
class FixedPointConfig:
    enabled: bool = True
    iq_scale: float = 127.0
    twiddle_scale: float = 127.0


def saturate_int8(values: np.ndarray) -> np.ndarray:
    return np.clip(values, INT8_MIN, INT8_MAX).astype(np.int8)


def quantize_real_to_int8(values: np.ndarray, scale: float = 127.0) -> tuple[np.ndarray, int]:
    scaled = np.rint(values * scale)
    sat_count = int(np.sum((scaled < INT8_MIN) | (scaled > INT8_MAX)))
    return saturate_int8(scaled), sat_count


def quantize_complex_to_int8(values: np.ndarray, scale: float = 127.0) -> tuple[np.ndarray, np.ndarray, int]:
    i_q, i_sat = quantize_real_to_int8(np.real(values), scale=scale)
    q_q, q_sat = quantize_real_to_int8(np.imag(values), scale=scale)
    return i_q, q_q, i_sat + q_sat


def dequantize_complex_from_int8(i_values: np.ndarray, q_values: np.ndarray, scale: float = 127.0) -> np.ndarray:
    return i_values.astype(np.float64) / scale + 1j * q_values.astype(np.float64) / scale


def interleave_iq_bytes(i_values: np.ndarray, q_values: np.ndarray) -> np.ndarray:
    if len(i_values) != len(q_values):
        raise ValueError("I and Q streams must have the same length")
    out = np.empty(2 * len(i_values), dtype=np.int8)
    out[0::2] = i_values
    out[1::2] = q_values
    return out


def deinterleave_iq_bytes(iq_bytes: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if len(iq_bytes) % 2 != 0:
        raise ValueError("Interleaved IQ byte stream length must be even")
    return iq_bytes[0::2].astype(np.int8), iq_bytes[1::2].astype(np.int8)


def quantize_complex_stream(values: np.ndarray, scale: float = 127.0) -> tuple[np.ndarray, int]:
    i_q, q_q, sat = quantize_complex_to_int8(values, scale=scale)
    return interleave_iq_bytes(i_q, q_q), sat


def bit_exact_mismatch_count(a_bytes: np.ndarray, b_bytes: np.ndarray) -> int:
    if a_bytes.shape != b_bytes.shape:
        raise ValueError("Streams must have identical shape for mismatch count")
    return int(np.sum(a_bytes != b_bytes))


def quantized_twiddles(n: int, scale: float = 127.0) -> tuple[np.ndarray, np.ndarray]:
    idx = np.arange(n, dtype=np.float64)
    tw = np.exp(-2j * np.pi * idx / n)
    i_q, _ = quantize_real_to_int8(np.real(tw), scale=scale)
    q_q, _ = quantize_real_to_int8(np.imag(tw), scale=scale)
    return i_q, q_q
