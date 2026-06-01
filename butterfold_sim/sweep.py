from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .config import NRConfig, SweepSpace, first_ge
from .cycle_model import CycleAssumptions, core_time_us, evaluate_case_requirements
from .tdd_timing import evaluate_tdd_timing
from .waveform import compare_folded_vs_golden


@dataclass(frozen=True)
class SweepRow:
    scs_khz: int
    m: int
    k: int
    clk_core_mhz: float | None
    clk_io_mhz: float | None
    tx_cycles: int
    rx_cycles: int
    tx_us: float | None
    rx_us: float | None
    pass_fail: str


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


def assumptions_to_fixed_cfg(assumptions: CycleAssumptions):
    from .fixed_point import FixedPointConfig

    _ = assumptions
    return FixedPointConfig(enabled=True, iq_scale=127.0, twiddle_scale=127.0)


def run_sweep(
    sweep: SweepSpace,
    assumptions: CycleAssumptions | None = None,
    include_correctness: bool = False,
) -> list[dict[str, Any]]:
    if assumptions is None:
        assumptions = CycleAssumptions()

    rows: list[dict[str, Any]] = []
    for cfg in sweep.configs():
        # k cannot be larger than m in practical mapping.
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
