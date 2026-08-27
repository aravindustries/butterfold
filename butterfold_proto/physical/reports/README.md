# Physical reports

- [`signoff/`](signoff/README.md) — **North/West team-side GF180 signoff**.
  Canonical GDS is repo-root `gds/butterfold_top.gds`
  (SHA `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12`).
  23 terminals: NORTH 12 / WEST 11 / EAST 0 / SOUTH 0.
  Minimum-clear density PASS. Minimum-metal fill is **integrator pending**.
- `38p4_mhz_setup_closure.md` — 38.4 MHz interval-10 max-SS setup closure
  (post-route extracted-aware ECO on the LibreLane production run).

Native tool output used for review lives in
[`signoff/evidence/`](signoff/evidence/). Heavy ODB/SPEF/GDS working copies
remain under `physical/results/` (gitignored).
