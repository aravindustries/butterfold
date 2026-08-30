# ACH validation template application (cheap gate)

Classification: ACH_VALIDATION_ONLY (final D03_A.def not available)

- Organizer DEF: `D03.def/D03/project_defs/ACH/D03_ACH.def`
- Organizer SHA-256: `13a068191b9d827cc31cb0fc2fa36f25ecadb91d84730637ed9055323bc8e7c9`
- Template: `butterfold_proto/physical/librelane/d03_ach_user_template.def`
- Template SHA-256: `cd0254ecbc6e69872968dd3a6368b7901c33a56214807351872500b36181b947`
- BTERMs: 23 (21 functional + VDD + VSS)
- Functional geometry match: 21/21
- VDD/VSS geometry match: YES
- Validation outer DIE: 1110 x 1675 µm
- Internal CORE: 6.72 20.16 1085.84 1088.64 µm (width 1079.12, height 1068.48, within 1110x1110)
- Placement rows: 212 unique Y, 20.16–1083.60 µm; **zero rows above 1088.64**
- SRAM: 2 x sram256x8m8wm1 R0 at (51.120, 720.560) and (531.120, 720.560)
- ApplyDEFTemplate LibreLane 10x DIE warning is a DEF-UNITS=200 vs tech-2000 metric artifact; pin microns match organizer.
- PG stitch: template M2 ports connected to compact-core PDN. OpenROAD PSM: VDD all shapes connected, VSS all shapes connected.

Evidence: [template_pins.rpt](evidence/template/template_pins.rpt)
