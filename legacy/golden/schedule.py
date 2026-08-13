"""
golden/schedule.py — the reference MICRO-OP SCHEDULE for the transforms.

This is the lever that makes a working FFT core reachable for the code agent:
instead of inventing the address/twiddle schedule of a 128-pt FFT (the hard part),
the scheduler RTL only has to EMIT this known-correct sequence, and the core RTL
only has to EXECUTE one micro-op correctly. Invention -> transcription.

Each transform is expressed as a list of butterfly/MAC micro-ops referencing a
twiddle ROM (twiddle_source). A Python executor runs the schedule and the
self-test proves it reproduces the numpy transform exactly, so the schedule is a
trustworthy spec for the RTL.

Emitted artifacts (generated/golden/):
  ifft128_schedule.json   radix-2 DIT butterfly schedule (7 stages x 64)
  dft12_schedule.json     direct 12-pt DFT MAC schedule (12 x 12)
  bitrev128.json          input bit-reversal permutation for the FFT
Twiddle ROMs are emitted by golden/vectors.py (tw128_*, twiddle_* for n=12).
"""
from __future__ import annotations
import json, pathlib
import numpy as np

ROOT   = pathlib.Path(__file__).parent.parent
OUTDIR = ROOT / "generated" / "golden"
import reference


# ── twiddle ROM (unit-circle, forward convention W[i]=exp(-j2pi i/N)) ─────────
def twiddle_rom_c(n: int) -> np.ndarray:
    return np.exp(-2j * np.pi * np.arange(n) / n)


# ── 128-pt radix-2 DIT schedule ──────────────────────────────────────────────
def bitrev_perm(n: int) -> list[int]:
    bits = int(np.log2(n))
    out = []
    for i in range(n):
        r = 0
        for b in range(bits):
            r = (r << 1) | ((i >> b) & 1)
        out.append(r)
    return out


def fft_schedule(n: int = 128) -> list[dict]:
    """Radix-2 DIT butterfly micro-ops over a bit-reversed buffer.

    Each op: {stage, top, bot, tw_idx} referencing the N-entry twiddle ROM.
    W used in a stage of span m is exp(-j2pi k/m) = ROM[k*N/m], so tw_idx=k*N//m.
    'conj' (for inverse) and 'scale' are applied by the executor per direction."""
    ops = []
    m = 2
    stage = 0
    while m <= n:
        half = m // 2
        for start in range(0, n, m):
            for k in range(half):
                ops.append({"stage": stage, "top": start + k,
                            "bot": start + half + k, "tw_idx": k * (n // m)})
        m *= 2
        stage += 1
    return ops


def run_fft(x: np.ndarray, inverse: bool, n: int = 128) -> np.ndarray:
    rom = twiddle_rom_c(n)
    perm = bitrev_perm(n)
    y = np.asarray(x, complex)[perm].copy()
    for op in fft_schedule(n):
        w = rom[op["tw_idx"]]
        if inverse:
            w = np.conj(w)
        t = w * y[op["bot"]]
        top = y[op["top"]]
        y[op["top"]] = top + t
        y[op["bot"]] = top - t
    if inverse:
        y = y / n
    return y


# ── 12-pt direct DFT schedule (MAC form) ─────────────────────────────────────
def dft12_schedule() -> list[dict]:
    """Direct 12-pt DFT as MAC micro-ops: X[n] += x[k]*ROM12[(n*k)%12].
    Correct-first (not area-optimal); a mixed-radix 3x4 refactor can replace it
    later without changing the golden it must match."""
    ops = []
    for n in range(12):
        for k in range(12):
            ops.append({"out": n, "in": k, "tw_idx": (n * k) % 12})
    return ops


def run_dft12(x: np.ndarray, inverse: bool) -> np.ndarray:
    rom = twiddle_rom_c(12)
    x = np.asarray(x, complex)
    X = np.zeros(12, complex)
    for op in dft12_schedule():
        w = rom[op["tw_idx"]]
        if inverse:
            w = np.conj(w)
        X[op["out"]] += x[op["in"]] * w
    if inverse:
        X = X / 12
    return X


def emit() -> dict:
    OUTDIR.mkdir(parents=True, exist_ok=True)
    (OUTDIR / "ifft128_schedule.json").write_text(json.dumps(fft_schedule(128)), encoding="utf-8")
    (OUTDIR / "dft12_schedule.json").write_text(json.dumps(dft12_schedule()), encoding="utf-8")
    (OUTDIR / "bitrev128.json").write_text(json.dumps(bitrev_perm(128)), encoding="utf-8")
    info = {"ifft128_ops": len(fft_schedule(128)), "dft12_ops": len(dft12_schedule())}
    print(f"[schedule] emitted ifft128 ({info['ifft128_ops']} butterflies), "
          f"dft12 ({info['dft12_ops']} MACs) -> generated/golden/")
    return info


# ── self-test: the schedules reproduce the numpy transforms exactly ──────────
if __name__ == "__main__":
    rng = np.random.default_rng(1)
    g = rng.standard_normal(128) + 1j * rng.standard_normal(128)

    ifft_sched = run_fft(g, inverse=True)
    ifft_ref   = reference.core_ifft128(g)
    e1 = np.max(np.abs(ifft_sched - ifft_ref))
    print(f"[schedule] IFFT-128 schedule vs golden: max err {e1:.2e}")
    assert e1 < 1e-9, "IFFT schedule must match the golden transform"

    fft_sched = run_fft(g, inverse=False)
    e2 = np.max(np.abs(fft_sched - reference.core_fft128(g)))
    print(f"[schedule]  FFT-128 schedule vs golden: max err {e2:.2e}")
    assert e2 < 1e-9

    x12 = rng.standard_normal(12) + 1j * rng.standard_normal(12)
    e3 = np.max(np.abs(run_dft12(x12, False) - reference.core_dft12(x12)))
    e4 = np.max(np.abs(run_dft12(x12, True)  - reference.core_idft12(x12)))
    print(f"[schedule] DFT-12 fwd/inv vs golden: max err {e3:.2e} / {e4:.2e}")
    assert e3 < 1e-9 and e4 < 1e-9

    emit()
    print("[schedule] self-test OK — schedules are faithful, artifacts emitted")
