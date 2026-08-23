# 24-pin physical signoff — paused

Full checkpoint (paths, hashes, resume commands):

`physical/results/24pin_eco/RESUME.md`

That directory is gitignored. If the workspace is wiped, the LibreLane run
`physical/librelane/runs/butterfold_top_24pin_38p4_9t/` (untracked, large)
and `physical/results/24pin_eco/` must still be on disk to continue without
re-running P&R.

**Do not promote** `gds/butterfold_top.gds` until Magic-GDS DRC + unique LVS pass.

Authoritative routed DB when resuming:

- `physical/results/24pin_eco/hold_eco/routed.odb`
- Magic GDS SHA `94f7fbd56b45cdb38c216834d6e6d8bf86293a589c3e51bcb27690b7a6fc1093`
