"""
EDA Skills Catalog
==================

The registry of specialist capabilities the meta-planner can dispatch to.
Each skill is self-describing: metadata (so the planner can reason about WHEN
to use it) plus a real handler (the actual execution — shells out to the EDA
tools already present in the IIC-OSIC-TOOLS Docker image).

Skills
------
  spec_query     retrieve grounded answers from the 3GPP spec (PDF or markdown)
  simulate       compile + run RTL against a testbench (iverilog / vvp)
  synthesize     synthesize RTL to a gate-level netlist (yosys)
  area_estimate  estimate gate count + silicon area (yosys stat, GF180 model)
  timing         estimate logic depth / critical path (yosys ltp, opensta if present)

CLI
---
  python agents/skills_catalog.py list
  python agents/skills_catalog.py manifest
  python agents/skills_catalog.py check
  python agents/skills_catalog.py run spec_query    --question "CP length for m=128?"
  python agents/skills_catalog.py run simulate      --rtl generated/rtl/butterfold_top.v --tb tests/tb_butterfold_top.v
  python agents/skills_catalog.py run synthesize    --rtl generated/rtl/butterfold_top.v --top butterfold_top
  python agents/skills_catalog.py run area_estimate --rtl generated/rtl/butterfold_top.v --top butterfold_top

The meta-planner consumes `manifest()` (or generated/skills_catalog.json) to
decide which specialists to spawn for a given subtask.
"""
from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from typing import Callable

ROOT = pathlib.Path(__file__).parent.parent
GEN = ROOT / "generated"

# Spec sources, richest first. Drop the real 3GPP TS 38.211 PDF in spec/ to use it.
SPEC_SOURCES = [
    ROOT / "spec" / "spec.pdf",
    ROOT / "spec.pdf",
    ROOT / "spec" / "38211.pdf",
    ROOT / "3GPP_ButterFold_Spec_Extract.md",
]


# --------------------------------------------------------------------------- #
# Skill definition
# --------------------------------------------------------------------------- #
@dataclass
class Skill:
    name: str
    category: str                 # "spec" | "eda"
    summary: str                  # one line: what it does
    when_to_use: str              # guidance the meta-planner reasons over
    inputs: dict                  # arg_name -> description
    outputs: dict                 # field_name -> description
    requires: list[str]           # external CLI tools needed
    handler: Callable[[dict], dict] = field(repr=False, default=None)

    def to_manifest(self) -> dict:
        """JSON-serializable view (no handler) for the meta-planner."""
        return {
            "name": self.name,
            "category": self.category,
            "summary": self.summary,
            "when_to_use": self.when_to_use,
            "inputs": self.inputs,
            "outputs": self.outputs,
            "requires": self.requires,
            "available": all(shutil.which(t) is not None for t in self.requires),
        }


