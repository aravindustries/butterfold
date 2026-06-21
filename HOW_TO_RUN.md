# How to Run ButterFold

A step-by-step guide from zero to generated RTL.

---

## What you need before starting

| Requirement | Check |
|---|---|
| Docker Desktop running | Open Docker Desktop — whale icon should be green |
| IIC-OSIC-TOOLS container started | VNC accessible at `http://localhost:80` |
| OpenAI API key | Get one at `https://platform.openai.com` |

---

## Step 1 — Open a terminal inside Docker

1. Open your browser and go to `http://localhost:80`
2. You will see a Linux desktop (the IIC-OSIC-TOOLS environment)
3. Right-click the desktop → **Open Terminal** (or use the taskbar)

All commands from here on are typed inside this terminal.

---

## Step 2 — Get the project into Docker

The Docker container can see files placed in `C:\Users\ashar\eda\designs` on your Windows machine (it appears as `/foss/designs` inside Docker).

```bash
cd /foss/designs
git clone <your-butterfold-repo-url> butterfold
cd butterfold
```

If you already have the folder there, just navigate to it:

```bash
cd /foss/designs/butterfold
```

---

## Step 3 — Install Python dependencies

```bash
pip install -r requirements.txt
```

This installs `openai`, `numpy`, `python-dotenv`, `langgraph`, and `pdfplumber`.

---

## Step 4 — Set your OpenAI API key

Open `.env` in a text editor:

```bash
nano .env
```

Replace the placeholder with your real key:

```
OPENAI_API_KEY=sk-...your-key-here...
```

Save and exit (`Ctrl+X` → `Y` → `Enter`).

---

## Step 5 — Write your module spec

The agents read `modular_description.md` as their hardware specification.

**Option A — Use the ButterFold spec (already filled in)**

The file `modular_description.md` already contains the full ButterFold spec.
Skip straight to Step 6.

**Option B — Design your own module**

```bash
cp modular_description.template.md modular_description.md
nano modular_description.md
```

Fill in every section of the template:
- Module name and ports
- Operating modes
- Processing steps (be explicit — name algorithms, sizes, bit widths)
- Key parameters
- Architecture constraints
- What to exclude

The more precise your spec, the fewer debug iterations the agents need.

---

## Step 6 — Run the automated workflow

```bash
python agents/orchestrator.py
```

This runs the full four-agent pipeline automatically:

```
planner  →  code_agent  →  verify  →  summarize
                               ↑          ↓
                             debug  ←  (if errors)
```

You will see live progress printed to the terminal:

```
[orchestrator] ── Step 1: Planner ──────────────────────────
[planner] Plan written to generated/plan.json
[planner] 8 subtasks generated

[orchestrator] ── Step 2: Code Agent ───────────────────────
[code_agent] Generating subtask: module_interface
[code_agent]  -> generated/rtl/module_interface.v
...
[code_agent] Combined RTL written to generated/rtl/butterfold_top.v

[orchestrator] ── Step 3: Verify ───────────────────────────
[verify] Syntax OK

[orchestrator] ── Step 5: Summarize ────────────────────────

==============================================================
  BUTTERFOLD WORKFLOW SUMMARY
==============================================================
• ...
==============================================================

[orchestrator] Summary saved → generated/summary.md
```

If the RTL has errors the debug node patches it and re-verifies automatically (up to 5 times).

---

## Step 7 — Check the outputs

| File | What it is |
|---|---|
| `generated/plan.json` | Structured task plan from the planner |
| `generated/rtl/butterfold_top.v` | Final synthesizable Verilog |
| `generated/rtl/<subtask>.v` | Per-subtask Verilog modules |
| `generated/verify_result.json` | Pass/fail + error log from iverilog |
| `generated/logs/syntax.log` | Full iverilog output |
| `generated/logs/sim.log` | Simulation output (if testbench was generated) |
| `generated/summary.md` | Human-readable run summary |

---

## Step 8 — Synthesize (optional)

Once verification passes, check area and gate count with Yosys:

```bash
yosys << 'EOF'
read_verilog generated/rtl/butterfold_top.v
synth -top butterfold_top
stat
write_verilog generated/synth/butterfold_top_synth.v
EOF
```

---

## Step 9 — RTL to GDS (optional)

Use LibreLane to run the full RTL-to-GDS flow on GF180:

```bash
# Copy the config template from the chipathon examples
cp -r ../sscs-chipathon-2026/examples/librelane_rtl2gds_gf180 ./librelane_run
cd librelane_run
# Edit config.json to point at ../generated/rtl/butterfold_top.v
# Then run the flow
librelane config.json
```

---

## Running agents individually

If you want to run one step at a time (useful for debugging):

```bash
python agents/planner.py          # create task plan
python agents/code_agent.py       # generate RTL
python agents/verify.agent.py     # syntax check + simulate
python agents/debug_agent.py      # fix errors (re-run if verify failed)
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `OPENAI_API_KEY` not set | Edit `.env` — make sure there are no spaces around `=` |
| `iverilog: command not found` | You are on the Windows host — open VNC at `http://localhost:80` and run from there |
| `ModuleNotFoundError: openai` | Run `pip install -r requirements.txt` |
| `generated/plan.json not found` | Run planner first: `python agents/planner.py` |
| Debug loops 5 times and still fails | Review `generated/rtl/butterfold_top.v` manually. Check `generated/logs/syntax.log` for the exact errors. Tighten the spec in `modular_description.md` and re-run |
| VNC screen is black | Restart the IIC-OSIC-TOOLS container in Docker Desktop |
| `pip install` fails (no internet in Docker) | Check Docker network settings — the container needs internet access for the OpenAI API |
