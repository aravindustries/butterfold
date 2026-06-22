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

PLAN_PATH      = ROOT / "generated" / "plan.json"
SPEC_PATH      = ROOT / "modular_description.md"
GPP_PATH       = ROOT / "3GPP_ButterFold_Spec_Extract.md"
REFERENCE_PATH = ROOT / "butterfold_reference.v"
RTL_DIR        = ROOT / "generated" / "rtl"

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
You are a Verilog RTL refinement agent. You are given a reference implementation
and asked to improve it, not generate from scratch.

Your tasks may include:
1. Optimize for area (reduce bit widths, simplify logic)
2. Optimize for timing (add pipelining, reduce critical paths)
3. Fix bugs or incomplete sections (marked with comments like "// TODO" or "// SIMPLIFIED")
4. Add missing features while preserving the core algorithm

Hard rules:
- Preserve all port names, module names, and external interfaces exactly
- Preserve the overall architecture and state machine structure
- No `initial` blocks in RTL (testbenches only)
- No SystemVerilog unpacked arrays, array slicing, or array function ports
- Synchronous active-low reset (rst_n)
- All flip-flops on posedge clk
- Fixed-point arithmetic only — no real/float keywords
- Use only Verilog-2005 constructs for iverilog compatibility
- Return ONLY the complete corrected Verilog file — no explanation, no markdown fences"""

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


def refine_from_reference(client, spec, plan, reference_rtl, gpp_context=""):
    """Deep-agent refinement: take reference RTL and improve it."""
    constraints = plan.get("hardware_constraints", {})

    context_parts = [
        f"Specification:\n{spec}",
    ]
    if gpp_context:
        context_parts.append(f"3GPP standard reference:\n{gpp_context}")
    context_parts += [
        f"Hardware constraints:\n{json.dumps(constraints, indent=2)}",
        f"Design plan:\n{json.dumps(plan, indent=2)}",
        f"Reference RTL (to refine, not replace):\n{reference_rtl}",
    ]
    user_content = "\n\n".join(context_parts)

    # --- Stage 1: Review and suggest improvements ---
    print(f"[code_agent]   stage1: analyzing reference RTL")
    review_completion = _call_with_retry(
        client.chat.completions.create,
        model="gpt-4o",
        max_tokens=2048,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a senior hardware architect reviewing a Verilog reference implementation. "
                    "Identify areas for improvement: incomplete sections (marked // SIMPLIFIED or // TODO), "
                    "potential bugs, optimization opportunities, or missing functionality. "
                    "Be specific about what needs improvement and how. Return a list of issues."
                ),
            },
            {"role": "user", "content": user_content},
        ],
    )
    review = review_completion.choices[0].message.content.strip()
    print(f"[code_agent]   stage1: review complete ({len(review)} chars)")

    # --- Stage 2: Refine the RTL based on review ---
    print(f"[code_agent]   stage2: refining RTL")
    refine_completion = _call_with_retry(
        client.chat.completions.create,
        model="gpt-4o",
        max_tokens=8192,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a Verilog RTL refinement expert. "
                    "Given a reference implementation and a list of improvement areas, "
                    "produce an improved version of the complete Verilog file. "
                    "Preserve the module interface and overall architecture. "
                    "Replace // SIMPLIFIED sections with correct implementations. "
                    "Return ONLY the complete refined Verilog file — no markdown, no explanation."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Specification:\n{spec}\n\n"
                    f"Areas for improvement:\n{review}\n\n"
                    f"Reference RTL to refine:\n{reference_rtl}\n\n"
                    f"Produce the refined Verilog."
                ),
            },
        ],
    )
    refined = _strip_fences(refine_completion.choices[0].message.content)
    print(f"[code_agent]   stage2: refined to {refined.count(chr(10))} lines")

    return refined


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
    if not REFERENCE_PATH.exists():
        raise FileNotFoundError(f"Reference RTL not found: {REFERENCE_PATH}")

    spec        = SPEC_PATH.read_text()
    plan        = json.loads(PLAN_PATH.read_text())
    gpp_context = _load_gpp_context()
    reference   = REFERENCE_PATH.read_text()
    RTL_DIR.mkdir(parents=True, exist_ok=True)

    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    print(f"[code_agent] Refining RTL from reference: {REFERENCE_PATH.name}")
    rtl = refine_from_reference(client, spec, plan, reference, gpp_context)

    top_file = RTL_DIR / "butterfold_top.v"
    top_file.write_text(rtl)
    print(f"[code_agent] Refined RTL written to {top_file}")


if __name__ == "__main__":
    run()
