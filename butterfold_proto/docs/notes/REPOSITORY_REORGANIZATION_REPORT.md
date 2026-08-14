# ButterFold repository reorganization and artifact-provenance report

> Point-in-time note: this report records the repository state during the
> reorganization task, when no GDS existed. A subsequent candidate stream-out
> is documented by `reports/current/CANDIDATE_GDS_STREAMOUT_REPORT.md` and
> `physical/results/CURRENT_RUN.md`.

Date: 2026-08-10  
Branch: `icarus-implementation`  
Repository: `/headless/aravindustries-repos/butterfold/butterfold_proto`

## 1. Original problem

The former flat root mixed production RTL, obsolete scheduler generations,
testbenches, golden generators, reports, experiments, and compiled simulation
binaries. Physical results also had several named result families without a
single authoritative pointer. A new engineer could not reliably distinguish
source from generated data or identify the routed padframe checkpoint.

The pre-move state is preserved in `REPOSITORY_REORGANIZATION_AUDIT.md`. It was
created before any move. The in-scope tree was clean; only parent-repository
`.env` and `.venv/` entries were untracked and were not touched.

## 2. Classification audit

| Classification | Content after reorganization |
|---|---|
| AUTHORITATIVE SOURCE | `rtl/`, `Makefile.gf180_sram`, `timing/`, active scripts in `physical/` |
| AUTHORITATIVE VERIFICATION | `verification/tb/` |
| AUTHORITATIVE GOLDEN/REFERENCE | root `gen_*.py`, `two_point_golden.py`, `vectors/` |
| CURRENT PHYSICAL FLOW | `physical/*.tcl`, `physical/Makefile`, `physical/README.md` |
| CURRENT GENERATED PHYSICAL RESULT | `physical/results/padframe/`; pointer in `physical/results/CURRENT_RUN.md` |
| CURRENT DESIGN REPORT | `reports/current/` |
| HISTORICAL REPORT | `reports/history/` |
| HISTORICAL EXPERIMENT | `experiments/` |
| LEGACY / COMPATIBILITY | `legacy/rtl/`, `legacy/tb/`, `legacy/Makefile.gf180_sram.fixed` |
| GENERATED BUILD ARTIFACT | ignored `build/sim/`, `timing/results/`, physical result databases |
| UNKNOWN — REQUIRES REVIEW | none among production dependencies; historical timing snapshots remain intentionally preserved |

Dependency inspection confirmed that the 128x8/128x32/512x8 wrappers and the
old scheduler variants are absent from the authoritative production source
lists. They were retained under `legacy/`, not deleted.

## 3. New directory structure

```text
.
├── AGENTS.md
├── README.md
├── Makefile.gf180_sram
├── rtl/
│   ├── top/
│   ├── padframe/
│   ├── transform/
│   ├── scheduler/
│   ├── io/
│   └── memory/
├── verification/tb/
├── vectors/
├── timing/
├── physical/
│   ├── Makefile
│   ├── README.md
│   ├── flow and signoff Tcl scripts
│   └── results/
│       ├── CURRENT_RUN.md
│       ├── padframe/
│       ├── A/ B/ C/
│       └── signoff/
├── reports/
│   ├── current/
│   └── history/
├── docs/architecture/
├── experiments/
│   ├── two_sram_architecture_study/
│   ├── precision_studies/
│   └── physical_planning/
├── legacy/
│   ├── rtl/
│   └── tb/
├── tools/
└── build/sim/                 (generated and ignored)
```

Golden generators and vectors intentionally remain at their established root
paths. Several generators derive output locations from their own path; moving
them would change behavior. This stable-path exception is safer than cosmetic
nesting and keeps their contents byte-identical.

## 4. Production RTL location

- Top: `rtl/top/butterfold_top.sv`
- Padframe: `rtl/padframe/butterfold_padframe_top.sv`
- Transform: `rtl/transform/fft128_modulo_controller.sv`,
  `fft128_twiddle_rom.sv`, `mixed_radix_butterfly.sv`
- Scheduler: `rtl/scheduler/transform_scheduler_core.sv`
- I/O: seven current SRAM/direct-stream adapters and mapper/serializer files
  under `rtl/io/`
- Memory: `rtl/memory/gf180_sram_256x8_wrapper.sv` and
  `gf180_sram_256x16_complex.sv`

The active source list elaborates two 256x8 SRAM macros and no 512x8 macro.

## 5. Verification location

`verification/tb/` contains the production final-pin, padframe smoke, reset
recovery, and SRAM-wrapper benches. Legacy scheduler/unit benches are isolated
under `legacy/tb/` and are not production specifications.

## 6. Golden/reference location

The immutable Python generators remain at the root and reference files remain
in `vectors/`. SHA-256 manifests were captured before moves and recomputed
after all regression runs. They compare exactly: Python, HEX vectors, and CSV
references are byte-identical.

## 7. Physical-design location

The reusable flow remains under `physical/` to avoid unnecessary churn in its
working relative paths. `physical/README.md` documents invocation.
`physical/results/README.md` labels result families, and
`physical/results/CURRENT_RUN.md` is the authoritative artifact pointer.
Core-only A/B/C and signoff studies are preserved but explicitly non-current.

## 8. Current authoritative run

| Artifact | Authoritative path |
|---|---|
| Routed ODB | `physical/results/padframe/route/route.odb` |
| Routed DEF | `physical/results/padframe/route/route.def` |
| Routed physical Verilog | `physical/results/padframe/route/butterfold_padframe_physical.v` |
| SS/RCmax SPEF | `physical/results/padframe/signoff/ss_125C_4v50_max/padframe.spef` |
| TT/RCnom SPEF | `physical/results/padframe/signoff/tt_025C_5v00_nom/padframe.spef` |
| FF/RCmin SPEF | `physical/results/padframe/signoff/ff_n40C_5v50_min/padframe.spef` |
| DRC | `physical/results/padframe/route/detailed_route_drc.rpt` (empty: zero violations) |
| STA | `physical/results/padframe/signoff/` |
| GDS | **NOT GENERATED** |

