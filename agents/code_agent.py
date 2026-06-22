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
import os, json, pathlib, time
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

PLAN_PATH    = ROOT / "generated" / "plan.json"
SPEC_PATH    = ROOT / "modular_description.md"
GPP_PATH     = ROOT / "3GPP_ButterFold_Spec_Extract.md"
RTL_DIR      = ROOT / "generated" / "rtl"

MAX_RETRIES = 5
INITIAL_WAIT = 1


def _call_with_retry(func, *args, **kwargs):
    """Retry OpenAI API calls with exponential backoff on rate limit errors."""
    wait_time = INITIAL_WAIT
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return func(*args, **kwargs)
        except openai.RateLimitError as e:
            if attempt == MAX_RETRIES:
                raise
            print(f"[code_agent] Rate limit hit (attempt {attempt}/{MAX_RETRIES}), waiting {wait_time}s...")
            time.sleep(wait_time)
            wait_time *= 2  # exponential backoff


SYSTEM_PROMPT = """\
You are a synthesizable Verilog RTL generation agent.
Given a hardware design spec and a subtask, generate clean, synthesizable Verilog
compatible with open-source simulators like iverilog.

Hard rules:
- No `initial` blocks in RTL (testbenches only)
- No $display, $finish, or other simulation-only constructs
- No SystemVerilog unpacked arrays (e.g., "logic data [0:11]")
- No array slicing or range indexing (e.g., "data[0:11]")
- No tasks or functions with array ports — use scalar loops instead
- Synchronous active-low reset (rst_n)
- All flip-flops on posedge clk
- Fixed-point arithmetic only — no real/float keywords
- No automatic variables; use explicit widths on all signals
- Use only Verilog-2005 constructs (loop through array elements one at a time)
- Return ONLY the Verilog code — no explanation, no markdown fences, no comments
  beyond what is architecturally required"""

CRITIQUE_PROMPT = """\
You are a senior RTL reviewer. Given a Verilog module and its specification,
list every issue you find. Be specific — include line or signal names.

Categories to check:
1. Verilog-2005 compliance: NO unpacked arrays (logic x [0:N]), NO array slicing (x[0:N]),
   NO arrays in task/function ports, NO real/float keywords
2. Synthesizability: initial blocks, $display, real/float types, unsupported constructs
3. Port compliance: do all ports in the spec appear with correct widths?
4. Reset compliance: is reset synchronous active-low (rst_n)?
5. Arithmetic: are all operations fixed-point? Any implicit width mismatches?
6. Spec compliance: does the logic match the described algorithm?

If there are NO issues, respond with exactly: NO_ISSUES
Otherwise list issues one per line, prefixed with the category name."""

REVISE_PROMPT = """\
You are a Verilog RTL debug agent.
Given a Verilog module, a list of reviewer issues, and the original spec,
return a corrected version of the complete Verilog file.

Rules:
- Address every listed issue
- Preserve all port names and module names exactly
- CRITICAL: use ONLY Verilog-2005 constructs — NO unpacked arrays, NO array slicing, NO array ports
- If you see "unpacked dimensions" errors, replace unpacked arrays with packed arrays or element-by-element loops
- If you see "Array cannot be indexed by a range", use individual element assignments instead
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
    completion = _call_with_retry(
        client.chat.completions.create,
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
    critique_completion = _call_with_retry(
        client.chat.completions.create,
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
    revise_completion = _call_with_retry(
        client.chat.completions.create,
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
