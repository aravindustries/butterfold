"""
golden/rx_exec.py — full fixed-point RX chain, end to end, at the precision that
closes the RX EVM gate. Mirror of top_exec.py (TX) in reverse.

RX: 274 time-domain bytes -> unpack 137 -> drop CP (9) -> 128 -> bit-reverse ->
FFT-128 (FORWARD, no per-stage scale) -> extract bins 58..69 -> IDFT-12 (inverse,
/12) -> 12 recovered symbols -> pack to 24 int8 bytes.

Same shared Q9.15 datapath / Q1.13 twiddles as TX. The forward FFT recovers the
grid (spread) magnitudes (FFT(IFFT(x))=x), so no overflow with 9 integer bits.
"""
from __future__ import annotations
import pathlib, sys
import numpy as np

ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "golden"))
import reference as ref
import schedule as sch
import top_exec as te

DFRAC, TWFRAC, START = te.DFRAC, te.TWFRAC, 58


def _rnd(x, s): return (x + (1 << (s - 1))) >> s if s > 0 else x


def _div12(x: int) -> int:
    """Round(x / 12) via reciprocal multiply (matches a hardware * >> impl)."""
    return _rnd(x * 2731, 15)          # 2731/32768 = 0.083344 ~ 1/12


def rx_rx(time_bytes: np.ndarray) -> list[tuple[int, int]]:
    b = np.asarray(time_bytes, dtype=np.int64)
    b = np.where(b >= 128, b - 256, b)
    # unpack 137 complex, drop the 9-sample CP -> 128 useful, widen to Q9.15
    re = [int(b[2 * (k + 9)]) << (DFRAC - 7) for k in range(128)]
    im = [int(b[2 * (k + 9) + 1]) << (DFRAC - 7) for k in range(128)]

    # bit-reverse + forward FFT-128 (no per-stage scaling)
    perm = sch.bitrev_perm(128)
    re = [re[p] for p in perm]; im = [im[p] for p in perm]
    w128r, w128i = te.twiddles(128)
    for op in sch.fft_schedule(128):
        ti = op["tw_idx"]; wr = w128r[ti]; wi = w128i[ti]     # forward (not conjugated)
        t = op["top"]; bo = op["bot"]
        tr = _rnd(re[bo] * wr - im[bo] * wi, TWFRAC)
        tii = _rnd(re[bo] * wi + im[bo] * wr, TWFRAC)
        re[t], im[t], re[bo], im[bo] = (re[t] + tr, im[t] + tii, re[t] - tr, im[t] - tii)

    # extract the 12 active bins (58..69)
    ar = [re[START + i] for i in range(12)]
    ai = [im[START + i] for i in range(12)]

    # IDFT-12 (inverse: conjugate twiddles, /12)
    w12r, w12i = te.twiddles(12)
    out = []
    for n in range(12):
        accr = acci = 0
        for k in range(12):
            idx = (n * k) % 12
            wr = w12r[idx]; wi = -w12i[idx]                   # conjugate (inverse)
            accr += ar[k] * wr - ai[k] * wi
            acci += ar[k] * wi + ai[k] * wr
        sr = _div12(_rnd(accr, TWFRAC)); si = _div12(_rnd(acci, TWFRAC))
        out.append((max(-128, min(127, _rnd(sr, DFRAC - 7))),
                    max(-128, min(127, _rnd(si, DFRAC - 7)))))
    return out


def evm(seed: int = 42) -> dict:
    b = ref.random_input_bytes(seed)                          # original TX symbols (24 bytes)
    tx = ref.tx_reference(b)["out_bytes"]                     # 274-byte TX output
    out = rx_rx(tx)
    meas = np.array([v for pair in out for v in pair], dtype=np.int64)
    g = np.array(b, dtype=np.int64); g = np.where(g >= 128, g - 256, g)
    cr = meas[0::2] / 127.0 + 1j * meas[1::2] / 127.0
    cg = g[0::2] / 127.0 + 1j * g[1::2] / 127.0
    e = 100.0 * np.sqrt(np.mean(np.abs(cr - cg) ** 2) / np.mean(np.abs(cg) ** 2))
    return {"seed": seed, "evm_percent": round(float(e), 4), "passed": e <= 2.0}


if __name__ == "__main__":
    es = []
    for s in list(range(8)) + [42]:
        r = evm(s); es.append(r["evm_percent"])
        print(f"[rx_exec] seed {s:>3}: recovered-symbol EVM={r['evm_percent']:.3f}%  "
              f"{'PASS' if r['passed'] else 'FAIL'}")
    print(f"[rx_exec] worst={max(es):.3f}%  {'ALL PASS' if max(es) <= 2.0 else 'SOME FAIL'}")
