"""
planner.py — modular build planner.

Consumes ONLY butterfold_module_io.md (via module_spec). Emits an ordered plan of
the 6 modules + top to author, each with its port summary and dependencies. The
plan is derived deterministically from the parsed contract (works with no API
key); if OPENAI_API_KEY is set, each module also gets a one-line design rationale.

Output: generated/plan.json
"""
from __future__ import annotations
import os, json, hashlib, pathlib
import module_spec

ROOT     = pathlib.Path(__file__).parent.parent
OUT_PATH = ROOT / "generated" / "plan.json"

try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass

# Which modules each module instantiates (drives depends_on + top integration).
DEPENDS = {
    "twiddle_source":            [],
    "unified_mixed_radix_core":  [],
    "subcarrier_map_extract":    [],
    "fdiq_io_adapter":           [],
    "tdiq_io_adapter_cp":        [],
    "scheduler_addr_control":    [],
    "butterfold_top": ["fdiq_io_adapter", "tdiq_io_adapter_cp", "subcarrier_map_extract",
                       "unified_mixed_radix_core", "twiddle_source", "scheduler_addr_control"],
}


def _rationale(client, mod: dict) -> str:
    try:
        r = client.chat.completions.create(
            model="gpt-4o", max_tokens=120,
            messages=[{"role": "system", "content":
                       "One sentence: the key implementation approach for this hardware module."},
                      {"role": "user", "content": module_spec.contract_text(mod)}])
        return r.choices[0].message.content.strip()
    except Exception:
        return ""


def run() -> dict:
    doc = module_spec.parse()
    client = None
    if os.environ.get("OPENAI_API_KEY"):
        try:
            import openai
            client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
        except Exception:
            client = None

    subtasks = []
    for name in doc["order"]:
        mod = doc["modules"][name]
        ni = sum(1 for p in mod["ports"] if p["dir"] == "input")
        no = sum(1 for p in mod["ports"] if p["dir"] == "output")
        subtasks.append({
            "id": name,
            "module_name": name,
            "description": (mod["functions"][0] if mod["functions"]
                            else "Top-level integration of all ButterFold modules."),
            "ports": {"total": len(mod["ports"]), "in": ni, "out": no},
            "depends_on": DEPENDS.get(name, []),
            "rationale": _rationale(client, mod) if client else "",
        })

    plan = {
        "design": "butterfold",
        "spec": "butterfold_module_io.md",
        "spec_hash": _hash(),
        "build_order": doc["order"],
        "subtasks": subtasks,
    }
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(plan, indent=2), encoding="utf-8")
    print(f"[planner] Plan written to {OUT_PATH}")
    print(f"[planner] {len(subtasks)} modules to author (build order):")
    for t in subtasks:
        dep = f"  <- {', '.join(t['depends_on'])}" if t["depends_on"] else ""
        print(f"[planner]   {t['id']:<28} {t['ports']['total']:>2} ports{dep}")
    return plan


def _hash() -> str:
    return hashlib.sha256(module_spec.SPEC_PATH.read_bytes()).hexdigest()[:16]


# kept for orchestrator compatibility; the plan is deterministic so react == run
def run_react(*_a, **_k) -> dict:
    return run()


if __name__ == "__main__":
    run()
