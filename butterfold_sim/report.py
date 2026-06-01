from __future__ import annotations

from typing import Iterable

from .config import SweepSpace, milestone_configs
from .cycle_model import CycleAssumptions, evaluate_case_requirements
from .fixed_point import FixedPointConfig
from .sweep import run_sweep
from .tdd_timing import evaluate_tdd_timing
from .waveform import compare_folded_vs_golden


def _fmt_mhz(v_hz: float | None) -> str:
    if v_hz is None:
        return "N/A"
    return f"{v_hz / 1e6:.2f}"


def _fmt_us(v_s: float) -> str:
    return f"{v_s * 1e6:.2f}"


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
    for r in rows:
        tx_us = "N/A" if r["tx_us"] is None else f"{r['tx_us']:.2f}"
        rx_us = "N/A" if r["rx_us"] is None else f"{r['rx_us']:.2f}"
        table_rows.append(
            [
                str(r["scs_khz"]),
                str(r["m"]),
                str(r["k"]),
                "N/A" if r["clk_core_mhz"] is None else f"{r['clk_core_mhz']:.2f}",
                "N/A" if r["clk_io_mhz"] is None else f"{r['clk_io_mhz']:.2f}",
                str(r["tx_cycles"]),
                str(r["rx_cycles"]),
                tx_us,
                rx_us,
                r["pass_fail"],
            ]
        )

    return _table(headers, table_rows)
