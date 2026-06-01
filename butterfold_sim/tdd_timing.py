from __future__ import annotations

import math
from dataclasses import dataclass

from .config import NRConfig


@dataclass(frozen=True)
class TDDTimingResult:
    tx_time_s: float
    rx_time_s: float
    combined_time_s: float
    tx_pass: bool
    rx_pass: bool
    half_duplex_pass: bool
    required_guard_symbols: int
    required_guard_time_s: float


def evaluate_tdd_timing(
    cfg: NRConfig,
    clk_core_hz: float,
    tx_cycles: int,
    rx_cycles: int,
) -> TDDTimingResult:
    tx_time_s = tx_cycles / clk_core_hz
    rx_time_s = rx_cycles / clk_core_hz
    switch_time_s = cfg.switch_cycles / clk_core_hz

    tx_pass = tx_time_s <= cfg.tx_deadline_s
    rx_pass = rx_time_s <= cfg.rx_deadline_s

    combined_time_s = tx_time_s + rx_time_s + switch_time_s
    half_duplex_pass = combined_time_s <= cfg.half_duplex_window_s

    free_window_without_guard = (cfg.tx_window_symbols + cfg.rx_window_symbols) * cfg.symbol_time_s
    extra_time_needed = max(0.0, combined_time_s - free_window_without_guard)

    if cfg.symbol_time_s <= 0:
        required_guard_symbols = 0
    else:
        required_guard_symbols = int(math.ceil(extra_time_needed / cfg.symbol_time_s))

    required_guard_time_s = required_guard_symbols * cfg.symbol_time_s

    return TDDTimingResult(
        tx_time_s=tx_time_s,
        rx_time_s=rx_time_s,
        combined_time_s=combined_time_s,
        tx_pass=tx_pass,
        rx_pass=rx_pass,
        half_duplex_pass=half_duplex_pass,
        required_guard_symbols=required_guard_symbols,
        required_guard_time_s=required_guard_time_s,
    )
