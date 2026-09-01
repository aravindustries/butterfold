# m2-fix template application (cheap gate)

Classification: ACH_VALIDATION_ONLY (final D03_A.def not available)

- Organizer DEF: `D03.def/D03/project_defs/ACH/D03_ACH.def`
- Organizer SHA-256: `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99`
- Template: `butterfold_proto/physical/librelane/d03_ach_user_template.def`
- Template SHA-256: `112db498d3fb2fa277771376687d212ef9c1a58b10bdb253b615ec17223d0909`
- Generator: `physical/librelane/gen_d03_ach_user_template.py` now preserves `BLOCKAGES`
- BTERMs: 23 (21 functional + VDD + VSS)
- Functional geometry match: 21/21
- VDD/VSS geometry match: YES
- Metal2 obstruction count: **1**
- TEMPLATE_M2_BLOCKAGE_MATCH: **1/1**
  `Metal2 RECT (0 0) (400 13000)` at UNITS 200 = (0, 0)–(2.0, 65.0) µm
- OPENDB_M2_BLOCKAGE_MATCH: **1/1**
  OpenDB 2000 dbu/µm: `OBS Metal2 0 0 4000 130000`
- `PDN_OBSTRUCTIONS` / `ROUTING_OBSTRUCTIONS`: `["Metal2", 0.0, 0.0, 2.0, 65.0]`
- Validation outer DIE: 1110 × 1675 µm
- Internal CORE: 6.72 20.16 1085.84 1088.64 µm
- SRAM: 2 × sram256x8m8wm1 R0 at (51.120, 720.560) and (531.120, 720.560)
- `stream_status_o`: **NO**
- ApplyDEFTemplate LibreLane 10× DIE warning is a DEF-UNITS=200 vs tech-2000
  metric artifact; pin microns match organizer.
- `MAGIC_DEF_NO_BLOCKAGES=1` so the keep-out is a routing constraint, not
  streamed as Metal2 geometry in the GDS.
- PG stitch: template M2 ports connected to compact-core PDN.

Evidence: [template_pins.rpt](evidence/template/template_pins.rpt),
[opendb_m2_blockage.rpt](evidence/template/opendb_m2_blockage.rpt)
