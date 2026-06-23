# ButterFold — Repository Layout & Workflow

This document is the map of the project. Read it first if anything looks duplicated or confusing.

## Two directories, one repo

There is **one** GitHub repository — `github.com/aravindustries/butterfold` — checked out in two places:

| Path | Role | Rule |
|---|---|---|
| `…\Desktop\chipathon\agentic_workflow\butterfold` | **Canonical source** | Edit, commit, and push **here**. |
| `…\eda\designs\chipathon\butterfold` | **Docker run mirror** (mounts to `/foss/designs/...` in the IIC-OSIC-TOOLS container) | **Only `git pull` into it and run tools.** Never hand-edit. |

The flow is one-directional: **edit in Desktop → commit/push → `git pull` in eda → run the toolchain
(iverilog / yosys / LibreLane) in the container.** Keeping edits out of the eda mirror prevents the
two copies from drifting apart.

> Note: the outer `agentic_workflow\` folder is just a container for this repo; do not keep working
> copies of `main.py` / `butterfold_sim/` outside the repo.

## Directory map (canonical repo)

```
butterfold/
├── modular_description.md        # planner INPUT spec (high-level design intent)
├── butterfold_module_io.md       # authoritative 6-module port contract (source of truth)
├── 3GPP_ButterFold_Spec_Extract.md
├── gen_reference.py              # generates + golden-validates the LOCKED DSP kernel
├── butterfold_kernel.v           # GENERATED, LOCKED, bit-exact (ROMs + multiplier + round/clip)
├── butterfold_top.v              # hierarchical wrapper reference (FSM + CP + I/O) -> instantiates kernel
├── butterfold_reference.v        # flat single-module fallback (unchanged)
├── butterfold_sim/               # Python golden model (numpy)
├── agents/                       # the agentic pipeline (see flow below)
├── tests/                        # committed testbenches
├── librelane/                    # GF180 PnR config (config.yaml tracked; runs/ ignored)
├── generated/                    # agent outputs (gitignored — regenerated each run)
├── _hwcheck.py                   # standalone bit-exact regression harness (top+kernel vs golden)
└── REPO_LAYOUT.md                # this file
```

## Spec → silicon flow

```
modular_description.md  (+ butterfold_module_io.md)
        │
        ▼
   planner.py ─────────────► generated/plan.json   (decompose into modules)
        │
        ▼
   code_agent.py:
     • gen_reference.py  ─►  butterfold_kernel.v   (FFT/DFT math — LOCKED, bit-exact)
     • LLM refine_wrapper ─► butterfold_top.v      (FSM + CP + I/O — AGENT-AUTHORED)
        │                    (no API key → emits the validated reference wrapper)
        ▼
   reflect_agent.py  ─► verify.agent.py  ─► synth_agent.py  ─► summary
                         (golden EVM gate,    (Yosys GF180
                          multi-file compile)  area report)
        │ fail → debug_agent loop (≤5×, edits wrapper only)
        ▼
   LibreLane (librelane/config.yaml)  ─►  signed-off GF180 GDS
```

Key invariant: the **golden-model EVM check** (seed 42, threshold 2%, current 1.59%) is authoritative.
The `butterfold_kernel` is generated and never LLM-edited; only the wrapper is agent-authored, so a bad
edit cannot corrupt the bit-exact twiddle ROMs.

## How to run

```bash
# Host (Windows): regenerate + self-validate the kernel (needs python + numpy)
python gen_reference.py                     # expect: Stage-6 seed (42) EVM = 1.5915%

# Container (Docker, has openai + iverilog + yosys): full agentic flow
#   from the eda mirror after `git pull`
cd /foss/designs/chipathon/butterfold
python agents/orchestrator.py               # planner → code → reflect → verify → synth → summary

# Bit-exact regression check of the hierarchical split (host emits, container runs):
python _hwcheck.py emit                      # writes _tb_hwcheck.v + expected vector
#   (in container) iverilog -g2012 -o /tmp/g.vvp _tb_hwcheck.v butterfold_top.v butterfold_kernel.v && vvp /tmp/g.vvp > generated/logs/hwcheck.log
python _hwcheck.py compare                    # expect: byte-identical / EVM 1.5915%
```
