from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Iterable

from .config import NRConfig, SweepSpace, first_ge, milestone_configs
from .cycle_model import CycleAssumptions, core_time_us, evaluate_case_requirements
from .fixed_point import FixedPointConfig
from .waveform import compare_folded_vs_golden


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

    return TDDTimingResult(
        tx_time_s=tx_time_s,
        rx_time_s=rx_time_s,
        combined_time_s=combined_time_s,
        tx_pass=tx_pass,
        rx_pass=rx_pass,
        half_duplex_pass=half_duplex_pass,
        required_guard_symbols=required_guard_symbols,
        required_guard_time_s=required_guard_symbols * cfg.symbol_time_s,
    )


def assumptions_to_fixed_cfg(assumptions: CycleAssumptions) -> FixedPointConfig:
    _ = assumptions
    return FixedPointConfig(enabled=True, iq_scale=127.0, twiddle_scale=127.0)


def to_mhz(value_hz: float | None) -> float | None:
    if value_hz is None:
        return None
    return value_hz / 1e6


def evaluate_config(
    cfg: NRConfig,
    sweep: SweepSpace,
    assumptions: CycleAssumptions,
    include_correctness: bool = False,
) -> dict[str, Any]:
    req = evaluate_case_requirements(cfg, assumptions)

    core_grid = sweep.core_grid()
    io_grid = sweep.io_grid()

    needed_core_hz = max(
        req["required_clk_core_tx_hz"],
        req["required_clk_core_rx_hz"],
        req["required_clk_core_half_hz"],
    )
    clk_core_hz = first_ge(core_grid, needed_core_hz)
    clk_io_hz = first_ge(io_grid, req["required_clk_io_hz"])

    if clk_core_hz is not None:
        tdd = evaluate_tdd_timing(
            cfg=cfg,
            clk_core_hz=clk_core_hz,
            tx_cycles=req["tx_cycles"]["total_cycles"],
            rx_cycles=req["rx_cycles"]["total_cycles"],
        )
        tx_us = core_time_us(req["tx_cycles"]["total_cycles"], clk_core_hz)
        rx_us = core_time_us(req["rx_cycles"]["total_cycles"], clk_core_hz)
    else:
        tdd = None
        tx_us = None
        rx_us = None

    if clk_core_hz is None or clk_io_hz is None or (tdd is not None and not tdd.half_duplex_pass):
        pass_fail = "FAIL"
    else:
        pass_fail = "PASS"

    result: dict[str, Any] = {
        "scs_khz": cfg.scs_khz,
        "m": cfg.m,
        "k": cfg.k,
        "clk_core_hz": clk_core_hz,
        "clk_io_hz": clk_io_hz,
        "clk_core_mhz": to_mhz(clk_core_hz),
        "clk_io_mhz": to_mhz(clk_io_hz),
        "tx_cycles": req["tx_cycles"]["total_cycles"],
        "rx_cycles": req["rx_cycles"]["total_cycles"],
        "tx_us": tx_us,
        "rx_us": rx_us,
        "pass_fail": pass_fail,
        "required_clk_core_tx_hz": req["required_clk_core_tx_hz"],
        "required_clk_core_rx_hz": req["required_clk_core_rx_hz"],
        "required_clk_core_half_hz": req["required_clk_core_half_hz"],
        "required_clk_io_hz": req["required_clk_io_hz"],
        "tdd": tdd,
    }

    if include_correctness:
        result["correctness"] = compare_folded_vs_golden(
            k=cfg.k,
            m=cfg.m,
            cp_len=cfg.cp_len,
            fixed_cfg=assumptions_to_fixed_cfg(assumptions),
            seed=1,
        )

    return result


def run_sweep(
    sweep: SweepSpace,
    assumptions: CycleAssumptions | None = None,
    include_correctness: bool = False,
) -> list[dict[str, Any]]:
    if assumptions is None:
        assumptions = CycleAssumptions()

    rows: list[dict[str, Any]] = []
    for cfg in sweep.configs():
        if cfg.k > cfg.m:
            continue
        rows.append(
            evaluate_config(
                cfg=cfg,
                sweep=sweep,
                assumptions=assumptions,
                include_correctness=include_correctness,
            )
        )
    return rows


