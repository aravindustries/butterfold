# 1. DRC AND LVS CORRECTNESS

The reviewed layout is `physical/results/padframe/gds/butterfold_padframe_candidate.gds`, top `butterfold_padframe_top`, SHA-256 `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`.

| Check | Result | Evidence |
| --- | --- | --- |
| OpenROAD detailed-routing DRC | **PASS — 0** | `physical/results/padframe/route/pad_boundary_repair.log` reports `[INFO DRT-0199] Number of violations = 0`; the clean `detailed_route_drc.rpt` is empty by tool convention. |
| Full GF180 GDS DRC | **FAIL — 37,494 markers in 54 nonzero rule categories** | KLayout 0.30.8, installed GF180 Open_PDKs runner `/foss/pdks/gf180mcuD/libs.tech/klayout/tech/drc/run_drc.py`, variant C (5LM, 9K top metal, MIM option B), main FEOL/BEOL/connectivity deck. Results: `physical/results/padframe/drc_gf180_serial/butterfold_padframe_candidate_main.lyrdb` and `violations.json`. |
| Hierarchical GDS LVS | **PASS** | `reports/current/HIERARCHICAL_LVS_MILESTONE_REPORT.md` and `physical/results/padframe/lvs/milestone/lvs_summary.txt`. |

The GDS DRC failure is not waived. The largest categories are `DF.13_MV` (14,410), `DF.14_MV` (11,355), `NW.2b_LV` (961), `PP.5b` (806), `DF.3b` (735), `PP.5dii` (642), and `NP.2` (573). Other categories include contact, well, implant, dual-gate, CUP, and Metal1 spacing rules. The report database attributes 37,006 markers to the flattened/top context and 488 to named foundry leaf/bond-pad transforms. This establishes a real failing main-deck result; it does not yet establish which top-context markers are integration errors versus hierarchy/deck-context effects. No waivers or geometry changes were made. The runner's optional density mode was not enabled because the mandatory main deck already failed; density compliance is therefore also not established.

The preserved hierarchical LVS result is bound to the same GDS hash. It reports:

- top signal terminals: **21 / 21 match**;
- standard-cell leaf connectivity: **PASS**;
- I/O-pad leaf connectivity: **PASS**;
- SRAM256x8 macros: **2 / 2 match**;
- SRAM512x8 macros: **0**;
- unexplained net mismatches: **0**;
- unexplained instance mismatches: **0**;
- negative control: **FAIL AS EXPECTED**.

The LVS scope treats foundry standard cells, pads, and SRAMs as verified leaves; it is not transistor-level library LVS. Its supply-name normalization is a modeled comparison and must not be mistaken for proof of conductive pad-to-core power routing.

**RUBRIC READINESS: 2-READY**

LVS and routing DRC evidence are strong, but full GF180 GDS DRC currently fails.

# 2. POWER, GROUND, AND CURRENT PATHS

The established OpenROAD PDN uses 0.48-um Metal1 followpins, 3.0-um Metal4/Metal5 straps at 80-um pitch, Metal1-to-Metal4 connections, Metal4-to-Metal5 connections, and an SRAM macro grid connecting Metal3 to Metal4 (`physical/padframe_flow.tcl`). OpenROAD inserted 1,494 `filltie` cells and 592 endcaps.

The physical connectivity evidence is not signoff-clean:

- `check_power_grid` fails with `PSM-0025` for `VDD`, `VSS`, `u_core/one_`, and `u_core/zero_` because none has a physical terminal/BTerm from which PDNSim can seed connectivity.
- The DEF keeps pad-domain `VDD`/`VSS` separate from core-PDN `u_core/one_`/`u_core/zero_`. The pad nets have logical pad-pin membership but no routed shapes joining them to the core PDN.
- `physical/results/padframe/route/pdn_failed_vias.rpt` contains **3** failed SRAM macro-grid vias: two overlapping failures on the high-byte SRAM power grid and one build failure on its ground grid.
- Both SRAM macros are logically assigned to the core supply nets, but their end-to-end conductive supply paths are **NOT ESTABLISHED** while the failed vias and missing PDN seed remain.
- One `dvdd` and one `dvss` foundry pad are instantiated, but pad-to-core supply continuity is **FAIL / NOT ESTABLISHED**.

| Metric | Result |
| --- | --- |
| Power connectivity | **FAIL / NOT ESTABLISHED** |
| VDD | **FAIL — pad/core nets are separate; no physical BTerm** |
| VSS | **FAIL — pad/core nets are separate; no physical BTerm** |
| SRAM power | **2 / 2 logically assigned; physical closure NOT ESTABLISHED** |
| Pad supplies | **FAIL / NOT ESTABLISHED** |
| Failed PDN vias | **3** |
| Disconnected PDN nodes | **UNKNOWN** — standard checker cannot run without a seed terminal |
| Quantitative IR drop | **NOT ESTABLISHED** |

LibreLane's `OpenROAD.IRDropReport` and OpenROAD PDNSim are installed, but a defensible run requires a connected supply terminal, voltage-source locations, and a validated current/activity model. Those prerequisites are absent, so no IR-drop number is reported. Structural current-path evidence is limited to the generated rails/straps/vias and the failures above.

