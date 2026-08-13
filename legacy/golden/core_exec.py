"""
golden/core_exec.py — golden execution model for the unified_mixed_radix_core.

The core is a scratch-memory FFT engine: load 128 complex samples, execute the
reference micro-op schedule (448 radix-2 butterflies for the IFFT-128), read the
results. Internally it carries Q5.11 (16-bit/component); the external load/read
interface is int8-packed {I8,Q8} (Q1.7), widened on load (<<4) and narrowed on
read (>>4, round, saturate).

This model produces the exact expected memory contents so the RTL core can be
checked bit-exactly. It reuses butterfly_q511 (the verified butterfly) and the
verified schedule — the same pieces, now sequenced over memory.
"""
from __future__ import annotations
import pathlib, sys
import numpy as np

ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "golden"))
import reference as ref
import schedule as sch

SHIFT = 4                       # Q1.7 (int8) <-> Q5.11 (16-bit): value * 2^4


def _tw_q17(tw_idx: int, inverse: bool) -> tuple[int, int]:
    """Quantized Q1.7 twiddle for a schedule op (forward ROM, conjugate if inverse)."""
    w = np.exp(-2j * np.pi * tw_idx / 128)
    if inverse:
        w = np.conj(w)
    return ref.sat8(int(np.rint(w.real * 127))), ref.sat8(int(np.rint(w.imag * 127)))


def uop_stream(inverse: bool = True) -> list[dict]:
    """The 448 radix-2 butterfly micro-ops with resolved int8 twiddles.
    Each: {top, bot, w_re, w_im} (in-place: dst == src)."""
    ops = []
    for op in sch.fft_schedule(128):
        wr, wi = _tw_q17(op["tw_idx"], inverse)
        ops.append({"top": op["top"], "bot": op["bot"], "w_re": wr, "w_im": wi})
    return ops


def load_grid_int8(seed: int = 42) -> list[tuple[int, int]]:
    """128-point bit-reversed input grid as int8 {I8,Q8} pairs (TX path: DFT-12
    spread mapped to the centered bins, quantized to int8, then bit-reversed)."""
    b = ref.random_input_bytes(seed)
    spread = ref.core_dft12(ref.fdiq_unpack(b))
    grid = ref.map_tx(spread)                       # 128 complex (float)
    i8 = [(ref.sat8(int(np.rint(g.real * 127))), ref.sat8(int(np.rint(g.imag * 127))))
          for g in grid]
    perm = sch.bitrev_perm(128)
    return [i8[p] for p in perm]                    # bit-reversed order


def run(seed: int = 42) -> dict:
    """Execute the IFFT schedule over the loaded grid; return int8 output samples
    (natural order) — the values the RTL core must reproduce bit-exactly."""
    grid = load_grid_int8(seed)
    re = [g[0] << SHIFT for g in grid]              # widen to Q5.11
    im = [g[1] << SHIFT for g in grid]
    for op in uop_stream(inverse=True):
        otr, oti, obr, obi = ref.butterfly_q511(
            re[op["top"]], im[op["top"]], re[op["bot"]], im[op["bot"]],
            op["w_re"], op["w_im"])
        re[op["top"]], im[op["top"]] = otr, oti
        re[op["bot"]], im[op["bot"]] = obr, obi
    # narrow back to int8 (round >>4, saturate)
    out = [(ref.sat8(ref._rnd(re[k], SHIFT)), ref.sat8(ref._rnd(im[k], SHIFT)))
           for k in range(128)]
    return {"grid_in": grid, "uops": uop_stream(True), "out_int8": out}


if __name__ == "__main__":
    r = run()
    print(f"[core_exec] {len(r['uops'])} butterfly uops, {len(r['grid_in'])} loaded, "
          f"{len(r['out_int8'])} out samples")
    print(f"[core_exec] sample out[0..3] = {r['out_int8'][:4]}")
