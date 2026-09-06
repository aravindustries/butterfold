# Final power-ring quantitative IR

```
FINAL_RING_IR_ANALYZED = YES

FINAL_RING_IR_TOPOLOGY_SHA =
    cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f

POST_RING_IR_VDD = 0.206 V
POST_RING_IR_VSS = 0.0889 V

PSM_VDD = PASS
PSM_VSS = PASS
```

ODB/DEF `physical/results/m2_fix/power_ring.{odb,def}` (2026-09-06 10:16) is the
accepted post-bar-removal topology. A temp KLayout DEF→GDS re-stream of that
DEF is **geometry-identical** to SHA `cb449023…` (XOR zero on 28 layers; only
GDS library/structure timestamps differ). Core-width Metal5 bars were **not**
restored. The GDS was **not** regenerated.

## Method

Same as `physical/scripts/final_ach_ir_power.tcl` / pre-ring 0.125 / 0.0889 V:

- OpenROAD `26Q2-254-g61932e897`
- corner `max_ss_125C_4v50`, VDD = 4.5 V, VSS = 0
- sources `physical/results/m2_fix/irdrop/VDD.vsrc` (6 north, y=1674.500) and
  `VSS.vsrc` (6 west, x=0.500)
- `analyze_power_grid` + `check_power_grid`
- Fresh OpenRCX SPEF from `power_ring.odb` written to
  `physical/results/m2_fix/irdrop_final_ring/spef/power_ring.max.spef`
  (53340 RC segments), then **re-read** in a second session without
  in-session extract so PDNSim sees the ODB grid the same way as the
  pre-ring run.

Scripts: `physical/scripts/final_ring_ir_power.tcl` (extract + IR) and
`physical/scripts/final_ring_ir_established.tcl` (established read_spef path).
Both sessions report the same worst-case numbers.

Logs: [established_ir_power.log](evidence/ir/established_ir_power.log),
[extract_session_ir_power.log](evidence/ir/extract_session_ir_power.log),
[irdrop_summary.rpt](evidence/ir/irdrop_summary.rpt).

## Comparison

| | VDD worst drop | VSS worst rise | Power |
|---|---:|---:|---:|
| Pre-ring (via-fix, SHA `12876f00…`) | **0.125 V** (2.78 %) | **0.0889 V** (1.98 %) | 0.120 W |
| Final ring (SHA `cb449023…`) | **0.206 V** (4.57 %) | **0.0889 V** (1.97 %) | 0.120 W |

VSS is unchanged. VDD is **0.081 V** worse in PDNSim.

## Investigation (VDD)

PDNSim voltages are instance terminals (42060 rows, all inside CORE
`y ≤ 1088.64`). The worst VDD cell is the same pre and post:
`_19562_` Metal1 at (1036.670, 34.463).

Per-instance VDD extra drop vs the pre-ring CSV is spatially uniform:
**mean +80.6 mV** (min +69.2 mV at north-core tap cells, max +90.2 mV).
That is a **series offset** between the north pad sources and the whole
core grid, not a new south-east grid bottleneck.

OpenDB dump of VDD special nets:

- `power_fixed.odb` and `power_ring.odb` have the **same** Metal4 feed
  rectangles: three 1.6 µm envelope feeds `y=1088.64–1675.00` at
  `x=483.04/636.64/790.24`, each overlapping the core strap by **0.30 µm**.
- The ring adds four 8.0 µm Metal5 envelope rectangles and six Via4 3×3
  arrays on those existing feeds (south bar `y≈1100`, north bar `y≈1669`).
- Pad Via2/Via3 stacks at `y=1674–1675` are unchanged.

Physically the pad-to-core Metal4 path is still the same continuous
rectangles. PDNSim’s extra ~81 mV is the via-on-strap series resistance it
inserts where the new Via4 arrays sit on those feeds. VSS is unaffected
because the VSS ring hangs off **new** north-only Metal4 extensions, not
the constrained west VSS entry.

This is **not** treated as a broken physical ring. The ring was left
unchanged (no restore of core-width Metal5 bars, no reroute).

4.57 % of 4.5 V remains a characterized digital IR result, not a
connectivity fail. `PSM-0040` both rails.
