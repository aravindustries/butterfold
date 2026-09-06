# Tapeout artifact manifest

Branch `power_ring`. Physical implementation was **not** modified for this
checkpoint. GDS was **not** regenerated. Dummy fill was **not** added.

```
FINAL_GDS_SHA =
    cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f

FINAL_RING_IR_ANALYZED = YES
POST_RING_IR_VDD = 0.206 V
POST_RING_IR_VSS = 0.0889 V

DENSITY_FILL_OWNERSHIP = ORGANIZER/INTEGRATOR
PARTICIPANT_DENSITY_BLOCKER = NO
PARTICIPANT_DUMMY_FILL_REQUIRED = NO
FINAL_INTEGRATOR_FILL_PENDING = YES
```

Provenance:

- Chipathon submission `LAYOUT_FILE` is repo-root `gds/butterfold_top.gds`
  (`lvs_config.json`). That file is now a **byte copy** of the accepted GDS
  SHA `cb449023…`. `butterfold_proto/gds/butterfold_top.gds` and the
  candidate GDS are the same bytes. No GDS was regenerated.
- `power_ring.odb` is the accepted post-bar-removal OpenDB (envelope-only
  8.0 µm Metal5 VDD/VSS rings; no core-width M5 bars; no second VSS branch).
- Powered netlist `butterfold_top.final.pnl.v` is the ACH LVS source used by
  `final_ach_netgen_lvs.tcl`. The ring ECO added special-net geometry only
  (no new instances); this PNL was not rewritten after the ring.
- **Final-ring STA SPEFs:** `spef/power_ring.max.spef` (setup) and
  `spef/power_ring.min.spef` (hold), extracted from `power_ring.odb`.
- **Historical / pre-ring SPEFs (not used for final STA):**
  `spef/final_ach.max.spef` / `spef/final_ach.min.spef`.
- **Final-ring IR SPEF (not the STA pair):**
  `irdrop_final_ring/spef/power_ring.max.spef` (IR 0.206 V / 0.0889 V).