The ODB timestamp is `2026-08-10 11:59:39.170003249 +0200` and its size is
21,472,927 bytes. The DEF timestamp is
`2026-08-10 11:59:39.276700823 +0200` and its size is 14,312,228 bytes. The
top is `butterfold_padframe_top`. The routed physical netlist contains exactly
two `gf180mcu_fd_ip_sram__sram256x8m8wm1` instances and zero 512x8 instances.

## 9. Legacy and historical locations

- Superseded/rejected timing studies are in `reports/history/`.
- The validated but non-production two-SRAM development study is now
  `experiments/two_sram_architecture_study/`.
- The aborted precision study and Padframe-A planning harness are preserved in
  `experiments/`.
- Obsolete SRAM wrappers, schedulers, adapters, and their benches are preserved
  in `legacy/`.
- No historical experiment or report was deleted.

## 10. Build changes

`Makefile.gf180_sram`, `timing/synth.ys`, and
`physical/padframe_config.tcl` now reference the categorized RTL/testbench
paths. Simulation products are emitted to ignored `build/sim/`. All compile
targets create that directory on a clean checkout. The old fixed Makefile is
retained as legacy collateral, and the SRAM discovery helper is under `tools/`.

Tracked moves were performed content-preservingly. The sandbox prevented
locking the parent Git index for `git mv`, so the unstaged status currently
shows old tracked paths as deletions and their destinations as untracked.
When these changes are staged normally, Git's content-based rename detection
can represent the identical files as renames; no index workaround was used.

## 11. Verification after moves

| Check | Result |
|---|---|
| Behavioral SRAM, transforms, OFDM, debug, full sweep | PASS |
| Official GF180 SRAM model regression | PASS |
| GF180 SRAM wrapper regression | PASS |
| Padframe smoke: reset/ECHO/MAGIC/SRAM/FFT2/bit map | PASS |
| Reset recovery | PASS |
| Yosys synthesis and OpenSTA path resolution | PASS |
| Existing padframe SS/TT/FF signoff target parsing/extraction | PASS |
| Golden SHA-256 comparison | PASS, identical |

## 12. Repository integrity

Production file contents were moved, not functionally edited. The only source
list changes are path updates. `git diff --check` passes. The protected Python
and vector diff is empty. Generated simulation binaries are no longer mixed
with source and are ignored. Existing generated physical databases are
preserved in place.

## 13. Major file/directory moves

| Old path | New path |
|---|---|
| `butterfold_top.sv` | `rtl/top/butterfold_top.sv` |
| `butterfold_padframe_top.sv` | `rtl/padframe/butterfold_padframe_top.sv` |
| current transform files | `rtl/transform/` |
| `transform_scheduler_core.sv` | `rtl/scheduler/transform_scheduler_core.sv` |
| current adapters/mappers/serializer | `rtl/io/` |
| current 256x8 SRAM wrappers | `rtl/memory/` |
| production `*_tb.sv` benches | `verification/tb/` |
| obsolete schedulers/wrappers/benches | `legacy/rtl/`, `legacy/tb/` |
| current state-setting reports | `reports/current/` |
| superseded timing reports | `reports/history/` |
| `two_sram_experiment/` | `experiments/two_sram_architecture_study/` |
| `experimental/` | `experiments/precision_studies/` |
| `physical_planning/` | `experiments/physical_planning/` |
| root `sim_*.out` | `build/sim/` (ignored) |

## 14. GDS provenance conclusion

Searches for `*.gds`, `*.gdsii`, and `*.gds.gz` found zero files first inside
`butterfold_proto/` and then in the bounded ButterFold repository. Searches of
the active physical/timing scripts found no `write_gds`, `write_gdsii`, or
stream-out command. Therefore there is no GDS candidate to validate or select,
and no legacy GDS was substituted.

The evidence chain selecting the current routed database is:

1. `reports/current/PAD_CORE_BUFFER_CTS_REPAIR_REPORT.md` identifies the
   successful pad-aware run and distinguishes it from invalid earlier CTS work.
2. Active padframe flow/Makefile targets write route artifacts beneath
   `physical/results/padframe/route/`.
3. `route.odb`, `route.def`, routed Verilog, empty DRC report, and matching
   SS/TT/FF SPEFs coexist in that run family.
4. The routed netlist proves the padframe top, two 256x8 macros, and no 512x8.

Consequently:

```text
CURRENT AUTHORITATIVE GDS FOUND:
NO

Latest authoritative routed database:
physical/results/padframe/route/route.odb

Latest authoritative DEF:
physical/results/padframe/route/route.def

Latest authoritative SPEF:
physical/results/padframe/signoff/{ss_125C_4v50_max,tt_025C_5v00_nom,ff_n40C_5v50_min}/padframe.spef

Reason no current GDS exists:
The active flow reaches detailed route and extraction but contains no GDS
stream-out stage, and no GDS file exists in the bounded repository search.

GDS export command/path that should be used next:
Add a GF180-qualified KLayout (or equivalent) stream-out target using
physical/results/padframe/route/route.def (or route.odb), top
butterfold_padframe_top, and the standard-cell, 256x8 SRAM, and I/O GDS views
listed in physical/results/CURRENT_RUN.md. Write the result to
physical/results/padframe/route/butterfold_padframe.gds and validate hierarchy,
macro counts, pad cells, and die boundary before marking it authoritative.
```

No GDS was generated during this maintenance task.
