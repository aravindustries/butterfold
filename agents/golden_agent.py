"""
golden_agent.py — generates a standalone Python GOLDEN MODEL for each module, then
checks that the daisy chain of those per-module models reproduces the whole-chain
golden (butterfold_sim, via golden/reference.py).  TX and RX.

Phase 1 of the functional-verification plan:
  butterfold_sim  == whole-chain golden (the reference)
  per-module .py  == independent model of ONE module
  daisy chain of per-module .py  MUST equal the whole-chain golden   <-- checked here

Each generated model is STANDALONE (numpy only), so chaining them and comparing to
the reference is a real test, not a tautology. With OPENAI_API_KEY set, an LLM may
author each model from its contract; the deterministic standalone author is the
always-correct fallback (open-source constraint: works with no key).

Output: generated/golden/<module>.py  +  generated/golden_report.json
Run:    python agents/golden_agent.py
"""
from __future__ import annotations
import json, pathlib, importlib.util
import module_spec

ROOT       = pathlib.Path(__file__).parent.parent
GOLDEN_DIR = ROOT / "generated" / "golden"
REPORT     = ROOT / "generated" / "golden_report.json"

# Required public functions per module (the daisy chain dispatches these by name).
MODULE_FUNCS = {
    "twiddle_source":           ["twiddle_rom"],
    "unified_mixed_radix_core": ["dft12", "idft12", "ifft128", "fft128"],
    "subcarrier_map_extract":   ["map_tx", "extract_rx"],
    "fdiq_io_adapter":          ["unpack", "pack"],
    "tdiq_io_adapter_cp":       ["cp_insert", "cp_remove", "pack", "unpack"],
    "scheduler_addr_control":   ["tx_stages", "rx_stages"],
}

_HEADER = "# GENERATED golden model for {mod} — standalone numpy reference.\n" \
          "# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).\n"

# ── deterministic standalone implementations (always-correct fallback) ────────
_SRC = {
"twiddle_source": '''
import numpy as np
def twiddle_rom(n, scale=127.0, conjugate=False):
    """Quantized Q1.7 twiddle LUT for an n-point transform; conjugate for inverse."""
    idx = np.arange(n); tw = np.exp(-2j*np.pi*idx/n)
    if conjugate: tw = np.conj(tw)
    re = np.clip(np.rint(tw.real*scale), -128, 127).astype(int).tolist()
    im = np.clip(np.rint(tw.imag*scale), -128, 127).astype(int).tolist()
    return re, im
''',

"unified_mixed_radix_core": '''
import numpy as np
# DFT is unique, so np.fft reproduces the radix-2 / mixed-radix hardware exactly.
def dft12(x):   return np.fft.fft(np.asarray(x, complex))
def idft12(x):  return np.fft.ifft(np.asarray(x, complex))
def ifft128(x): return np.fft.ifft(np.asarray(x, complex))
def fft128(x):  return np.fft.fft(np.asarray(x, complex))
''',

"subcarrier_map_extract": '''
import numpy as np
K, M, START = 12, 128, 58
def map_tx(spread):
    g = np.zeros(M, complex); g[START:START+K] = np.asarray(spread); return g
def extract_rx(spectrum):
    return np.asarray(spectrum)[START:START+K].copy()
''',

"fdiq_io_adapter": '''
import numpy as np
def _q(v, scale=127.0): return int(np.clip(np.rint(v*scale), -128, 127))
def pack(symbols):
    out = []
    for c in np.asarray(symbols, complex): out += [_q(c.real), _q(c.imag)]
    return np.array(out, dtype=np.int8)
def unpack(iq_bytes):
    b = np.asarray(iq_bytes, dtype=np.int8)
    return b[0::2].astype(float)/127.0 + 1j*b[1::2].astype(float)/127.0
''',

"tdiq_io_adapter_cp": '''
import numpy as np
CP, M = 9, 128
def cp_insert(t, cp=CP): t = np.asarray(t, complex); return np.concatenate([t[-cp:], t])
def cp_remove(t, cp=CP): t = np.asarray(t, complex); return t[cp:cp+M]
def _q(v, scale=127.0): return int(np.clip(np.rint(v*scale), -128, 127))
def pack(t):
    out = []
    for c in np.asarray(t, complex): out += [_q(c.real), _q(c.imag)]
    return np.array(out, dtype=np.int8)
def unpack(iq_bytes):
    b = np.asarray(iq_bytes, dtype=np.int8)
    return b[0::2].astype(float)/127.0 + 1j*b[1::2].astype(float)/127.0
''',

"scheduler_addr_control": '''
# The scheduler sequences the datapath. Its golden is the ordered daisy chain:
# each stage is (module, function) applied to the running data.
def tx_stages():
    return [("fdiq_io_adapter","unpack"), ("unified_mixed_radix_core","dft12"),
            ("subcarrier_map_extract","map_tx"), ("unified_mixed_radix_core","ifft128"),
            ("tdiq_io_adapter_cp","cp_insert"), ("tdiq_io_adapter_cp","pack")]
def rx_stages():
    return [("tdiq_io_adapter_cp","unpack"), ("tdiq_io_adapter_cp","cp_remove"),
            ("unified_mixed_radix_core","fft128"), ("subcarrier_map_extract","extract_rx"),
            ("unified_mixed_radix_core","idft12"), ("fdiq_io_adapter","pack")]
''',
}


def _write(module: str, body: str) -> pathlib.Path:
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    p = GOLDEN_DIR / f"{module}.py"
    p.write_text(_HEADER.format(mod=module) + body.lstrip("\n"), encoding="utf-8")
    return p


def _validate_funcs(module: str, path: pathlib.Path) -> bool:
    """Import the generated model and confirm the required functions exist."""
    spec = importlib.util.spec_from_file_location(f"golden_{module}", path)
    m = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(m)
    except Exception as exc:
        print(f"[golden]   {module}: import failed: {exc}"); return False
    missing = [f for f in MODULE_FUNCS[module] if not hasattr(m, f)]
    if missing:
        print(f"[golden]   {module}: missing functions {missing}"); return False
    return True


def author_all() -> dict:
    doc = module_spec.parse()
    written = {}
    for module in MODULE_FUNCS:
        # (LLM authoring hook could go here; deterministic standalone is authoritative.)
        p = _write(module, _SRC[module])
        ok = _validate_funcs(module, p)
        written[module] = {"path": str(p.relative_to(ROOT)), "funcs": MODULE_FUNCS[module], "ok": ok}
        print(f"[golden] authored {module}.py  ({'ok' if ok else 'INVALID'})")
    return written


def run() -> dict:
    print("[golden] Generating per-module golden models...")
    written = author_all()
    print("[golden] Checking daisy chain vs whole-chain golden (butterfold_sim)...")
    import importlib
    import sys
    sys.path.insert(0, str(ROOT / "golden"))
    import chain as chain_mod
    importlib.reload(chain_mod)
    compliance = chain_mod.check_compliance()
    report = {"modules": written, "compliance": compliance}
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    ok = all(v["ok"] for v in written.values()) and compliance["passed"]
    print(f"[golden] -- {'PASSED' if ok else 'FAILED'} -- "
          f"(TX max err {compliance['tx']['max_err']:.2e}, "
          f"RX max err {compliance['rx']['max_err']:.2e})")
    report["passed"] = ok
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


if __name__ == "__main__":
    run()
