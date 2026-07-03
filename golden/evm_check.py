"""
golden/evm_check.py — authoritative scorer for Phase 2.

Reads an RTL-captured byte output (hex, from a testbench $writememh) and the golden
byte output, interprets both as interleaved Q1.7 complex samples, and reports:
  - EVM %   (authoritative PASS gate: EVM <= 2.0%)
  - bit-exact int8 mismatch count (informational)

Usage:
  python golden/evm_check.py <rtl_out.hex> <golden.hex>
or import score(rtl_hex, gold_hex) -> dict.
"""
from __future__ import annotations
import sys, pathlib
import numpy as np

EVM_GATE = 2.0


def _read_hex_bytes(path: str) -> np.ndarray:
    txt = pathlib.Path(path).read_text().split()
    vals = [int(t, 16) for t in txt if t.strip()]
    a = np.array(vals, dtype=np.int64)
    a = np.where(a >= 128, a - 256, a)          # unsigned hex -> signed int8
    return a.astype(np.int8)


def _to_complex(b: np.ndarray) -> np.ndarray:
    return b[0::2].astype(float) / 127.0 + 1j * b[1::2].astype(float) / 127.0


def score(rtl_hex: str, gold_hex: str) -> dict:
    rtl  = _read_hex_bytes(rtl_hex)
    gold = _read_hex_bytes(gold_hex)
    n = min(len(rtl), len(gold))
    out = {"rtl_bytes": len(rtl), "gold_bytes": len(gold)}
    if len(rtl) != len(gold):
        out["length_mismatch"] = True
    rtl, gold = rtl[:n], gold[:n]

    mism = int(np.sum(rtl != gold))
    cr, cg = _to_complex(rtl), _to_complex(gold)
    ref_p = float(np.mean(np.abs(cg) ** 2))
    evm = 0.0 if ref_p == 0 else float(100.0 * np.sqrt(np.mean(np.abs(cr - cg) ** 2) / ref_p))

    out.update({"evm_percent": round(evm, 4), "bit_exact_mismatches": mism,
                "total_bytes": n, "evm_gate": EVM_GATE, "passed": evm <= EVM_GATE})
    return out


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: evm_check.py <rtl_out.hex> <golden.hex>"); sys.exit(2)
    r = score(sys.argv[1], sys.argv[2])
    print(f"[evm] EVM={r['evm_percent']}%  gate<={r['evm_gate']}%  "
          f"bit-exact mismatches={r['bit_exact_mismatches']}/{r['total_bytes']}  "
          f"-> {'PASS' if r['passed'] else 'FAIL'}")
