"""
golden/top_exec.py — full fixed-point TX chain, end to end, at the precision that
CLOSES the EVM <= 2% gate. The top RTL mirrors these ops bit-for-bit.

Precision (found by sweep in this file's history; see REPORT.md):
  internal data  = signed, DFRAC=15 fractional bits (Q9.15 in 24-bit)
  twiddles       = signed Q1.TWFRAC, TWFRAC=13 (14-bit)
  int8 boundaries only at din/dout (narrow by DFRAC-7 = 8).
Q5.11 + Q1.7 (the modular streaming interfaces) is too coarse (~2.8%); the full
transform must keep this wider precision in a shared datapath.
"""
from __future__ import annotations
import pathlib, sys
import numpy as np

ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "golden"))
import reference as ref
import schedule as sch

DFRAC  = 15
TWFRAC = 13
NARROW = DFRAC - 7        # 8


def _rnd(x: int, s: int) -> int:
    return (x + (1 << (s - 1))) >> s if s > 0 else x


def twiddles(n: int):
    idx = np.arange(n)
    tw = np.exp(-2j * np.pi * idx / n)
    sc = 1 << TWFRAC
    return ([int(round(v)) for v in tw.real * sc],
            [int(round(v)) for v in tw.imag * sc])


def top_tx(sym_bytes: np.ndarray) -> list[tuple[int, int]]:
    b = np.asarray(sym_bytes, dtype=np.int64)
    b = np.where(b >= 128, b - 256, b)
    xi = [int(b[2 * k]) << (DFRAC - 7) for k in range(12)]     # widen int8 -> Q9.15
    xq = [int(b[2 * k + 1]) << (DFRAC - 7) for k in range(12)]

    w12r, w12i = twiddles(12)
    sr = [0] * 12; si = [0] * 12
    for n in range(12):
        ar = ai = 0
        for k in range(12):
            i = (n * k) % 12
            ar += xi[k] * w12r[i] - xq[k] * w12i[i]
            ai += xi[k] * w12i[i] + xq[k] * w12r[i]
        sr[n] = _rnd(ar, TWFRAC); si[n] = _rnd(ai, TWFRAC)     # back to Q9.15

    gr = [0] * 128; gi = [0] * 128
    for i in range(12):
        gr[ref.START + i] = sr[i]; gi[ref.START + i] = si[i]

    perm = sch.bitrev_perm(128)
    re = [gr[p] for p in perm]; im = [gi[p] for p in perm]
    w128r, w128i = twiddles(128)
    for op in sch.fft_schedule(128):
        ti = op["tw_idx"]; wr = w128r[ti]; wi = -w128i[ti]     # conjugate (inverse)
        t = op["top"]; bo = op["bot"]
        tr = _rnd(re[bo] * wr - im[bo] * wi, TWFRAC)
        tii = _rnd(re[bo] * wi + im[bo] * wr, TWFRAC)
        re[t], im[t], re[bo], im[bo] = (_rnd(re[t] + tr, 1), _rnd(im[t] + tii, 1),
                                        _rnd(re[t] - tr, 1), _rnd(im[t] - tii, 1))

    order = list(range(128 - 9, 128)) + list(range(128))       # CP insert (137)
    out = []
    for k in order:
        vr = _rnd(re[k], NARROW); vq = _rnd(im[k], NARROW)
        out.append((max(-128, min(127, vr)), max(-128, min(127, vq))))
    return out


def evm(seed: int = 42) -> dict:
    b = ref.random_input_bytes(seed)
    gold = ref.tx_reference(b)["out_bytes"]
    out = top_tx(b)
    meas = np.array([v for pair in out for v in pair], dtype=np.int64)
    g = np.array(gold, dtype=np.int64)
    cr = meas[0::2] / 127.0 + 1j * meas[1::2] / 127.0
    cg = g[0::2] / 127.0 + 1j * g[1::2] / 127.0
    e = 100.0 * np.sqrt(np.mean(np.abs(cr - cg) ** 2) / np.mean(np.abs(cg) ** 2))
    return {"seed": seed, "evm_percent": round(float(e), 4),
            "mism": int(np.sum(meas != g)), "passed": e <= 2.0}


if __name__ == "__main__":
    es = []
    for s in list(range(8)) + [42]:
        r = evm(s); es.append(r["evm_percent"])
        print(f"[top_exec] seed {s:>3}: EVM={r['evm_percent']:.3f}%  {'PASS' if r['passed'] else 'FAIL'}")
    print(f"[top_exec] DFRAC={DFRAC} TWFRAC={TWFRAC}  worst={max(es):.3f}%  "
          f"{'ALL PASS' if max(es) <= 2.0 else 'SOME FAIL'}")
