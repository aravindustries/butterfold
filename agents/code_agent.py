"""
Verilog Code Agent — iterates through the task plan and generates synthesizable
Verilog RTL for each subtask, then assembles a combined top-level file.

Input : generated/plan.json + modular_description.md
Output: generated/rtl/<subtask_id>.v  +  generated/rtl/butterfold_top.v
"""
import os, json, pathlib
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

PLAN_PATH = ROOT / "generated" / "plan.json"
SPEC_PATH = ROOT / "modular_description.md"
RTL_DIR   = ROOT / "generated" / "rtl"

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


def generate_subtask(client, spec, plan, subtask, prior_rtl=""):
    constraints = plan.get("hardware_constraints", {})
    context_parts = [
        f"Full specification:\n{spec}",
        f"Hardware constraints (extracted from waveform spec):\n{json.dumps(constraints, indent=2)}",
        f"Overall plan:\n{json.dumps(plan, indent=2)}",
    ]
    if prior_rtl:
        context_parts.append(f"Previously generated RTL (for context):\n{prior_rtl}")
    context_parts.append(
        f"Subtask to implement now:\n{json.dumps(subtask, indent=2)}\n\n"
        f"This subtask satisfies constraint: {subtask.get('constraint_basis', '')}\n"
        f"The RTL must preserve these waveform properties: "
        f"{constraints.get('waveform_properties', [])}"
    )

    completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=8192,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": "\n\n".join(context_parts)},
        ],
    )
    return completion.choices[0].message.content.strip()


def run():
    if not PLAN_PATH.exists():
        raise FileNotFoundError("generated/plan.json not found — run planner.py first")

    spec = SPEC_PATH.read_text()
    plan = json.loads(PLAN_PATH.read_text())
    RTL_DIR.mkdir(parents=True, exist_ok=True)

    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    accumulated_rtl = ""

    for subtask in plan["subtasks"]:
        print(f"[code_agent] Generating subtask: {subtask['id']}")
        rtl = generate_subtask(client, spec, plan, subtask, accumulated_rtl)

        # Strip markdown fences if model wrapped the output anyway
        if rtl.startswith("```"):
            rtl = rtl.split("```", 1)[1]
            if rtl.lower().startswith(("verilog", "systemverilog", "sv")):
                rtl = rtl.split("\n", 1)[1]
            rtl = rtl.rsplit("```", 1)[0].strip()

        out_file = RTL_DIR / f"{subtask['id']}.v"
        out_file.write_text(rtl)
        accumulated_rtl += f"\n// --- {subtask['id']} ---\n{rtl}\n"
        print(f"[code_agent]  -> {out_file}")

    top_file = RTL_DIR / "butterfold_top.v"
    top_file.write_text(accumulated_rtl.strip())
    print(f"[code_agent] Combined RTL written to {top_file}")


if __name__ == "__main__":
    run()