def _run(cmd: list[str], timeout: int = 60, cwd: pathlib.Path = ROOT) -> dict:
    """Run a shell command, capture output, never raise."""
    try:
        p = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=str(cwd)
        )
        return {"rc": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except FileNotFoundError as e:
        return {"rc": 127, "stdout": "", "stderr": f"tool not found: {e}"}
    except subprocess.TimeoutExpired:
        return {"rc": 124, "stdout": "", "stderr": f"timeout after {timeout}s"}


# --------------------------------------------------------------------------- #
# Handler: spec_query
# --------------------------------------------------------------------------- #
def _resolve_spec_source() -> pathlib.Path | None:
    for p in SPEC_SOURCES:
        if p.exists():
            return p
    return None


def _load_spec_passages(source: pathlib.Path) -> list[dict]:
    """Return list of {ref, text} passages from the spec source."""
    if source.suffix.lower() == ".pdf":
        try:
            import pdfplumber  # lazy: only needed when a PDF is present
        except ImportError:
            return [{
                "ref": "error",
                "text": "pdfplumber not installed. Run: pip install pdfplumber",
            }]
        passages = []
        with pdfplumber.open(str(source)) as pdf:
            for i, page in enumerate(pdf.pages):
                txt = page.extract_text() or ""
                if txt.strip():
                    passages.append({"ref": f"page {i + 1}", "text": txt})
        return passages
    # markdown: split on headers so each section is a passage
    text = source.read_text(encoding="utf-8", errors="replace")
    passages, cur_ref, cur = [], "preamble", []
    for line in text.splitlines():
        if line.startswith("#"):
            if cur:
                passages.append({"ref": cur_ref, "text": "\n".join(cur)})
            cur_ref, cur = line.lstrip("# ").strip(), [line]
        else:
            cur.append(line)
    if cur:
        passages.append({"ref": cur_ref, "text": "\n".join(cur)})
    return passages


def _score(question: str, text: str) -> int:
    """Cheap keyword overlap score — no embeddings needed."""
    terms = {w.lower().strip("?.,()") for w in question.split() if len(w) > 2}
    low = text.lower()
    return sum(low.count(t) for t in terms)


def skill_spec_query(args: dict) -> dict:
    """Retrieve passages from the 3GPP spec relevant to a question, and (if an
    OPENAI_API_KEY is present) synthesize a grounded answer."""
    question = args.get("question")
    top_k = int(args.get("top_k", 4))
    if not question:
        return {"ok": False, "error": "spec_query requires --question"}

    source = _resolve_spec_source()
    if source is None:
        return {
            "ok": False,
            "error": "no spec source found",
            "looked_in": [str(p) for p in SPEC_SOURCES],
            "hint": "drop the 3GPP TS 38.211 PDF at spec/spec.pdf",
        }

    passages = _load_spec_passages(source)
    ranked = sorted(passages, key=lambda p: _score(question, p["text"]), reverse=True)
    hits = [p for p in ranked if _score(question, p["text"]) > 0][:top_k]
    if not hits:
        hits = ranked[:1]

    result = {
        "ok": True,
        "source": str(source.relative_to(ROOT)),
        "question": question,
        "passages": [{"ref": h["ref"], "excerpt": h["text"][:1200]} for h in hits],
    }

    # Optional LLM synthesis — degrades gracefully when no key / no SDK.
    answer = _synthesize_answer(question, hits)
    if answer:
        result["answer"] = answer
    return result


def _synthesize_answer(question: str, hits: list[dict]) -> str | None:
    import os
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    try:
        import openai
    except ImportError:
        return None
    context = "\n\n".join(f"[{h['ref']}]\n{h['text'][:1500]}" for h in hits)
    try:
        client = openai.OpenAI(api_key=key)
        completion = client.chat.completions.create(
            model="gpt-4o",
            max_tokens=600,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Answer strictly from the provided 3GPP spec passages. "
                        "Cite the [ref] you used. If the passages do not contain the "
                        "answer, say so plainly."
                    ),
                },
                {
                    "role": "user",
                    "content": f"Question: {question}\n\nPassages:\n{context}",
                },
            ],
        )
        return completion.choices[0].message.content.strip()
    except Exception as e:  # noqa: BLE001 — never let scoring crash the skill
        return f"(LLM synthesis skipped: {e})"


# --------------------------------------------------------------------------- #
# Handler: simulate
# --------------------------------------------------------------------------- #
def skill_simulate(args: dict) -> dict:
    rtl = ROOT / args.get("rtl", "generated/rtl/butterfold_top.v")
    tb = ROOT / args.get("tb", "tests/tb_butterfold_top.v")
    timeout = int(args.get("timeout", 30))
    if not rtl.exists():
        return {"ok": False, "error": f"RTL not found: {rtl}"}
    if not tb.exists():
        return {"ok": False, "error": f"testbench not found: {tb}"}

    with tempfile.TemporaryDirectory() as td:
        vvp = pathlib.Path(td) / "build.vvp"
        comp = _run(
            ["iverilog", "-g2012", "-Wall", "-o", str(vvp), str(rtl), str(tb)],
            timeout=timeout,
        )
        if comp["rc"] != 0:
            return {"ok": False, "stage": "compile", "compiled": False,
                    "log": comp["stderr"] or comp["stdout"]}
        sim = _run(["vvp", str(vvp)], timeout=timeout)
        out = sim["stdout"]
        passed = out.upper().count("PASS")
        failed = out.upper().count("FAIL")
        return {
            "ok": failed == 0 and sim["rc"] == 0,
            "compiled": True,
            "ran": sim["rc"] == 0,
            "passed": passed,
            "failed": failed,
            "log": out[-2000:],
        }


