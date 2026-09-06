# Density / dummy-metal fill ownership

```
DENSITY_FILL_OWNERSHIP = UNRESOLVED
PARTICIPANT_DENSITY_BLOCKER = UNRESOLVED
```

Final-envelope official density on SHA `cb449023…` is below GF180 nominal
minima (COMP 23.72 %, M1 21.77 %, M2 13.91 %, M3 16.85 %, M4 4.46 %,
M5/MT 5.55 %). That is reported honestly. **No fill was added.**

This note exists because prior text (“integrator fill pending”) is **not**
accepted as ownership. Ownership was re-derived from Chipathon/organizer
collateral already in this repository, plus the Chipathon 2026 Integration
README that that collateral points at.

## What was searched

| Source | What it is | Dummy-metal / CMP fill statement |
|---|---|---|
| `D03.def/D03/project_defs/ACH/D03_ACH.def` | Organizer participant-slot DEF (135 pins, 1110×1675 µm) | None. One Metal2 keep-out blockage only. |
| `D03.def/D03/project_defs/ACH/D03_ACH_interface.yaml` | Organizer slot interface | `origin_microns: [350, 910]`, `size_microns: [1110, 1675]`, `routing_blockage_layers: [Metal1..Metal5]`. No fill/dummy/density keys. |
| `D03.def/D03/project_defs/ACH/D03_ACH_padring.cfg` | Organizer padring (Juan Moya / Mitch Bailey) | `AREA 2935 2935`. `FILLER gf180mcu_fd_io__fill5` is **I/O pad-ring filler**, not dummy metal. |
| `D03.def/D03/project_defs/ACH/D03_ACH_padring.def` | Padring DEF | `gf180mcu_fd_io__fill5` instances only. |
| `D03.def/D03/project_defs/D03_selected_variants.json` | Organizer consumes `source_gds` `…/gds/D03/butterfold_top.gds` | Slot bbox/labels only. No fill keys. |
| Repo-root `info.yaml` | Chipathon 2026 project config | Pins + `lvs_config` only. No density/fill policy. |
| Repo-root `lvs_config.json` | Chipathon LVS hook | Layout/netlist only. |
| Chipathon 2026 Integration README | https://github.com/sscs-ose/sscs-chipathon-2026/blob/main/resources/Integration/README.md | Padring, ESD, I/O pad **fill1/fill5/fill10/fillnc**. No dummy-metal / CMP fill. |
| Chipathon 2026 guidelines | `docs/guidelines.md` | No DRC density or fill requirement. |
| Chipathon 2026 schedule | `schedule/README.md` | “DRC-clean GDS to Channel Partner” on the integration-track final date. Does not say whether density/fill is participant or chiptop. |
| Week 30 “Multi project integration” slides | Chipathon schedule, Kevin Guan / Camilo Velez | Chip-level padring, PDN, tie cells, ESD. No dummy-metal fill. |
| GitHub code search `repo:sscs-ose/sscs-chipathon-2026 density OR dummy OR fill` | Official 2026 repo | No dummy-metal / density-fill hits (I/O fillers live only in the Integration README above). |
| Team reports (`README.md`, `physical/reports/**/00_manifest.md`, `final_ach/density.md`) | ButterFold write-ups | Phrase “integrator fill pending” — **not used as authority**. |

GF180 `density.drc` counts drawn metal **plus dummy datatypes** (e.g. Metal2
datatype 4) and sets `CHIP = extent.sized(0.0)` of **whatever GDS is being
checked**. That is a foundry rule-deck fact. It does not assign who inserts
those dummy layers for Chipathon 2026.

## Why this is not option A or B

Organizer collateral **does** show that participant `butterfold_top.gds` is a
**slot** (1110×1675 µm at origin 350/910) inside a **2935×2935 µm padring
chip**, with Metal1–Metal5 routing blockages over the slot. That is the ACH
integration model. It is **not** an explicit sentence that dummy/CMP fill of
the participant slot or of the assembled chiptop is owned by the
organizer/integrator after GDS submission.

It is also **not** an explicit requirement that dummy metal must be inside
the participant ButterFold GDS. `info.yaml` / `lvs_config.json` /
`D03_ACH_interface.yaml` do not list a participant density-fill deliverable.

Without that assignment, fill ownership is **UNRESOLVED**. Participant-side
density is **not** independently satisfied. No fill was inserted to greening
the numbers.
