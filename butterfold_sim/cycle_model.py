from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from .config import NRConfig


@dataclass(frozen=True)
class CycleAssumptions:
    butterfly_per_cycle: int = 1
    complex_multiply_per_cycle: int = 1
    ram_rw_pair_per_cycle: int = 1
    bytes_per_clk_io: int = 1

    dft12_radix4_stage_cycles: int = 16
    dft12_radix3_stage_cycles: int = 18
    dft12_twiddle_permute_cycles: int = 12


def is_power_of_two(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


def radix2_fft_cycles(n: int, assumptions: CycleAssumptions) -> int:
    if not is_power_of_two(n):
        raise ValueError(f"radix2_fft_cycles expects power-of-two n, got {n}")
    base = (n // 2) * int(math.log2(n))
    return math.ceil(base / assumptions.butterfly_per_cycle)


def dft_cycles(k: int, assumptions: CycleAssumptions) -> int:
    if k == 12:
        return (
            assumptions.dft12_radix4_stage_cycles
            + assumptions.dft12_radix3_stage_cycles
            + assumptions.dft12_twiddle_permute_cycles
        )
    if is_power_of_two(k):
        return radix2_fft_cycles(k, assumptions)

    # Conservative fallback for non-power-of-two DFT sizes.
    mult_cycles = math.ceil((k * k) / assumptions.complex_multiply_per_cycle)
    return mult_cycles


def tx_cycle_breakdown(cfg: NRConfig, assumptions: CycleAssumptions) -> dict[str, int]:
    input_load_cycles = cfg.k
    k_dft_cycles = dft_cycles(cfg.k, assumptions)
    subcarrier_mapping_cycles = cfg.k
    m_ifft_cycles = radix2_fft_cycles(cfg.m, assumptions)
    cp_insert_cycles = cfg.cp_len
    output_stream_cycles = cfg.m + cfg.cp_len

    total = (
        input_load_cycles
        + k_dft_cycles
        + subcarrier_mapping_cycles
        + m_ifft_cycles
        + cp_insert_cycles
        + output_stream_cycles
    )

    return {
        "input_load_cycles": input_load_cycles,
        "k_dft_cycles": k_dft_cycles,
        "subcarrier_mapping_cycles": subcarrier_mapping_cycles,
        "m_ifft_cycles": m_ifft_cycles,
        "cp_insert_cycles": cp_insert_cycles,
        "output_stream_cycles": output_stream_cycles,
        "total_cycles": total,
    }


def rx_cycle_breakdown(cfg: NRConfig, assumptions: CycleAssumptions) -> dict[str, int]:
    input_stream_cycles = cfg.m + cfg.cp_len
    cp_remove_cycles = cfg.cp_len
    m_fft_cycles = radix2_fft_cycles(cfg.m, assumptions)
    subcarrier_extract_cycles = cfg.k
    output_stream_cycles = cfg.k

    total = (
        input_stream_cycles
        + cp_remove_cycles
        + m_fft_cycles
        + subcarrier_extract_cycles
        + output_stream_cycles
    )

    return {
        "input_stream_cycles": input_stream_cycles,
        "cp_remove_cycles": cp_remove_cycles,
        "m_fft_cycles": m_fft_cycles,
        "subcarrier_extract_cycles": subcarrier_extract_cycles,
        "output_stream_cycles": output_stream_cycles,
        "total_cycles": total,
    }


def core_time_us(total_cycles: int, clk_core_hz: float) -> float:
    return 1e6 * total_cycles / clk_core_hz


def required_clk_core_hz(total_cycles: int, deadline_s: float) -> float:
    if deadline_s <= 0:
        return float("inf")
    return total_cycles / deadline_s


def io_requirements(cfg: NRConfig, assumptions: CycleAssumptions) -> dict[str, float]:
    complex_rate_sps = cfg.fs_hz
    byte_rate_Bps = 2.0 * complex_rate_sps
    required_clk_io_hz = byte_rate_Bps / assumptions.bytes_per_clk_io

    symbol_bytes_no_cp = 2 * cfg.m
    symbol_bytes_with_cp = 2 * (cfg.m + cfg.cp_len)

    return {
        "complex_rate_sps": complex_rate_sps,
        "byte_rate_Bps": byte_rate_Bps,
        "required_clk_io_hz": required_clk_io_hz,
        "symbol_bytes_no_cp": float(symbol_bytes_no_cp),
        "symbol_bytes_with_cp": float(symbol_bytes_with_cp),
    }


def evaluate_case_requirements(cfg: NRConfig, assumptions: CycleAssumptions) -> dict[str, Any]:
    tx = tx_cycle_breakdown(cfg, assumptions)
    rx = rx_cycle_breakdown(cfg, assumptions)
    io = io_requirements(cfg, assumptions)

    req_clk_core_tx_hz = required_clk_core_hz(tx["total_cycles"], cfg.tx_deadline_s)
    req_clk_core_rx_hz = required_clk_core_hz(rx["total_cycles"], cfg.rx_deadline_s)
    req_clk_core_half_hz = required_clk_core_hz(
        tx["total_cycles"] + rx["total_cycles"] + cfg.switch_cycles,
        cfg.half_duplex_window_s,
    )

    return {
        "tx_cycles": tx,
        "rx_cycles": rx,
        "io": io,
        "required_clk_core_tx_hz": req_clk_core_tx_hz,
        "required_clk_core_rx_hz": req_clk_core_rx_hz,
        "required_clk_core_half_hz": req_clk_core_half_hz,
        "required_clk_io_hz": io["required_clk_io_hz"],
    }