| path | purpose | size | SHA256 |
|---|---|---:|---|
| `gds/butterfold_top.gds` | Chipathon submission / repo-root canonical GDS | 19786438 | `cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f` |
| `butterfold_proto/gds/butterfold_top.gds` | Proto canonical GDS (byte-identical) | 19786438 | `cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f` |
| `butterfold_proto/physical/results/m2_fix/candidate_power_ring/butterfold_top.gds` | Candidate GDS (byte-identical) | 19786438 | `cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f` |
| `butterfold_proto/physical/results/m2_fix/power_ring.odb` | Accepted power-ring OpenDB | 29320020 | `8883b46559644aef38db675259f248addb548749ea0a8b5fead21fbe6cab5cc6` |
| `butterfold_proto/physical/results/m2_fix/power_ring.def` | Accepted power-ring DEF (streamout source) | 15454005 | `eb5815ebefc2b90eeae7e30b517116326aeea84fdd0f36ef8ca040acb495fca9` |
| `butterfold_proto/physical/results/m2_fix/butterfold_top.final.pnl.v` | Powered netlist used by unique LVS | 5860997 | `d959cd8c50f494e7401fa8684c8c7122f1cf60526b447d997b037d6372d72cff` |
| `butterfold_proto/physical/results/m2_fix/butterfold_top.final.v` | Gate-level netlist without pwr/gnd pins | 3664385 | `cd3c7742d2bd6b4ec4f023f70ff66818cfa746edc7eb1ec3c600ce01f4dac1e3` |
| `butterfold_proto/physical/results/m2_fix/spef/power_ring.max.spef` | **Final-ring** max OpenRCX SPEF (setup STA) | 17474201 | `10ea7f166178f139e81ee10965f70f350399cdb74127d6b02d2c4b027d82b983` |
| `butterfold_proto/physical/results/m2_fix/spef/power_ring.min.spef` | **Final-ring** min OpenRCX SPEF (hold STA) | 17418402 | `d31e53cb5ec6fadde825908e494cd829e168fb323d2cc9910acfef53fcfc2218` |
| `butterfold_proto/physical/results/m2_fix/spef/final_ach.max.spef` | Historical **pre-ring** max SPEF (not final STA) | 17474271 | `1ef509229a8e050053144b2ca2d85c79025b0e3b55f5816038a2ef3b86c1882d` |
| `butterfold_proto/physical/results/m2_fix/spef/final_ach.min.spef` | Historical **pre-ring** min SPEF (not final STA) | 17418474 | `0bb026364a405b243f80887fe64ced8dd131c07af4d7306b4fdc9c27bc64efdc` |
| `butterfold_proto/physical/results/m2_fix/irdrop_final_ring/spef/power_ring.max.spef` | Final-ring OpenRCX SPEF (quantitative IR only) | 17474201 | `10298ae73daa82e54adc74a97fb677c5a9dcb7d2f14e7d53c548bd1107bb1d73` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/sta/setup_power_ring.log` | Setup STA log (WNS 0.039952 ns) | 1564 | `b4bc2dd30393c84dbfc807a3088c12d1bbe5996954e9aaf5202b546377c9fba8` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/sta/hold_power_ring.log` | Hold STA log (WNS 0.181811 ns) | 1559 | `b25bb96bf83f84fde03dce112701f1a39d4e95bcb74e5dc57b4ea9bfd5f81600` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/sta/setup_power_ring.max.rpt` | Setup path report | 30636 | `217bc34748812adaf8cd1c5c4d73cbacb8f4e01dd5ca4fd4845ae1ad8336abf2` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/sta/hold_power_ring.min.rpt` | Hold path report | 14640 | `77bfbabfb2dfeb2e5be82c901f693ad9816f7822d22a63cea015f20d92bd7e2d` |
| `butterfold_proto/physical/results/m2_fix/irdrop/VDD.vsrc` | IR voltage sources, 6 north VDD pads | 150 | `c3598948af52fc7bfa6eb9bb33ccfd4d0415d5ad67249ab9835ab71534441588` |
| `butterfold_proto/physical/results/m2_fix/irdrop/VSS.vsrc` | IR voltage sources, 6 west VSS pads | 130 | `98c697193e93acfced232087847e627e68ef2a26e3f4ed98db1d56ae20b82920` |
| `butterfold_proto/physical/results/m2_fix/irdrop_final_ring/established-VDD.csv` | Final-ring instance VDD map (PDNSim) | 2190962 | `caf571435e7676935a940c86eb3a2d0325b573768c5023bb19ba766a040521b5` |
| `butterfold_proto/physical/results/m2_fix/irdrop_final_ring/established-VSS.csv` | Final-ring instance VSS map (PDNSim) | 2191073 | `743a03a71f04b0f5f92832e95cc3f44a99c3a53521dea937d03ce49708b75e95` |
| `D03.def/D03/project_defs/ACH/D03_ACH.def` | Organizer participant-slot DEF | 18635 | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` |
| `D03.def/D03/project_defs/ACH/D03_ACH_interface.yaml` | Organizer slot interface / pin map | 67756 | `89fa2b488644c8902c422f40a186ef2216db7e6b5b816005b46cb3320301fb60` |
| `butterfold_proto/physical/reports/m2_fix/evidence/organizer/D03_ACH.def` | Immutable signoff copy of organizer DEF | 18635 | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` |
| `butterfold_proto/physical/reports/m2_fix/evidence/organizer/package.sha256` | Organizer package / DEF SHA record | 238 | `59ad1551be8f5479d4baaa2c0651e77aa11c3cd9263952c23d6d082dd9a7cf09` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/lvs/lvs_summary.rpt` | Unique LVS summary | 134 | `ad2d25c10a6fe827c7bb9a63da71f5c86c8ab495c8960d3b092987b15aaec022` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/evidence/non_fill_drc_final.json` | Non-fill DRC summary | 430 | `2b7c70ea029ee73eb87bc7d0b77efc9814eeddad19dbc9bc2badd9594998c536` |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/power_ring_connectivity.md` | Ring/PDN connectivity report | — | (this commit) |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/final_ring_ir.md` | Final-ring IR report | — | (this commit) |
| `butterfold_proto/physical/reports/m2_fix/final_power_ring/final_signoff_summary.md` | Power-ring signoff dashboard | — | (this commit) |
