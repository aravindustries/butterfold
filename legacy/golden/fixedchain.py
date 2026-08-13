"""
golden/fixedchain.py — pin the core's fixed-point format and PROVE it hits EVM<=2%
before any RTL is written.

The float golden (reference.py) says WHAT to compute; this says with how many bits.
It runs the TX chain with finite internal precision (quantize after every transform
stage) and reports EVM vs the ideal float golden. If a format clears the 2% gate
here, it is a safe target for the butterfly/core RTL; if not, no RTL could pass.

Internal format knob: FRAC fractional bits, WBITS total signed bits per component,
with the DIT IFFT's 1/128 applied as one >>1 (round) per stage (7 stages).
"""
from __future__ import annotations
import pathlib, sys
import numpy as np

ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "golden"))
import reference as ref
import schedule as sch


def _q(v: np.ndarray, frac: int, wbits: int) -> np.ndarray:
    """Quantize complex array to Q(wbits-frac).(frac) with round + saturate."""
    lim = (1 << (wbits - 1))
    def q1(x):
        s = np.rint(x * (1 << frac))
        s = np.clip(s, -lim, lim - 1)
        return s / (1 << frac)
    return q1(np.real(v)) + 1j * q1(np.imag(v))


def fixed_tx(symbols: np.ndarray, frac: int, wbits: int) -> np.ndarray:
    """TX chain with finite internal precision; returns time_with_cp (float view
    of the fixed-point values). Twiddles are Q1.7 (the twiddle_source ROM)."""
    twq = lambda n: _q(ref.twiddle_rom(n)[0] / 127.0 + 1j * ref.twiddle_rom(n)[1] / 127.0, 7, 8)

    # DFT-12 with quantized twiddles, then quantize the spread output
    W12 = np.conj(twq(12))  # forward uses exp(-j..) already in ROM
    x = _q(symbols, frac, wbits)
    spread = np.array([np.sum(x * (twq(12) ** 0)) if False else
                       np.sum(x * np.exp(-2j*np.pi*n*np.arange(12)/12)) for n in range(12)])
    spread = _q(spread, frac, wbits)

    # centered map
    grid = np.zeros(128, complex); grid[ref.START:ref.START+12] = spread

    # radix-2 DIT IFFT with per-stage quantize and >>1 (1/128 total over 7 stages)
    rom = np.exp(-2j*np.pi*np.arange(128)/128)          # forward twiddles
    y = _q(grid[sch.bitrev_perm(128)], frac, wbits)
    stage = 0; m = 2
    while m <= 128:
        for op in [o for o in sch.fft_schedule(128) if o["stage"] == stage]:
            w = np.conj(rom[op["tw_idx"]])              # inverse -> conjugate
            t = w * y[op["bot"]]
            top = y[op["top"]]
            y[op["top"]] = top + t
            y[op["bot"]] = top - t
        y = _q(y * 0.5, frac, wbits)                    # >>1 per stage (round+sat), total /128
        stage += 1; m *= 2

    time_cp = np.concatenate([y[-9:], y])               # CP insert
    return time_cp


def evm(frac: int = 13, wbits: int = 18, seed: int = 42) -> dict:
    b = ref.random_input_bytes(seed)
    symbols = ref.fdiq_unpack(b)
    ideal = ref.tx_reference(b)["time_with_cp"]          # float golden
    got = fixed_tx(symbols, frac, wbits)
    err = np.sqrt(np.mean(np.abs(got - ideal) ** 2))
    rp = np.sqrt(np.mean(np.abs(ideal) ** 2))
    e = 100.0 * err / rp if rp else 0.0
    return {"frac": frac, "wbits": wbits, "evm_percent": round(e, 4), "passed": e <= 2.0}


if __name__ == "__main__":
    print("[fixedchain] sweeping internal precision (EVM vs float golden, gate<=2%):")
    best = None
    for wbits in (12, 14, 16, 18, 20):
        for frac in (9, 11, 13, 15):
            if frac >= wbits:
                continue
            r = evm(frac, wbits)
            mark = "  <= PASS" if r["passed"] else ""
            print(f"  Q{wbits-frac}.{frac} ({wbits}b): EVM={r['evm_percent']:.3f}%{mark}")
            if r["passed"] and (best is None or wbits < best["wbits"]):
                best = r
    print(f"[fixedchain] smallest passing format: {best}")