def _fmt_mhz(v_hz: float | None) -> str:
    if v_hz is None:
        return "N/A"
    return f"{v_hz / 1e6:.2f}"


def _table(headers: list[str], rows: Iterable[list[str]]) -> str:
    all_rows = list(rows)
    widths = [len(h) for h in headers]
    for row in all_rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt_row(row: list[str]) -> str:
        return " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(row))

    out = [fmt_row(headers), "-+-".join("-" * w for w in widths)]
    out.extend(fmt_row(r) for r in all_rows)
    return "\n".join(out)


def run_milestone_report() -> str:
    assumptions = CycleAssumptions()
    fx_cfg = FixedPointConfig(enabled=True, iq_scale=127.0, twiddle_scale=127.0)

    headers = [
        "SCS(kHz)",
        "m",
        "k",
        "Req clk_io (MHz)",
        "Req clk_core TX (MHz)",
        "Req clk_core RX (MHz)",
        "Req clk_core half-duplex (MHz)",
        "Req guard sym",
        "EVM(%)",
        "Max err",
        "RMS err",
        "Bit mismatches",
        "PAPR in/out (dB)",
        "TX cycles",
        "RX cycles",
    ]

    rows: list[list[str]] = []
    for cfg in milestone_configs():
        req = evaluate_case_requirements(cfg, assumptions)
        clk_core_half = req["required_clk_core_half_hz"]
        tdd = evaluate_tdd_timing(
            cfg=cfg,
            clk_core_hz=clk_core_half,
            tx_cycles=req["tx_cycles"]["total_cycles"],
            rx_cycles=req["rx_cycles"]["total_cycles"],
        )
        corr = compare_folded_vs_golden(
            k=cfg.k,
            m=cfg.m,
            cp_len=cfg.cp_len,
            fixed_cfg=fx_cfg,
            seed=1,
        )
        rows.append(
            [
                str(cfg.scs_khz),
                str(cfg.m),
                str(cfg.k),
                _fmt_mhz(req["required_clk_io_hz"]),
                _fmt_mhz(req["required_clk_core_tx_hz"]),
                _fmt_mhz(req["required_clk_core_rx_hz"]),
                _fmt_mhz(req["required_clk_core_half_hz"]),
                str(tdd.required_guard_symbols),
                f"{corr.evm_percent:.5f}",
                f"{corr.max_error:.3e}",
                f"{corr.rms_error:.3e}",
                str(corr.bit_exact_mismatch_count),
                f"{corr.papr_input_db:.2f}/{corr.papr_output_db:.2f}",
                str(req["tx_cycles"]["total_cycles"]),
                str(req["rx_cycles"]["total_cycles"]),
            ]
        )

    return "\n".join(
        [
            "ButterFold Milestone: k=12, m=128, SCS=15/30/60 kHz",
            _table(headers, rows),
        ]
    )


def run_full_report() -> str:
    sweep = SweepSpace()
    rows = run_sweep(sweep=sweep, assumptions=CycleAssumptions(), include_correctness=False)

    headers = [
        "SCS",
        "m",
        "k",
        "clk_core(MHz)",
        "clk_io(MHz)",
        "TX cycles",
        "RX cycles",
        "TX us",
        "RX us",
        "pass/fail",
    ]

    table_rows: list[list[str]] = []
    for row in rows:
        tx_us = "N/A" if row["tx_us"] is None else f"{row['tx_us']:.2f}"
        rx_us = "N/A" if row["rx_us"] is None else f"{row['rx_us']:.2f}"
        table_rows.append(
            [
                str(row["scs_khz"]),
                str(row["m"]),
                str(row["k"]),
                "N/A" if row["clk_core_mhz"] is None else f"{row['clk_core_mhz']:.2f}",
                "N/A" if row["clk_io_mhz"] is None else f"{row['clk_io_mhz']:.2f}",
                str(row["tx_cycles"]),
                str(row["rx_cycles"]),
                tx_us,
                rx_us,
                row["pass_fail"],
            ]
        )

    return _table(headers, table_rows)
