"""
Debug Agent — reads verification errors, asks Claude to patch the RTL, then
re-runs verification. Loops up to MAX_ITERATIONS times.

Input : generated/verify_result.json + generated/rtl/butterfold_top.v
Output: updated generated/rtl/butterfold_top.v  (overwritten in place)
"""
import os, json, pathlib, importlib.util, time
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

RTL_FILE    = ROOT / "generated" / "rtl" / "butterfold_top.v"
RESULT_FILE = ROOT / "generated" / "verify_result.json"
SPEC_PATH   = ROOT / "modular_description.md"

MAX_ITERATIONS = 5
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
            print(f"[debug] Rate limit hit (attempt {attempt}/{MAX_RETRIES}), waiting {wait_time}s...")
            time.sleep(wait_time)
            wait_time *= 2


SYSTEM_PROMPT = """\
You are a Verilog RTL debug agent.
Given a Verilog module that failed verification, the error log, and the original spec,
produce a corrected version of the full Verilog file.

Rules:
- Fix only what the errors indicate — do not restructure the whole design
- Preserve all port names, module names, and parameter values exactly
- Keep synthesizability rules: no initial blocks in RTL, no $display/$finish,
  synchronous rst_n, posedge clk flip-flops, fixed-point only
- NO SystemVerilog unpacked arrays (e.g., "logic data [0:11]")
- NO array slicing or range indexing (e.g., "data[0:11]")
- NO tasks/functions with array ports — use scalar loops instead
- Use ONLY Verilog-2005 constructs for iverilog compatibility
- Return ONLY the corrected Verilog, no explanation, no markdown fences"""


def _load_verify_agent():
    """Load verify.agent module despite the dot in its filename."""
    verify_path = pathlib.Path(__file__).parent / "verify.agent.py"
    spec = importlib.util.spec_from_file_location("verify_agent", verify_path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _strip_fences(text):
    if "```" not in text:
        return text.strip()
    text = text.split("```", 1)[1]
    if text.lower().startswith(("verilog", "systemverilog", "sv")):
        text = text.split("\n", 1)[1]
    return text.rsplit("```", 1)[0].strip()


def run():
    if not RESULT_FILE.exists():
        print("[debug] No verify_result.json — run verify.agent.py first")
        return

    result = json.loads(RESULT_FILE.read_text())
    if result.get("syntax_ok") and result.get("sim_ok"):
        print("[debug] Design already passing — nothing to debug.")
        return

    spec         = SPEC_PATH.read_text()
    client       = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    verify_agent = _load_verify_agent()

    for iteration in range(1, MAX_ITERATIONS + 1):
        # Combine all error signals from the richer verify result
        errors     = "\n".join(result.get("errors", [])     or ["unknown error"])
        fix_hints  = "\n".join(result.get("fix_hints", [])  or [])
        spec_issues = "\n".join(
            f"[{i.get('severity','?').upper()}] {i.get('description','')} (near: {i.get('line_hint','')})"
            for i in result.get("spec_issues", [])
            if i.get("severity") == "error"
        )

        rtl = RTL_FILE.read_text()
        print(f"[debug] Iteration {iteration} — sending errors to LLM")

        prompt = (
            f"Original specification:\n{spec}\n\n"
            f"Current RTL:\n{rtl}\n\n"
            f"Verification errors:\n{errors}\n\n"
            + (f"Spec compliance issues:\n{spec_issues}\n\n" if spec_issues else "")
            + (f"Suggested fix hints from simulation analysis:\n{fix_hints}\n\n" if fix_hints else "")
            + "Produce the corrected Verilog."
        )

        completion = _call_with_retry(
            client.chat.completions.create,
            model="gpt-4o",
            max_tokens=8192,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": prompt},
            ],
        )

        fixed_rtl = _strip_fences(completion.choices[0].message.content)
        RTL_FILE.write_text(fixed_rtl)
        print("[debug] RTL updated — re-running verification")

        result    = verify_agent.run()
        syntax_ok = result.get("syntax_ok", False)
        spec_ok   = result.get("spec_ok", True)   # None = not run, treat as ok
        synth_ok  = result.get("synth_ok", True)
        sim_ok    = result.get("sim_ok")           # None = no TB, treat as ok

        all_ok = (syntax_ok
                  and (spec_ok is None or spec_ok)
                  and (synth_ok is None or synth_ok)
                  and (sim_ok   is None or sim_ok))

        if all_ok:
            print(f"[debug] Fixed after {iteration} iteration(s).")
            return

    print(f"[debug] Could not fix after {MAX_ITERATIONS} iterations.")
    print("[debug] Review generated/rtl/butterfold_top.v and generated/logs/ manually.")


if __name__ == "__main__":
    run()
