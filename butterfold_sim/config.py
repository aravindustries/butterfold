from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from typing import Iterable, Iterator


@dataclass(frozen=True)
class NRConfig:
    scs_khz: int
    m: int
    k: int
    cp_len: int
    tx_window_symbols: float = 1.0
    rx_window_symbols: float = 1.0
    tdd_guard_symbols: float = 0.25
    switch_cycles: int = 32

    @property
    def fs_hz(self) -> float:
        return float(self.m * self.scs_khz * 1_000)

    @property
    def symbol_samples(self) -> int:
        return self.m + self.cp_len

    @property
    def symbol_time_s(self) -> float:
        return self.symbol_samples / self.fs_hz

    @property
    def tx_deadline_s(self) -> float:
        return self.tx_window_symbols * self.symbol_time_s

    @property
    def rx_deadline_s(self) -> float:
        return self.rx_window_symbols * self.symbol_time_s

    @property
    def half_duplex_window_s(self) -> float:
        total_symbols = self.tx_window_symbols + self.rx_window_symbols + self.tdd_guard_symbols
        return total_symbols * self.symbol_time_s


@dataclass(frozen=True)
class SweepSpace:
    scs_khz: tuple[int, ...] = (15, 30, 60, 120)
    m_values: tuple[int, ...] = (128, 256, 512, 1024)
    k_values: tuple[int, ...] = (12, 24, 48, 72, 144)
    cp_len: int = 9
    core_clk_min_hz: float = 10e6
    core_clk_max_hz: float = 500e6
    core_clk_step_hz: float = 1e6
    io_clk_min_hz: float = 1e6
    io_clk_max_hz: float = 100e6
    io_clk_step_hz: float = 1e6
    tdd_guard_symbols: float = 0.25

    def core_grid(self) -> list[float]:
        start = int(self.core_clk_min_hz)
        stop = int(self.core_clk_max_hz)
        step = int(self.core_clk_step_hz)
        return [float(v) for v in range(start, stop + 1, step)]

    def io_grid(self) -> list[float]:
        start = int(self.io_clk_min_hz)
        stop = int(self.io_clk_max_hz)
        step = int(self.io_clk_step_hz)
        return [float(v) for v in range(start, stop + 1, step)]

    def configs(self) -> Iterator[NRConfig]:
        for scs_khz, m, k in product(self.scs_khz, self.m_values, self.k_values):
            yield NRConfig(
                scs_khz=scs_khz,
                m=m,
                k=k,
                cp_len=self.cp_len,
                tdd_guard_symbols=self.tdd_guard_symbols,
            )


def milestone_configs() -> list[NRConfig]:
    return [
        NRConfig(scs_khz=scs, m=128, k=12, cp_len=9, tdd_guard_symbols=0.25)
        for scs in (15, 30, 60)
    ]


def first_ge(grid: Iterable[float], threshold: float) -> float | None:
    for value in grid:
        if value >= threshold:
            return value
    return None
