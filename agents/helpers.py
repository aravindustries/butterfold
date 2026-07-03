"""
helpers.py — internal building-block modules that the 6 spec modules instantiate
(e.g. the shared complex multiplier and radix-2 butterfly inside the unified core).

They are not in butterfold_module_io.md (which defines external module boundaries),
but they are authored + functionally gated the same way — one rung of the ladder
each — so the hard core is built bottom-up from verified pieces.
"""
from __future__ import annotations
import module_spec

# name -> {ports: [(name, dir, width)], functions: [...]}
HELPERS = {
    "complex_mul": {
        "ports": [("a_re", "input", 8), ("a_im", "input", 8),
                  ("b_re", "input", 8), ("b_im", "input", 8),
                  ("p_re", "output", 8), ("p_im", "output", 8)],
        "functions": ["Signed Q1.7 complex multiply with rounding and saturation.",
                      "Combinational shared multiplier reused by the DFT/FFT butterflies."],
    },
}


def names() -> list[str]:
    return list(HELPERS.keys())


def is_helper(name: str) -> bool:
    return name in HELPERS


def _mod(name: str) -> dict:
    h = HELPERS[name]
    ports = [{"name": n, "dir": d, "width": w, "desc": ""} for (n, d, w) in h["ports"]]
    return {"name": name, "title": name, "functions": h["functions"], "ports": ports}


def contract_text(name: str) -> str:
    return module_spec.contract_text(_mod(name))


def skeleton(name: str) -> str:
    return module_spec.skeleton(_mod(name))