**RUBRIC READINESS: NOT READY**

# 3. ANALOG MATCHING, SYMMETRY, AND NOISE ISOLATION

ButterFold is a synthesized digital transform engine built from digital standard cells, two hardened SRAM macros, and foundry I/O cells. It contains no custom analog signal-processing layout requiring common-centroid matching, interdigitation, or analog-device symmetry.

**CUSTOM ANALOG MATCHING: NOT APPLICABLE**

Relevant digital noise evidence is limited to a dedicated CTS clock tree and the routed PDN topology. Supply-noise/IR-drop analysis is not established, so no stronger clock/supply-noise-isolation claim is made.

# 4. RELIABILITY AND PHYSICAL-DESIGN RISKS

| Area | Result | Evidence |
| --- | --- | --- |
| Tap/well | **CONCERN** | OpenROAD inserted 1,494 filltie cells and 592 endcaps at a configured 120-um tap distance, but the full GF180 DRC has nonzero `NW.*` and `LPW.*` markers. Foundry compliance is therefore not established. |
| Antenna | **FAIL — 24** | PDK-supported KLayout antenna deck, `physical/results/padframe/antenna_gf180/violations.json`; all 24 are `ANT.16_ii_ANT.3`. |
| Antenna diodes | **0** | No `gf180mcu_fd_sc_mcu9t5v0__antenna` instance exists; the physical flow explicitly excluded that cell. |
| ESD / I/O | **CONCERN** | Foundry `in_c`, `bi_t`, `dvdd`, `dvss`, and corner cells are used. All `ESD.*` rules in the executed deck report zero markers, but system discharge continuity is not established because pad-supply continuity and pad-ring filler continuity are incomplete. |
| Voltage domains | **CONCERN** | Signal inputs follow pad -> `in_c` -> local isolation/drive buffer -> core; clock and reset have dedicated root buffering. No direct unsafe signal-pad-to-core bypass was found (**0**). However, `VDD`/`DVDD` and `VSS`/`DVSS` were normalized in LVS while their physical connection to the core PDN is not established. |
| Quantitative EM/current density | **NOT ESTABLISHED** | The installed LibreLane/OpenROAD/GF180 environment exposes PDN/IR reporting but no supported quantitative EM signoff stage. No custom solver was created. |
| Output electrical | **OPEN** | At 5 pF the SS output-pad slew is 4.61 ns against the 1.0-ns Liberty limit (`physical/results/padframe/signoff/ss_125C_4v50_max/max_slew.rpt`). |

The 5-pF slew issue does not invalidate signal LVS or geometric DRC by itself. It does invalidate a claim that the external output electrical interface is closed, and it remains a max-transition failure in pad-aware STA.

**RUBRIC READINESS: NOT READY**

# 5. TOP-LEVEL INTEGRATION AND CONNECTIVITY

Signal-level integration is well evidenced:

- 21 / 21 top signal terminals are present and match;
- clock and reset boundaries are connected;
- all 11 inputs and all 10 outputs are connected;
- 11 `gf180mcu_fd_io__in_c` and 10 `gf180mcu_fd_io__bi_t` pads are present;
- both SRAM256x8 macros match and no SRAM512x8 is present;
- hierarchical signal/leaf LVS passes uniquely with zero unexplained mismatches.

Power integration is not equivalently established. The authoritative DEF has separate pad and core supply nets, no physical supply BTerm for OpenROAD power-grid traversal, three failed PDN vias, and no I/O filler cells closing the sparse pad ring. Thus the signal result must not be presented as full chip-level power connectivity closure.

**RUBRIC READINESS: 2-READY**

## Extracted timing evidence

The established `make -C physical padframe-signoff` target was rerun on the current `route.odb` using fresh OpenRCX extraction. Clock is 61.44 MHz (16.2760416667 ns). `report_wns`/`report_tns` show 0.00/0.00 because OpenSTA clamps positive WNS to zero; the path reports below give the actual positive worst slack.

| Corner | Overall setup | Overall hold | Internal setup | Internal hold | SRAM setup | SRAM hold |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| SS / 125 C / 4.50 V / RCmax | +0.45 ns PASS | +1.29 ns PASS | +0.34 ns | +1.25 ns | +2.21 ns | +1.57 ns |
| TT / 25 C / 5.00 V / RCnom | +7.64 ns PASS | +0.66 ns PASS | +7.57 ns | +0.65 ns | +8.95 ns | +0.77 ns |
| FF / -40 C / 5.50 V / RCmin | +10.78 ns PASS | +0.40 ns PASS | +10.75 ns | +0.39 ns | +11.49 ns | +0.42 ns |

**ALL ANALYZED PVT CORNERS PASS SETUP/HOLD** under the candidate I/O timing constraints in `physical/padframe_constraints.sdc`. Internal timing, SRAM timing, and candidate input timing pass separately. External output max-transition closure does not pass at the modeled 5-pF load.
