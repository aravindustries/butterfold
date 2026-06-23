"""
Task Planning Agent — reads modular_description.md and produces a structured
JSON task plan broken into ordered hardware subtasks.

Input : modular_description.md
Output: generated/plan.json
"""
import os, json, pathlib, time
import openai
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

SPEC_PATH      = ROOT / "modular_description.md"
MODULE_IO_PATH = ROOT / "butterfold_module_io.md"   # authoritative 6-module port contract
OUT_PATH       = ROOT / "generated" / "plan.json"

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
            print(f"[planner] Rate limit hit (attempt {attempt}/{MAX_RETRIES}), waiting {wait_time}s...")
            time.sleep(wait_time)
            wait_time *= 2


SYSTEM_PROMPT = """\
You are a standards-aware hardware architecture planning agent.

Your job has two stages:

STAGE 1 — Translate the communication/waveform spec into hardware constraints.
Before planning any Verilog subtasks, extract the following from the specification:
  - Why each transform size (k, m) was chosen and what standard motivates it
  - Which parameters are frozen for tapeout vs open for design-space exploration
  - What TDD or half-duplex assumptions make RX/TX hardware reuse legal
  - What "compliance" means for this design (proof-of-concept vs full standard)
  - What waveform-level properties the RTL must preserve (e.g. DFT linearity,
    zero-in/zero-out, TX→RX loopback correctness, PAPR reduction intent)

STAGE 2 — Break the design into ordered implementation subtasks.
Each subtask must be bounded by the constraints extracted in Stage 1.
Each subtask must have:
  id               — short snake_case identifier
  description      — what to implement in one sentence
  constraint_basis — which hardware constraint from Stage 1 this subtask satisfies
  inputs           — list of port/signal names relevant to this subtask
  outputs          — list of port/signal names this subtask produces
  depends_on       — list of subtask ids this depends on (empty list if none)
  test_cases       — list of brief waveform-behavior test cases (at least 2)

Return ONLY valid JSON matching this exact schema, with no explanation:
{
  "module_name": "string",
  "hardware_constraints": {
    "transform_sizes": {"k": 0, "m": 0, "cp": 0},
    "standard_motivation": "string",
    "tdd_reuse_assumption": "string",
    "frozen_for_tapeout": ["string"],
    "open_for_dse": ["string"],
    "compliance_boundary": "string",
    "waveform_properties": ["string"]
  },
  "subtasks": [
    {
      "id": "string",
      "description": "string",
      "constraint_basis": "string",
      "inputs": ["string"],
      "outputs": ["string"],
      "depends_on": ["string"],
      "test_cases": ["string"]
    }
  ]
}"""


def run():
    if not SPEC_PATH.exists():
        raise FileNotFoundError(f"Spec not found: {SPEC_PATH}")

    spec   = SPEC_PATH.read_text()
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    # Additively include the authoritative 6-module port contract so the plan
    # decomposes into ButterFold's real module boundaries (mirrors how code_agent
    # loads the 3GPP extract). Optional — planning still works without it.
    user_content = spec
    if MODULE_IO_PATH.exists():
        module_io = MODULE_IO_PATH.read_text().strip()
        user_content = (
            f"{spec}\n\n"
            f"=== AUTHORITATIVE MODULE I/O CONTRACT (butterfold_module_io.md) ===\n"
            f"Decompose the design into these modules; use these exact port names/widths.\n\n"
            f"{module_io}"
        )
        print(f"[planner] Loaded module I/O contract ({len(module_io)} chars)")

    completion = _call_with_retry(
        client.chat.completions.create,
        model="gpt-4o",
        max_tokens=4096,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": user_content},
        ],
    )

    raw = completion.choices[0].message.content.strip()
    if "```json" in raw:
        raw = raw.split("```json", 1)[1].split("```", 1)[0].strip()
    elif "```" in raw:
        raw = raw.split("```", 1)[1].split("```", 1)[0].strip()

    plan = json.loads(raw)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(plan, indent=2))
    constraints = plan.get("hardware_constraints", {})
    print(f"[planner] Plan written to {OUT_PATH}")
    print(f"[planner] {len(plan['subtasks'])} subtasks generated")
    print(f"[planner] k={constraints.get('transform_sizes',{}).get('k')}  "
          f"m={constraints.get('transform_sizes',{}).get('m')}  "
          f"cp={constraints.get('transform_sizes',{}).get('cp')}")
    print(f"[planner] Standard motivation: {constraints.get('standard_motivation','')}")
    print(f"[planner] Compliance boundary: {constraints.get('compliance_boundary','')}")
    return plan


