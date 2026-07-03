# ButterFold — Repository Layout & Workflow

Read this first if anything looks confusing. The design is built by agents from a
single spec; see `README.md` for the module list.

## Two directories, one repo

One GitHub repo — `github.com/aravindustries/butterfold` — checked out twice:

| Path | Role | Rule |
|---|---|---|
| `…\Desktop\chipathon\agentic_workflow\butterfold` | **Canonical source** | Edit, commit, and push **here**. |
| `…\eda\designs\chipathon\butterfold` | **Docker run mirror** (mounts to `/foss/designs/...` in the IIC-OSIC-TOOLS container) | **Only `git pull` and run tools.** Never hand-edit. |

Flow is one-directional: **edit in Desktop → commit/push → `git pull` in eda →
run the toolchain (iverilog / yosys / LibreLane) in the container.**

## Directory map (canonical repo)

```
butterfold/
├── butterfold_module_io.md       # THE spec: 6-module + top port/function contract (source of truth)
├── agents/
│   ├── module_spec.py            # parse the spec → structured contracts + port skeletons
│   ├── planner.py                # ordered module build plan  → generated/plan.json
│   ├── agent_core.py             # Journal memory + ModuleHarness + ReAct loop
│   ├── code_agent.py             # ReAct-authors each module from its contract
│   ├── verify_agent.py           # per-module compile/elaborate/testbench + top integration
│   ├── synth_agent.py            # Yosys full synthesis → GF180 area
│   ├── librelane_agent.py        # RTL→GDS signoff (gated by BUTTERFOLD_GDS=1)
│   ├── harness_agent.py          # emits tests/modules/tb_*.v from the spec
│   └── orchestrator.py           # one-button pipeline
├── tests/modules/                # committed per-module testbenches
├── librelane/                    # GF180 PnR config (config.yaml tracked; runs/ ignored)
├── generated/                    # agent outputs — RTL, plan, reports (gitignored, regenerated)
├── README.md
└── REPO_LAYOUT.md                # this file
```

## Spec → silicon flow

```
butterfold_module_io.md
   → module_spec.parse           structured contracts (single source of truth)
   → planner                     generated/plan.json (build order)
   → code_agent                  ReAct authors generated/rtl/<module>.v (compile→elaborate→tb)
   → verify_agent                per-module checks + butterfold_top integration
      (repair: re-author failing modules, bounded)
   → synth_agent                 GF180 area
   → librelane_agent             signed-off GDS   (BUTTERFOLD_GDS=1)
   → generated/summary.md
```

There is **no flat generator, no locked kernel, no golden-byte copy**.
Correctness per module is structural: exact ports, clean iverilog compile, clean
yosys elaboration, and a passing (or absent) testbench.

## How to run (container)

```bash
cd /foss/designs/chipathon/butterfold
git pull
python agents/orchestrator.py                  # spec → verified, synthesized RTL
BUTTERFOLD_GDS=1 python agents/orchestrator.py  # …all the way to GDS (long)
```

Without `OPENAI_API_KEY` the agents write compile-clean port skeletons, so the
pipeline still runs end-to-end; the key makes the module bodies real.