# --------------------------------------------------------------------------- #
# Handler: synthesize / area_estimate / timing (yosys-backed)
# --------------------------------------------------------------------------- #
def _yosys_stat(rtl: pathlib.Path, top: str, timeout: int) -> dict:
    """Run synth + stat, return parsed cell counts."""
    json_out = GEN / "synth" / "stat.json"
    json_out.parent.mkdir(parents=True, exist_ok=True)
    script = (
        f"read_verilog {rtl}; "
        f"synth -top {top} -flatten; "
        f"stat -json; "
        f"write_json {json_out}"
    )
    res = _run(["yosys", "-q", "-p", script], timeout=timeout)
    cells = {}
    total = 0
    # yosys prints stat as text too; parse "Number of cells: N"
    for line in res["stdout"].splitlines():
        line = line.strip()
        if line.startswith("Number of cells:"):
            try:
                total = int(line.split(":")[1])
            except ValueError:
                pass
    return {"rc": res["rc"], "log": (res["stderr"] or res["stdout"])[-2000:],
            "total_cells": total, "cells": cells}


def skill_synthesize(args: dict) -> dict:
    rtl = ROOT / args.get("rtl", "generated/rtl/butterfold_top.v")
    top = args.get("top", "butterfold_top")
    timeout = int(args.get("timeout", 60))
    if not rtl.exists():
        return {"ok": False, "error": f"RTL not found: {rtl}"}
    stat = _yosys_stat(rtl, top, timeout)
    return {
        "ok": stat["rc"] == 0,
        "top": top,
        "total_cells": stat["total_cells"],
        "netlist": "generated/synth/stat.json",
        "log": stat["log"],
    }


# Rough GF180MCU 7-track area per generic cell (um^2). Calibrate later against
# real .lib characterization; good enough for relative DSE comparisons.
GF180_AREA_PER_CELL_UM2 = 9.7


def skill_area_estimate(args: dict) -> dict:
    rtl = ROOT / args.get("rtl", "generated/rtl/butterfold_top.v")
    top = args.get("top", "butterfold_top")
    per_cell = float(args.get("area_per_cell", GF180_AREA_PER_CELL_UM2))
    timeout = int(args.get("timeout", 60))
    if not rtl.exists():
        return {"ok": False, "error": f"RTL not found: {rtl}"}
    stat = _yosys_stat(rtl, top, timeout)
    cells = stat["total_cells"]
    return {
        "ok": stat["rc"] == 0,
        "total_cells": cells,
        "est_area_um2": round(cells * per_cell, 1),
        "area_model": f"GF180 ~{per_cell} um^2/cell (rough)",
        "log": stat["log"],
    }


def skill_timing(args: dict) -> dict:
    """Logic-depth proxy via yosys 'ltp' (longest topological path). If opensta
    is available and a netlist+sdc are given, prefer that for real STA."""
    rtl = ROOT / args.get("rtl", "generated/rtl/butterfold_top.v")
    top = args.get("top", "butterfold_top")
    timeout = int(args.get("timeout", 60))
    if not rtl.exists():
        return {"ok": False, "error": f"RTL not found: {rtl}"}
    script = f"read_verilog {rtl}; synth -top {top} -flatten; ltp"
    res = _run(["yosys", "-q", "-p", script], timeout=timeout)
    depth = None
    for line in res["stdout"].splitlines():
        if "longest topological path" in line.lower():
            for tok in line.split():
                if tok.isdigit():
                    depth = int(tok)
    return {
        "ok": res["rc"] == 0,
        "logic_depth": depth,
        "note": "logic-depth proxy (yosys ltp); run opensta for ns-accurate STA",
        "opensta_available": shutil.which("sta") is not None,
        "log": (res["stderr"] or res["stdout"])[-1500:],
    }


