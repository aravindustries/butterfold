# Power-ring connectivity

Final candidate GDS SHA:

`cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f`

ODB: `physical/results/m2_fix/power_ring.odb`  
Script: `physical/scripts/add_power_ring.py`  
Streamout: KLayout DEF→GDS (`physical/scripts/stream_power_ring_gds.py`), same method as the signed-off ACH GDS.

## Architecture

The internal PDN already has Metal1 rails, Metal4 vertical 1.6 µm straps, and
Metal5 horizontal 1.6 µm straps. This ECO adds a closed Metal5 VDD/VSS ring in
the empty ACH envelope (`y > 1088.64`) that meets the north VDD pad feeds and
the west VSS pad interface.

Core-width Metal5 bars were **not** used. A trial overlay of 8 µm M5 across the
core (including `y≈22–50` tiel abutment and `y≈1068–1086` SRAM Q routing)
caused Mag extract to merge four ACH tie ports into VDD/VSS and to merge SRAM
`Q[1]` with unrelated logic. Those bars were removed. The envelope ring plus
the existing core M4/M5 grid is the production topology.

VSS uses one physically constrained entry (the accepted ACH fix). The rejected
west-core second VSS branch is **not** recreated.

## Layers and width

| | VDD | VSS |
|---|---|---|
| Ring layer | Metal5 | Metal5 |
| Ring width | 8.0 µm | 8.0 µm |
| Min neck | 8.0 µm | 8.0 µm |
| Closed | YES | YES |

Via master for every new M4/M5 transition:

`via4_5_3200_3200_3_3_1040_1040` (technology-generated 3×3, 9 cuts, 1.6 µm M4 enclosure).

`RAW_HAND_DRAWN_CRITICAL_VIA_CUTS = 0`

## Pad → ring → PDN

OpenDB connectivity (`audit_power_ring.py`):

| Gate | Result |
|---|---|
| ACH_VDD_TO_RING | PASS |
| ACH_VSS_TO_RING | PASS |
| VDD_RING_TO_INTERNAL_PDN | PASS |
| VSS_RING_TO_INTERNAL_PDN | PASS |
| VDD_RING_TO_PDN_ENTRY_COUNT | 69 Via4 arrays (621 cuts) |
| VSS_RING_TO_PDN_ENTRY_COUNT | 70 Via4 arrays (630 cuts) |
| SINGLE_VIA_RING_BOTTLENECKS | 0 |

ACH VDD: six north Metal2 ports `y=1674–1675` already stacked through
tech-generated Via2 1×3 (3 cuts) and Via3 2×3 (6 cuts) onto three Metal4 feeds
at `x=483.84 / 637.44 / 791.04`. The envelope VDD ring lands on those feeds
with Via4 3×3.

ACH VSS: six west Metal2 ports. The accepted single VSS entry
(`~8.80, 40.11`) keeps Via3 2×3 (6 cuts) and Via4 3×3 (9 cuts). Three existing
VSS Metal4 verticals are extended **north only** into the envelope (not a
second west-core branch).

## Prior reviewer fixes preserved

| Fix | Status |
|---|---|
| VDD 3 independent entries, 3-cut M2/M3, 6-cut M3/M4 | PASS (GDS cut audit) |
| VSS 1 entry, 6-cut M3/M4, 9-cut M4/M5 | PASS |
| din_ready_o M2 spacing ~0.350 vs 0.280 | PASS (0 violations / 145 ports) |
| M2 SW keep-out (0,0)–(2,65) | PASS |
| 135/135 YAML, 102/102 IO controls | unchanged logical netlist |

## PSM

`check_power_grid -net VDD` / `VSS`: all shapes connected (PSM-0040).
