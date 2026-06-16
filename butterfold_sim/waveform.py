from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .fixed_point import FixedPointConfig, bit_exact_mismatch_count, quantize_complex_stream
from .folded_transforms import mixed_radix_dft, radix2_fft, radix2_ifft


@dataclass
class TxArtifacts:
    spread_symbols: np.ndarray
    grid: np.ndarray
    time_no_cp: np.ndarray
    time_with_cp: np.ndarray


@dataclass
class RxArtifacts:
    spectrum: np.ndarray
    active_bins: np.ndarray
    recovered_symbols: np.ndarray


@dataclass
class WaveformComparison:
    max_error: float
    rms_error: float
    evm_percent: float
    bit_exact_mismatch_count: int
    papr_input_db: float
    papr_after_dft_db: float
    papr_output_db: float
    saturation_count: int


def papr_db(values: np.ndarray) -> float:
    p = np.abs(values) ** 2
    mean_p = float(np.mean(p))
    if mean_p == 0.0:
        return 0.0
    peak_p = float(np.max(p))
    return 10.0 * np.log10(peak_p / mean_p)


def rms_error(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.abs(a - b) ** 2)))


def evm_percent(reference: np.ndarray, measured: np.ndarray) -> float:
    err = measured - reference
    ref_power = np.mean(np.abs(reference) ** 2)
    if ref_power == 0.0:
        return 0.0
    evm = np.sqrt(np.mean(np.abs(err) ** 2) / ref_power)
    return float(100.0 * evm)


def qam_symbols(k: int, order: int = 16, rng: np.random.Generator | None = None) -> np.ndarray:
    if rng is None:
        rng = np.random.default_rng(0)
    if order != 16:
        raise ValueError("Only 16-QAM is implemented in this proof-of-concept")

    levels = np.array([-3, -1, 1, 3], dtype=np.float64)
    i = levels[rng.integers(0, 4, size=k)]
    q = levels[rng.integers(0, 4, size=k)]
    symbols = i + 1j * q
    symbols /= np.sqrt(np.mean(np.abs(symbols) ** 2))
    return symbols


def centered_mapping_start(m: int, k: int) -> int:
    if k > m:
        raise ValueError("k cannot exceed m")
    return (m - k) // 2


def _ofdm_modulate(grid: np.ndarray, cp_len: int, folded: bool) -> tuple[np.ndarray, np.ndarray]:
    if folded:
        time_no_cp = radix2_ifft(grid)
    else:
        time_no_cp = np.fft.ifft(grid)

    if cp_len > 0:
        cp = time_no_cp[-cp_len:]
        time_with_cp = np.concatenate([cp, time_no_cp])
    else:
        time_with_cp = time_no_cp.copy()

    return time_no_cp, time_with_cp


def tx_chain(symbols: np.ndarray, m: int, cp_len: int, folded: bool) -> TxArtifacts:
    """Uplink DFT-s-OFDM TX: DFT -> map -> IFFT -> CP insertion."""
    k = len(symbols)
    if folded:
        spread = mixed_radix_dft(symbols, inverse=False)
    else:
        spread = np.fft.fft(symbols)

    grid = np.zeros(m, dtype=np.complex128)
    start = centered_mapping_start(m, k)
    grid[start : start + k] = spread

    time_no_cp, time_with_cp = _ofdm_modulate(grid, cp_len=cp_len, folded=folded)

    return TxArtifacts(
        spread_symbols=spread,
        grid=grid,
        time_no_cp=time_no_cp,
        time_with_cp=time_with_cp,
    )


def cp_ofdm_downlink_tx_chain(symbols: np.ndarray, m: int, cp_len: int, folded: bool) -> TxArtifacts:
    """Downlink CP-OFDM TX reference used to generate RX test waveforms."""
    k = len(symbols)
    grid = np.zeros(m, dtype=np.complex128)
    start = centered_mapping_start(m, k)
    grid[start : start + k] = symbols
    time_no_cp, time_with_cp = _ofdm_modulate(grid, cp_len=cp_len, folded=folded)
    return TxArtifacts(
        spread_symbols=symbols,
        grid=grid,
        time_no_cp=time_no_cp,
        time_with_cp=time_with_cp,
    )


def rx_chain(time_with_cp: np.ndarray, m: int, k: int, cp_len: int, folded: bool) -> RxArtifacts:
    """Downlink CP-OFDM RX: CP removal -> FFT -> active-bin extraction."""
    if cp_len > 0:
        no_cp = time_with_cp[cp_len: cp_len + m]
    else:
        no_cp = time_with_cp[:m]

    if folded:
        spectrum = radix2_fft(no_cp)
    else:
        spectrum = np.fft.fft(no_cp)

    start = centered_mapping_start(m, k)
    active = spectrum[start : start + k]
    return RxArtifacts(spectrum=spectrum, active_bins=active, recovered_symbols=active)


def compare_folded_vs_golden(
    k: int,
    m: int,
    cp_len: int,
    fixed_cfg: FixedPointConfig,
    seed: int = 0,
) -> WaveformComparison:
    rng = np.random.default_rng(seed)
    symbols = qam_symbols(k, rng=rng)

    tx_golden = tx_chain(symbols, m=m, cp_len=cp_len, folded=False)
    tx_folded = tx_chain(symbols, m=m, cp_len=cp_len, folded=True)

    dl_tx_golden = cp_ofdm_downlink_tx_chain(symbols, m=m, cp_len=cp_len, folded=False)
    dl_tx_folded = cp_ofdm_downlink_tx_chain(symbols, m=m, cp_len=cp_len, folded=True)
    rx_golden = rx_chain(dl_tx_golden.time_with_cp, m=m, k=k, cp_len=cp_len, folded=False)
    rx_folded = rx_chain(dl_tx_folded.time_with_cp, m=m, k=k, cp_len=cp_len, folded=True)

    max_err = float(np.max(np.abs(rx_folded.recovered_symbols - rx_golden.recovered_symbols)))
    rms_err = rms_error(rx_golden.recovered_symbols, rx_folded.recovered_symbols)
    evm = evm_percent(symbols, rx_folded.recovered_symbols)

    saturation_count = 0
    mismatch_count = 0
    if fixed_cfg.enabled:
        folded_bytes, sat_folded = quantize_complex_stream(tx_folded.time_with_cp, scale=fixed_cfg.iq_scale)
        golden_bytes, sat_golden = quantize_complex_stream(tx_golden.time_with_cp, scale=fixed_cfg.iq_scale)
        saturation_count = sat_folded + sat_golden
        mismatch_count = bit_exact_mismatch_count(folded_bytes, golden_bytes)

    return WaveformComparison(
        max_error=max_err,
        rms_error=rms_err,
        evm_percent=evm,
        bit_exact_mismatch_count=mismatch_count,
        papr_input_db=papr_db(symbols),
        papr_after_dft_db=papr_db(tx_folded.spread_symbols),
        papr_output_db=papr_db(tx_folded.time_no_cp),
        saturation_count=saturation_count,
    )
