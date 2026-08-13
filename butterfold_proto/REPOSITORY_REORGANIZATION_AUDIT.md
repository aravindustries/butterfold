# Repository reorganization pre-move audit

- Branch: `icarus-implementation`
- Timestamp (UTC): `2026-08-10T16:12:49Z`
- Repository root: `/headless/aravindustries-repos/butterfold/butterfold_proto`
- `git diff --stat`: empty
- In-scope `git status --short`: clean
- Parent-repository untracked items observed but out of scope: `../.env`, `../.venv/`

No production, golden, verification, or physical-flow file had an uncommitted
diff at the start of this task.

## Original top-level layout

The root mixed authoritative RTL, historical schedulers and SRAM wrappers,
testbenches, golden generators, vectors, reports, experiment directories,
physical/timing collateral, and compiled `sim_*.out` artifacts.  Important
directories were:

```
experimental/
physical/
physical/results/
physical_planning/padframe_a_study/
timing/
timing/results/
two_sram_experiment/
vectors/
```

Authoritative source and verification files were otherwise flat in the root.
The complete pre-move file inventory and command output were captured in the
task transcript; this document records the stable repository facts required
to interpret subsequent moves.
