# Physical reports

On branch `pin-redesign-22` the project-canonical GDS is
repo-root `gds/butterfold_top.gds` SHA
`31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e`
(1092.66 × 1108.80 µm; **22 pins including VDD and VSS**; no ACH DEF).

- [`pin22_signoff/`](pin22_signoff/README.md) — **current 22-pin compact
  production signoff**.
- [`d03_ach_resized/`](d03_ach_resized/README.md) — historical ACH validation
  integration (1110 × 1675 µm). Not this chip.
- [`signoff/`](signoff/README.md) — historical pre-ACH shrink baseline.
- `38p4_mhz_setup_closure.md` — historical 38.4 MHz interval-10 max-SS notes.
- `shrink_area_feasibility.md` — historical area-compliance note vs 1110 × 1110
  Block A.

Native 22-pin copies live in
[`pin22_signoff/evidence/`](pin22_signoff/evidence/). Heavy ODB/SPEF remain
under `physical/results/` (not recommended for git).
