# Native PDN core-ring rehardening

Branch `native-power-ring` from pre-ECO checkpoint `68eccf1ddf7728d665e84cf0d6a15d4928a2167d`.
`main` was not checked out and was not modified.

LibreLane `PDN_CORE_RING` generated a closed Metal4/Metal5 ring around the digital
core before placement and routing. ACH Metal2 VDD/VSS ports were stitched to that
ring with OpenROAD-generated multi-cut vias (no hand-drawn cuts, no ECO envelope
ring, no rejected second VSS branch).

Final GDS SHA-256:

`d283d354d9d9e8c84636e47215482bd25e81c509b9253e7649a58c13676a92da`

Fresh OpenRCX + PDNSim (max_ss_125C_4v50, 4.5 V, official vsrc files):

| | Native | ECO fallback | Pre-ring |
|---|---|---|---|
| VDD worst drop | **0.0931 V (2.07%)** | 0.206 V (4.57%) | 0.125 V |
| VSS worst rise | **0.0667 V** | 0.0889 V | 0.0889 V |
| PSM VDD/VSS | PASS / PASS | PASS / PASS | PASS / PASS |

Native IR improves VDD versus the ECO ring.

Artifacts: `physical/results/native_power_ring/`, `gds/butterfold_top.gds`,
reviewer IR report `native_ring_ir_report.md`.
