"""
Verilog Code Agent — iterates through the task plan and generates synthesizable
Verilog RTL for each subtask, then assembles a combined top-level file.

Deep-agent pattern: each subtask goes through a generate → critique → revise
inner loop before the output is accepted. This catches port mismatches, wrong
bit widths, and unsynthesizable constructs before iverilog ever sees the file.

Input : generated/plan.json + modular_description.md
        (optional) 3GPP_ButterFold_Spec_Extract.md  — loaded automatically if present
Output: generated/rtl/<subtask_id>.v  +  generated/rtl/butterfold_top.v
"""
import os, json, pathlib
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

PLAN_PATH    = ROOT / "generated" / "plan.json"
SPEC_PATH    = ROOT / "modular_description.md"
GPP_PATH     = ROOT / "3GPP_ButterFold_Spec_Extract.md"
RTL_DIR      = ROOT / "generated" / "rtl"

SYSTEM_PROMPT = """\
You are a synthesizable Verilog RTL generation agent.
Given a hardware design spec and a subtask, generate clean, synthesizable Verilog.

Hard rules:
- No `initial` blocks in RTL (testbenches only)
- No $display, $finish, or other simulation-only constructs in RTL
- Synchronous active-low reset (rst_n)
- All flip-flops on posedge clk
- Fixed-point arithmetic only — no real or float types
- No automatic variables; use explicit widths on all signals
- Return ONLY the Verilog code — no explanation, no markdown fences, no comments
  beyond what is architecturally required"""

CRITIQUE_PROMPT = """\
You are a senior RTL reviewer. Given a Verilog module and its specification,
list every issue you find. Be specific — include line or signal names.

Categories to check:
1. Synthesizability: initial blocks, $display, real/float types, unsupported constructs
2. Port compliance: do all ports in the spec appear with correct widths?
3. Reset compliance: is reset synchronous active-low (rst_n)?
4. Arithmetic: are all operations fixed-point? Any implicit width mismatches?
5. Spec compliance: does the logic match the described algorithm?

If there are NO issues, respond with exactly: NO_ISSUES
Otherwise list issues one per line, prefixed with the category name."""

REVISE_PROMPT = """\
You are a Verilog RTL debug agent.
Given a Verilog module, a list of reviewer issues, and the original spec,
return a corrected version of the complete Verilog file.

Rules:
- Address every listed issue
- Preserve all port names and module names exactly
- Return ONLY the corrected Verilog — no markdown fences, no explanation"""


def _strip_fences(text: str) -> str:
    if "```" not in text:
        return text.strip()
    text = text.split("```", 1)[1]
    if text.lower().startswith(("verilog", "systemverilog", "sv")):
        text = text.split("\n", 1)[1]
    return text.rsplit("```", 1)[0].strip()


def _load_gpp_context() -> str:
    """Load extracted 3GPP spec if available; return empty string otherwise."""
    if GPP_PATH.exists():
        content = GPP_PATH.read_text().strip()
        print(f"[code_agent] Loaded 3GPP context from {GPP_PATH.name} "
              f"({len(content)} chars)")
        return content
    return ""


def generate_subtask(client, spec, plan, subtask, prior_rtl="", gpp_context=""):
    """Deep-agent inner loop: generate → critique → revise (if needed)."""
    constraints = plan.get("hardware_constraints", {})

    context_parts = [f"Full specification:\n{spec}"]
    if gpp_context:
        context_parts.append(f"3GPP standard reference (for algorithm accuracy):\n{gpp_context}")
    context_parts += [
        f"Hardware constraints:\n{json.dumps(constraints, indent=2)}",
        f"Overall plan:\n{json.dumps(plan, indent=2)}",
    ]
    if prior_rtl:
        context_parts.append(f"Previously generated RTL (for interface consistency):\n{prior_rtl}")
    context_parts.append(
        f"Subtask to implement now:\n{json.dumps(subtask, indent=2)}\n\n"
        f"Constraint basis: {subtask.get('constraint_basis', '')}\n"
        f"Waveform properties to preserve: {constraints.get('waveform_properties', [])}"
    )
    user_content = "\n\n".join(context_parts)

    # --- Stage 1: Generate ---
    completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=8192,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": user_content},
        ],
    )
    rtl = _strip_fences(completion.choices[0].message.content)
    print(f"[code_agent]   stage1: generated {rtl.count(chr(10))} lines")

    # --- Stage 2: Critique (deep-agent self-review) ---
    critique_completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=1024,
        messages=[
            {"role": "system", "content": CRITIQUE_PROMPT},
            {"role": "user",   "content": f"Spec:\n{spec}\n\nVerilog to review:\n{rtl}"},
        ],
    )
    critique = critique_completion.choices[0].message.content.strip()

    if critique == "NO_ISSUES":
        print(f"[code_agent]   stage2: critique clean — no revision needed")
        return rtl

    print(f"[code_agent]   stage2: critique found issues — revising")

    # --- Stage 3: Revise ---
    revise_completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=8192,
        messages=[
            {"role": "system", "content": REVISE_PROMPT},
            {"role": "user",   "content": (
                f"Original spec:\n{spec}\n\n"
                f"Reviewer issues:\n{critique}\n\n"
                f"Verilog to fix:\n{rtl}"
            )},
        ],
    )
    revised = _strip_fences(revise_completion.choices[0].message.content)
    print(f"[code_agent]   stage3: revised to {revised.count(chr(10))} lines")
    return revised


def run():
    if not PLAN_PATH.exists():
        raise FileNotFoundError("generated/plan.json not found — run planner.py first")

    spec        = SPEC_PATH.read_text()
    plan        = json.loads(PLAN_PATH.read_text())
    gpp_context = _load_gpp_context()
    RTL_DIR.mkdir(parents=True, exist_ok=True)

    client          = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    accumulated_rtl = ""

    for subtask in plan["subtasks"]:
        print(f"[code_agent] Generating subtask: {subtask['id']}")
        rtl = generate_subtask(client, spec, plan, subtask, accumulated_rtl, gpp_context)

        out_file = RTL_DIR / f"{subtask['id']}.v"
        out_file.write_text(rtl)
        accumulated_rtl += f"\n// --- {subtask['id']} ---\n{rtl}\n"
        print(f"[code_agent]  -> {out_file}")

    top_file = RTL_DIR / "butterfold_top.v"
    top_file.write_text(accumulated_rtl.strip())
    print(f"[code_agent] Combined RTL written to {top_file}")


if __name__ == "__main__":
    run()