# --------------------------------------------------------------------------- #
# Catalog registry
# --------------------------------------------------------------------------- #
CATALOG: dict[str, Skill] = {
    "spec_query": Skill(
        name="spec_query",
        category="spec",
        summary="Retrieve grounded answers from the 3GPP TS 38.211 spec.",
        when_to_use=(
            "When a subtask needs a standards fact: CP length, subcarrier "
            "spacing, RB size, transform-precoding rule, modulation order, EVM "
            "limit. Ground RTL parameters in the actual spec instead of guessing."
        ),
        inputs={"question": "natural-language question", "top_k": "passages (default 4)"},
        outputs={"answer": "grounded answer (if API key)", "passages": "cited excerpts"},
        requires=[],  # pdfplumber only if a PDF source is used
        handler=skill_spec_query,
    ),
    "simulate": Skill(
        name="simulate",
        category="eda",
        summary="Compile + run RTL against a testbench (iverilog/vvp).",
        when_to_use="After RTL exists, to check functional correctness and waveform tests.",
        inputs={"rtl": "path to RTL", "tb": "path to testbench", "timeout": "seconds"},
        outputs={"passed": "PASS count", "failed": "FAIL count", "log": "sim tail"},
        requires=["iverilog", "vvp"],
        handler=skill_simulate,
    ),
    "synthesize": Skill(
        name="synthesize",
        category="eda",
        summary="Synthesize RTL to a gate-level netlist (yosys).",
        when_to_use="After simulation passes, to get a structural netlist + cell count.",
        inputs={"rtl": "path to RTL", "top": "top module", "timeout": "seconds"},
        outputs={"total_cells": "gate count", "netlist": "json netlist path"},
        requires=["yosys"],
        handler=skill_synthesize,
    ),
    "area_estimate": Skill(
        name="area_estimate",
        category="eda",
        summary="Estimate gate count + silicon area (yosys stat, GF180 model).",
        when_to_use="During design-space exploration, to compare variants by area.",
        inputs={"rtl": "path to RTL", "top": "top module", "area_per_cell": "um^2/cell"},
        outputs={"total_cells": "gate count", "est_area_um2": "rough area"},
        requires=["yosys"],
        handler=skill_area_estimate,
    ),
    "timing": Skill(
        name="timing",
        category="eda",
        summary="Estimate logic depth / critical path (yosys ltp; opensta if present).",
        when_to_use="To gauge max frequency feasibility and spot deep combinational paths.",
        inputs={"rtl": "path to RTL", "top": "top module", "timeout": "seconds"},
        outputs={"logic_depth": "longest topological path", "note": "method"},
        requires=["yosys"],
        handler=skill_timing,
    ),
}


# --------------------------------------------------------------------------- #
# Public API (used by the meta-planner)
# --------------------------------------------------------------------------- #
def manifest() -> dict:
    """The machine-readable catalog the meta-planner reasons over."""
    return {
        "version": "1.0",
        "skills": [s.to_manifest() for s in CATALOG.values()],
    }


def write_manifest() -> pathlib.Path:
    GEN.mkdir(parents=True, exist_ok=True)
    out = GEN / "skills_catalog.json"
    out.write_text(json.dumps(manifest(), indent=2))
    return out


def run_skill(name: str, args: dict) -> dict:
    if name not in CATALOG:
        return {"ok": False, "error": f"unknown skill '{name}'",
                "available": list(CATALOG)}
    return CATALOG[name].handler(args)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _parse_kv(argv: list[str]) -> dict:
    args = {}
    i = 0
    while i < len(argv):
        if argv[i].startswith("--"):
            key = argv[i][2:]
            val = argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else "true"
            args[key] = val
            i += 2
        else:
            i += 1
    return args


def main(argv: list[str]) -> None:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return

    cmd = argv[0]
    if cmd == "list":
        for s in CATALOG.values():
            tools = ",".join(s.requires) or "-"
            print(f"  {s.name:14s} [{s.category}] needs:{tools:18s} {s.summary}")
        return
    if cmd == "manifest":
        out = write_manifest()
        print(json.dumps(manifest(), indent=2))
        print(f"\n[skills] manifest written to {out.relative_to(ROOT)}")
        return
    if cmd == "check":
        for s in CATALOG.values():
            ok = all(shutil.which(t) for t in s.requires)
            mark = "OK " if ok else "MISS"
            print(f"  [{mark}] {s.name:14s} requires: {s.requires or '-'}")
        return
    if cmd == "run":
        if len(argv) < 2:
            print("usage: run <skill> [--arg value ...]")
            return
        name = argv[1]
        result = run_skill(name, _parse_kv(argv[2:]))
        print(json.dumps(result, indent=2))
        return

    print(f"unknown command: {cmd}\n")
    print(__doc__)


if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
