"""
golden/chain.py — run the daisy chain of the per-module golden models and check
it against the whole-chain golden (reference.py / butterfold_sim).

Loads generated/golden/<module>.py, gets the stage order from the scheduler model,
threads data through each (module, function) stage, and compares every stage's
output to the corresponding whole-chain reference stage. TX and RX.
"""
from __future__ import annotations
import pathlib, importlib.util
import numpy as np

ROOT       = pathlib.Path(__file__).parent.parent
GOLDEN_DIR = ROOT / "generated" / "golden"

import reference   # golden/reference.py (whole-chain oracle)

# daisy stage index -> whole-chain reference key it must equal
TX_REFKEYS = ["symbols", "spread", "grid", "time_no_cp", "time_with_cp", "out_bytes"]
RX_REFKEYS = ["time_with_cp", "time_no_cp", "spectrum", "active", "recovered", "out_bytes"]


def _load(module: str):
    p = GOLDEN_DIR / f"{module}.py"
    spec = importlib.util.spec_from_file_location(f"golden_{module}", p)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def _models() -> dict:
    names = ["twiddle_source", "unified_mixed_radix_core", "subcarrier_map_extract",
             "fdiq_io_adapter", "tdiq_io_adapter_cp", "scheduler_addr_control"]
    return {n: _load(n) for n in names}


def run_chain(direction: str, in_data, models: dict) -> list:
    """Thread in_data through the scheduler's ordered (module, func) stages.
    Returns the list of stage outputs (one per stage)."""
    sched = models["scheduler_addr_control"]
    stages = sched.tx_stages() if direction == "tx" else sched.rx_stages()
    data, outputs = in_data, []
    for mod_name, func_name in stages:
        fn = getattr(models[mod_name], func_name)
        data = fn(data)
        outputs.append(data)
    return outputs


def _err(a, b) -> float:
    a = np.asarray(a); b = np.asarray(b)
    if a.shape != b.shape:
        return float("inf")
    if np.issubdtype(a.dtype, np.integer) and np.issubdtype(b.dtype, np.integer):
        return float(np.max(np.abs(a.astype(int) - b.astype(int))))
    return float(np.max(np.abs(a.astype(complex) - b.astype(complex))))


def _compare(outputs: list, ref: dict, refkeys: list) -> dict:
    stages = {}
    worst = 0.0
    for i, key in enumerate(refkeys):
        e = _err(outputs[i], ref[key])
        stages[key] = e
        worst = max(worst, e if e != float("inf") else 1e9)
    return {"max_err": worst, "stages": stages}


def check_compliance(seed: int = 42, tol_float: float = 1e-9, tol_byte: float = 0) -> dict:
    models = _models()
    in_bytes = reference.random_input_bytes(seed)

    # TX: daisy chain vs whole-chain reference
    ref_tx = reference.tx_reference(in_bytes)
    tx_out = run_chain("tx", in_bytes, models)
    tx = _compare(tx_out, ref_tx, TX_REFKEYS)

    # RX: feed the TX output bytes back through the RX daisy chain
    tx_bytes = ref_tx["out_bytes"]
    ref_rx = reference.rx_reference(tx_bytes)
    rx_out = run_chain("rx", tx_bytes, models)
    rx = _compare(rx_out, ref_rx, RX_REFKEYS)

    # Byte outputs must match exactly; complex stages within float tolerance.
    tx_ok = tx["stages"]["out_bytes"] <= tol_byte and \
            all(v <= tol_float for k, v in tx["stages"].items() if k != "out_bytes")
    rx_ok = rx["stages"]["out_bytes"] <= tol_byte and \
            all(v <= tol_float for k, v in rx["stages"].items() if k != "out_bytes")
    return {"passed": bool(tx_ok and rx_ok), "seed": seed, "tx": tx, "rx": rx}


if __name__ == "__main__":
    r = check_compliance()
    print(f"[chain] TX stage errors: " +
          "  ".join(f"{k}={v:.1e}" for k, v in r["tx"]["stages"].items()))
    print(f"[chain] RX stage errors: " +
          "  ".join(f"{k}={v:.1e}" for k, v in r["rx"]["stages"].items()))
    print(f"[chain] compliance: {'PASSED' if r['passed'] else 'FAILED'}")
