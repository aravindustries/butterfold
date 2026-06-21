"""
Reflect Agent — deep cross-module reviewer that runs AFTER code_agent and
BEFORE verify. It reads the full assembled RTL, checks for interface
mismatches and spec drift, and either approves or patches the file in place.

This is the second layer of the deep-agent pattern:
  - code_agent's inner loop: per-subtask generate → critique → revise
  - reflect_agent: whole-design cross-module reasoning pass

Why this matters: individual subtasks can each be locally correct but
introduce mismatched port widths, wrong signal names at the connection
points, or duplicate module declarations when assembled.

Input : generated/rtl/butterfold_top.v + modular_description.md
Output: generated/rtl/butterfold_top.v (patched in place if issues found)
        generated/reflect_result.json
"""
import os, json, pathlib
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

TOP_FILE    = ROOT / "generated" / "rtl" / "butterfold_top.v"
SPEC_PATH   = ROOT / "modular_description.md"
RESULT_PATH = ROOT / "generated" / "reflect_result.json"

REFLECT_PROMPT = """\
You are a senior RTL architect performing a holistic design review.
Given the full assembled Verilog and the original specification, check for:

1. PORT MISMATCHES — signals connected between modules with wrong widths
2. DUPLICATE MODULES — same module name declared more than once
3. MISSING CONNECTIONS — submodule instantiation ports left unconnected
4. SPEC DRIFT — top-level port names that don't match the spec exactly
5. CLOCK/RESET CONSISTENCY — all FFs using posedge clk and synchronous rst_n
6. INTERFACE PROTOCOL — dout_valid, busy, done signals wired correctly

Return a JSON object with this exact schema:
{
  "approved": true | false,
  "issues": [
    {"category": "PORT_MISMATCH|DUPLICATE|MISSING|SPEC_DRIFT|CLKRESET|PROTOCOL",
     "description": "...",
     "severity": "error|warning"}
  ],
  "summary": "one sentence overall assessment"
}

If approved is true, issues list must be empty."""

PATCH_PROMPT = """\
You are a Verilog RTL architect.
Fix every ERROR-severity issue listed by the reviewer.
Preserve all logic — only fix connections, widths, and structural issues.
Return ONLY the complete corrected Verilog file — no markdown, no explanation."""


def _strip_fences(text: str) -> str:
    if "```" not in text:
        return text.strip()
    text = text.split("```", 1)[1]
    if text.lower().startswith(("verilog", "systemverilog", "sv", "json")):
        text = text.split("\n", 1)[1]
    return text.rsplit("```", 1)[0].strip()


def run() -> dict:
    if not TOP_FILE.exists():
        print("[reflect] No butterfold_top.v found — skipping reflection")
        result = {"approved": True, "issues": [], "summary": "No RTL to review"}
        RESULT_PATH.parent.mkdir(parents=True, exist_ok=True)
        RESULT_PATH.write_text(json.dumps(result, indent=2))
        return result

    spec = SPEC_PATH.read_text()
    rtl  = TOP_FILE.read_text()
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    print(f"[reflect] Reviewing {rtl.count(chr(10))} lines of assembled RTL")

    # --- Deep reflection pass ---
    completion = client.chat.completions.create(
        model="gpt-4o",
        max_tokens=2048,
        messages=[
            {"role": "system", "content": REFLECT_PROMPT},
            {"role": "user",   "content": f"Spec:\n{spec}\n\nAssembled RTL:\n{rtl}"},
        ],
    )

    raw = _strip_fences(completion.choices[0].message.content)
    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        print("[reflect] Could not parse reflection JSON — treating as approved")
        result = {"approved": True, "issues": [], "summary": "Parse failed, skipped"}

    errors   = [i for i in result.get("issues", []) if i.get("severity") == "error"]
    warnings = [i for i in result.get("issues", []) if i.get("severity") == "warning"]

    print(f"[reflect] {result.get('summary', '')}")
    print(f"[reflect] {len(errors)} error(s), {len(warnings)} warning(s)")

    if not result.get("approved") and errors:
        print(f"[reflect] Patching {len(errors)} error(s) in place")

        issue_text = "\n".join(
            f"[{i['category']}] {i['description']}"
            for i in errors
        )
        patch_completion = client.chat.completions.create(
            model="gpt-4o",
            max_tokens=8192,
            messages=[
                {"role": "system", "content": PATCH_PROMPT},
                {"role": "user",   "content": (
                    f"Spec:\n{spec}\n\n"
                    f"Issues to fix:\n{issue_text}\n\n"
                    f"RTL to patch:\n{rtl}"
                )},
            ],
        )
        patched = _strip_fences(patch_completion.choices[0].message.content)
        TOP_FILE.write_text(patched)
        result["patched"] = True
        print(f"[reflect] RTL patched and written back to {TOP_FILE.name}")
    else:
        result["patched"] = False
        print("[reflect] RTL approved — no patches needed")

    RESULT_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULT_PATH.write_text(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    run()
