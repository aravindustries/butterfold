# Pad-spacing post-fix evidence

Final candidate GDS SHA: `12876f003ed41f9b6229ef95207e50af71b16ef45a63ffb8516eb1be5dd71d2d`

BEFORE: `din_ready_o` Metal2 spacing to `din_ready_o_OE` was `0.000 um`, less
than the GF180 M2.2a requirement of `0.280 um`.

AFTER: the long Metal2 access strip is absent. The terminal escape transitions
immediately to Metal3; its local replacement bbox is
`(0.840, 1275.260)–(3.640, 1275.540) um` on Metal3. The nearest Metal2 of the
`din_ready_o` route is above/beyond the control region. Exact-GDS separation
from `din_ready_o_OE` is `0.350 um`, giving `0.070 um` margin to M2.2a.

```
KNOWN_LONG_STRIP_NET: din_ready_o
KNOWN_LONG_STRIP_LAYER: Metal2
KNOWN_LONG_STRIP_PRE_FIX_BBOX: (0.000,466.570)-(2.660,1275.600) um
NEARBY_PAD_PIN: din_ready_o_OE
NEARBY_PAD_LAYER: Metal2
NEARBY_PAD_BBOX: (0.000,1274.490)-(1.000,1274.870) um
APPLICABLE_PAD_SPACING_RULE: GF180 M2.2a
REQUIRED_PAD_SPACING_UM: 0.280
PRE_FIX_PAD_SPACING_UM: 0.000
PRE_FIX_VIOLATION_UM: 0.280
PAD_SPACING_FIX: organizer-derived Metal2 route exclusions plus immediate Metal3 terminal escape
POST_FIX_LONG_STRIP_BBOX: ABSENT; Metal3 replacement (0.840,1275.260)-(3.640,1275.540) um
POST_FIX_PAD_SPACING_UM: 0.350
POST_FIX_SPACING_MARGIN_UM: 0.070
KNOWN_LONG_STRIP_PAD_SPACING: PASS
PAD_PIN_SPACING_REGIONS_CHECKED: 145
PAD_PIN_SPACING_VIOLATIONS: 0
```

Machine-readable exact-GDS evidence:
`evidence/pad_spacing_final.json`. The audit checks 145 organizer
Metal2 PORT regions against top-level Metal2 polygons and routed paths; cell
internal shapes are excluded from the top-level routing population.
