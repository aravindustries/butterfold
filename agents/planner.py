"""
Task Planning Agent — reads modular_description.md and produces a structured
JSON task plan broken into ordered hardware subtasks.

Input : modular_description.md
Output: generated/plan.json
"""
import os, json, pathlib
import anthropic
from dotenv import load_dotenv

ROOT = pathlib.Path(__file__).parent.parent
load_dotenv(ROOT / ".env")

SPEC_PATH = ROOT / "modular_description.md"
OUT_PATH  = ROOT / "generated" / "plan.json"

SYSTEM_PROMPT = """\
You are a digital hardware design planning agent.
Given a Verilog module specification, break it into an ordered list of subtasks.
Each subtask must have:
  id          — short snake_case identifier
  description — what to implement in one sentence
  inputs      — list of port/signal names relevant to this subtask
  outputs     — list of port/signal names this subtask produces
  depends_on  — list of subtask ids this depends on (empty list if none)
  test_cases  — list of brief test case descriptions (at least 2)

Return ONLY valid JSON matching this exact schema, with no explanation:
{
  "module_name": "string",
  "subtasks": [
    {
      "id": "string",
      "description": "string",
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
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    msg = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": spec}],
    )

    raw = msg.content[0].text.strip()
    if "```json" in raw:
        raw = raw.split("```json", 1)[1].split("```", 1)[0].strip()
    elif "```" in raw:
        raw = raw.split("```", 1)[1].split("```", 1)[0].strip()

    plan = json.loads(raw)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(plan, indent=2))
    print(f"[planner] Plan written to {OUT_PATH}")
    print(f"[planner] {len(plan['subtasks'])} subtasks generated")
    return plan


if __name__ == "__main__":
    run()
