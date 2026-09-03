# Pad-spacing pre-fix evidence

Candidate GDS SHA: `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3`

The final-GDS Metal2 route connected to the intended organizer terminal
`din_ready_o_OUT` formed one long component which crossed unrelated organizer
controls. The component was attributed to `din_ready_o` by its intersection
with that intended terminal and by the corresponding routed DEF net.

| Field | Measured value |
|---|---|
| Offending net | `din_ready_o` |
| Layer | Metal2 (GDS 36/0) |
| Long-strip bbox | `(0.000, 466.570)–(2.660, 1275.600) um` |
| Width / length | `2.660 / 809.030 um` |
| Nearby unrelated pin | `din_ready_o_OE` |
| Pin layer / bbox | Metal2, `(0.000, 1274.490)–(1.000, 1274.870) um` |
| Measured spacing | `0.000 um` (overlap) |
| Rule | GF180 `M2.2a` |
| Required spacing | `0.280 um` |
| Violation | `0.280 um` |

The same strip also crossed `din_ready_o_IN`, `din_PU[0]`, and `din_PD[0]`.
The pre-fix general audit found 12 organizer-port regions with unrelated
top-level Metal2 at less than M2.2a spacing. Evidence sources are the original
GDS, `physical/reports/m2_fix/evidence/organizer/D03_ACH.def`, the matching DEF
route, and the PDK rules at `gf180mcuD.tech:2982` / `metal2.drc:30-40`.

Classification: the `_OE`, `_IN`, `_PU`, and `_PD` controls are separate nets
in the organizer DEF and are not ButterFold's intended `_OUT` connection.