def _load_agent_core():
    import importlib.util
    p = pathlib.Path(__file__).parent / "agent_core.py"
    spec = importlib.util.spec_from_file_location("agent_core", p)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def _strip_json(raw: str) -> str:
    if "```json" in raw:
        return raw.split("```json", 1)[1].split("```", 1)[0].strip()
    if "```" in raw:
        return raw.split("```", 1)[1].split("```", 1)[0].strip()
    return raw.strip()


def run_react(max_rounds: int = 2):
    """Deep (reason+act) planner: generate -> self-critique against the 6-module
    contract -> revise. The planner produces text (a plan), not tool actions, so
    its 'loop' is a critique/revise reasoning loop (logged to the Journal) rather
    than a tool-using ReAct loop. Falls back to a single-shot run() with no key.
    """
    if not os.environ.get("OPENAI_API_KEY"):
        print("[planner] No API key — single-shot plan.")
        return run()

    core    = _load_agent_core()
    journal = core.Journal()
    plan    = run()                       # initial generation (already module-aware)
    journal.append("planner", "plan", f"initial plan: {len(plan.get('subtasks', []))} subtasks")

    client     = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    module_io  = MODULE_IO_PATH.read_text() if MODULE_IO_PATH.exists() else ""

    for rnd in range(1, max_rounds + 1):
        critique = _call_with_retry(
            client.chat.completions.create, model="gpt-4o", max_tokens=1024,
            messages=[
                {"role": "system", "content":
                 "You are a hardware planning reviewer. Given the 6-module I/O contract "
                 "and a JSON plan, list concrete gaps: modules from the contract not "
                 "covered by a subtask, wrong/missing depends_on edges, or missing "
                 "test_cases. If the plan is complete and correct, reply exactly OK."},
                {"role": "user", "content": f"CONTRACT:\n{module_io}\n\nPLAN:\n{json.dumps(plan, indent=2)}"},
            ],
        ).choices[0].message.content.strip()

        if critique.upper().startswith("OK"):
            journal.append("planner", "decision", f"round {rnd}: plan complete")
            print(f"[planner] Self-critique round {rnd}: plan complete.")
            break

        journal.append("planner", "finding", f"round {rnd} gaps: {critique[:200]}")
        print(f"[planner] Self-critique round {rnd} found gaps — revising.")
        revised = _call_with_retry(
            client.chat.completions.create, model="gpt-4o", max_tokens=4096,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content":
                 f"Revise this plan to address the gaps. Return ONLY the JSON.\n\n"
                 f"CONTRACT:\n{module_io}\n\nGAPS:\n{critique}\n\nCURRENT PLAN:\n{json.dumps(plan)}"},
            ],
        ).choices[0].message.content
        try:
            plan = json.loads(_strip_json(revised))
            OUT_PATH.write_text(json.dumps(plan, indent=2))
        except json.JSONDecodeError:
            print("[planner] Revision was not valid JSON — keeping prior plan.")
            break

    print(f"[planner] Final plan: {len(plan.get('subtasks', []))} subtasks.")
    return plan


if __name__ == "__main__":
    import sys
    if "--react" in sys.argv:
        run_react()
    else:
        run()
