# ButterFold

ButterFold is a **minimum-area, half-duplex GF180MCU** digital baseband
transform engine for a one-resource-block, 15 kHz-SCS lower-PHY proof of
concept. It is **not** a complete modem or RFIC.

Chipathon 2026 team: **D03_ButterFold**.

One folded mixed-radix arithmetic core is shared across TX and RX. The same
transform hardware performs DFT12, FFT64, and IFFT64. Area minimization is a
primary design objective.

Authoritative implementation: [`butterfold_proto/`](butterfold_proto/).
Do not infer intended behavior from `legacy/` or other sibling trees.

---

## Current Tapeout Status

**RESIZED ACH VALIDATION INTEGRATION COMPLETE**

On `def-integration-resized` the project-canonical GDS is
[`gds/butterfold_top.gds`](gds/butterfold_top.gds).

| | |
|---|---|
| Role | Canonical resized ACH validation GDS for this branch |
| SHA-256 | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Outer GDS | **1110 × 1675 µm** (intentional ACH envelope) |
| Compact CORE | `6.72 20.16 1085.84 1088.64` (1079.12 × 1068.48 µm, ≤1110 × 1110) |
| Classification | ACH_VALIDATION_ONLY |
| Pad controls | PENDING_FINAL_D03_A_DEF |
| Final D03_A integration | **PENDING** |

This is **not** the final D03_A manufacturing GDS.

All functional, timing, electrical, routing, antenna, non-fill DRC, MSLOT, PG,
and device-level LVS checks pass.

Official full-envelope density on the intentional 1110 × 1675 ACH validation
GDS reports DCF.1b = 23.56% and M1.4 = 21.71%, below their nominal standalone
team thresholds. DCF.1d = 23.56% ≤ 70% PASS.

Dashboard: [`butterfold_proto/physical/reports/d03_ach_resized/11_signoff_summary.md`](butterfold_proto/physical/reports/d03_ach_resized/11_signoff_summary.md)

### ACH validation dashboard (`def-integration-resized`)

| Check | Status | Result | Report | Native evidence |
|---|---|---|---|---|
| ACH DEF/template | **PASS** | 23 BTERMs, 21/21 functional, VDD/VSS geometry | [template](butterfold_proto/physical/reports/d03_ach_resized/00_template_apply.md) | [pins](butterfold_proto/physical/reports/d03_ach_resized/evidence/template/template_pins.rpt) |
| Functional regression | **PASS** | Foundry-SRAM Icarus, `TX_BYTE_INTERVAL=10`; FINAL-PIN OVERALL RESULT: PASS | [12](butterfold_proto/physical/reports/d03_ach_resized/12_functional.md) | [log](butterfold_proto/physical/reports/d03_ach_resized/evidence/functional/interval10_regression.log) |
| Max-SS setup | **PASS** | `max_ss_125C_4v50` worst MET **+3.88 ns**, WNS 0, 0 violations | [01](butterfold_proto/physical/reports/d03_ach_resized/01_setup_max_ss.md) | [STA](butterfold_proto/physical/reports/d03_ach_resized/evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | **PASS** | `min_ff_n40C_5v50` worst MET **+0.08 ns**, WNS 0, 0 violations | [02](butterfold_proto/physical/reports/d03_ach_resized/02_hold_min_ff.md) | [STA](butterfold_proto/physical/reports/d03_ach_resized/evidence/hold/min_ff_hold_summary.rpt) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](butterfold_proto/physical/reports/d03_ach_resized/03_electrical.md) | [log](butterfold_proto/physical/reports/d03_ach_resized/evidence/electrical/extract_elec.log) / [fanout](butterfold_proto/physical/reports/d03_ach_resized/evidence/electrical/fanout.rpt) |
| Reset electrical | **PASS** | slew 0, cap 0 | [04](butterfold_proto/physical/reports/d03_ach_resized/04_reset.md) | [violators](butterfold_proto/physical/reports/d03_ach_resized/evidence/reset/reset_visible_violators.rpt) |
| Antenna | **PASS** | 0 nets / 0 pins, **7** diodes | [05](butterfold_proto/physical/reports/d03_ach_resized/05_antenna.md) | [OpenROAD](butterfold_proto/physical/reports/d03_ach_resized/evidence/antenna/openroad_check_antennas.rpt) |
| Routing | **PASS** | GRT overflow 0, DRT 0, opens/shorts/unrouted 0 | [08](butterfold_proto/physical/reports/d03_ach_resized/08_routing_pg_ir.md) | [GRT](butterfold_proto/physical/reports/d03_ach_resized/evidence/routing/grt_summary.rpt) / [DRT](butterfold_proto/physical/reports/d03_ach_resized/evidence/routing/drt_summary.rpt) |
| PG | **PASS** | VDD/VSS connected | [08](butterfold_proto/physical/reports/d03_ach_resized/08_routing_pg_ir.md) | [PSM](butterfold_proto/physical/reports/d03_ach_resized/evidence/pg/psm_connectivity.rpt) |
| Non-fill DRC | **PASS** | 0 items, CO.6a = 0 | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [summary](butterfold_proto/physical/reports/d03_ach_resized/evidence/drc/non_fill_drc_summary.rpt) |
| DCF.1d | **PASS** | 23.56% ≤ 70% (full 1110×1675) | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [density](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt) |
| DCF.1b | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 23.56% < 25% | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [density](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt) |
| Poly2 PL.8 | **PASS** | 17.93% ≥ 14% | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [density](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt) |
| M1.4 | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** | 21.71% < 30% | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [density](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 13.08 / 16.41 / 2.49 / 2.53 / 2.53 % | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [density](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt) |
| MSLOT | **PASS** | 0 items (unified official deck) | [06](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md) | [lyrdb](butterfold_proto/physical/reports/d03_ach_resized/evidence/mslot/mslot_unified.lyrdb) |
| Full device-level LVS | **PASS** | Netgen: Circuits match uniquely; **11537** devices / **11552** nets; 2 SRAM | [07](butterfold_proto/physical/reports/d03_ach_resized/07_lvs.md) | [summary](butterfold_proto/physical/reports/d03_ach_resized/evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD worst **0.149 V**, VSS worst **0.088 V** | [08](butterfold_proto/physical/reports/d03_ach_resized/08_routing_pg_ir.md) | [IR](butterfold_proto/physical/reports/d03_ach_resized/evidence/ir/irdrop_summary.rpt) |
| Power | **INFO** | **0.134196 W** vectorless, no VCD/SAIF | [09](butterfold_proto/physical/reports/d03_ach_resized/09_power.md) | [power](butterfold_proto/physical/reports/d03_ach_resized/evidence/power/vectorless_power.rpt) |
| ACH outer GDS | **PASS** | exactly 1110 × 1675 µm | [00](butterfold_proto/physical/reports/d03_ach_resized/00_manifest.md) | [bbox](butterfold_proto/physical/reports/d03_ach_resized/evidence/gds/gds_sha_bbox.rpt) |
| Internal compact core | **PASS** | ≤1110 × 1110; 0 rows above 1088.64 | [00](butterfold_proto/physical/reports/d03_ach_resized/00_manifest.md) | [floorplan](butterfold_proto/physical/reports/d03_ach_resized/evidence/floorplan/core_rows_sram.rpt) |
| Final D03_A integration | **PENDING** | D03_A.def not available | [10](butterfold_proto/physical/reports/d03_ach_resized/10_final_artifacts.md) | — |

Empty electrical/reset violator files are the native OpenSTA `-violators` dumps (zero violations).

### Previous pre-ACH shrunk production baseline (from main)

On `main`, path `gds/butterfold_top.gds` is still the compact production
baseline. On **this** branch that same path has been promoted to the ACH
GDS above. The previous binary remains in Git history on `main`:

| | |
|---|---|
| SHA-256 | `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` |
| Die | **1092.66 × 1108.80 µm (1.211541 mm²)** ≤ 1110 × 1110 |
| Dashboard | [`butterfold_proto/physical/reports/signoff/11_signoff_summary.md`](butterfold_proto/physical/reports/signoff/11_signoff_summary.md) |

Those metrics (setup +5.04 ns, hold +0.26 ns, 15 diodes, DCF.1b 35.72%,
M1.4 33.21%, LVS 11612/11623, IR ~1 mV, 0.116 W) describe **that** GDS only.

---

## Architecture

ButterFold reuses one mixed-radix butterfly across TX and RX (half-duplex TDD;
slot scheduling is **external**).

| Path | What it does |
|---|---|
| TX | 12 FDIQ complex samples → DFT12 → map to natural IFFT bins 1..12 → IFFT64 → CP insert → TDIQ |
| RX | TDIQ → CP remove → FFT64 → extract natural FFT bins 1..12 → 12 FDIQ samples |
| Diagnostics | Standalone FFT2 / IFFT2 / FFT3 / DFT12 / FFT64 / IFFT64 / ECHO / MAGIC / SRAM R/W |

**FFT size is 64**, not 128. Older 128-point notes and filenames under
`legacy/` or historical vector names are superseded.

| Item | Value |
|---|---|
| Technology | GF180 MCU, OpenPDKs `gf180mcuD` |
| Standard cells | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | exactly **2 ×** `gf180mcu_fd_ip_sram__sram256x8m8wm1` (logical 256×16 via two 256×8 macros) |
| Clock | **38.4 MHz** / period **26.041667 ns** |
| TX pacing | `TX_BYTE_INTERVAL = 10` |
| External samples | signed 8-bit Q1.7, interleaved I then Q |
| Internal datapath | signed 16-bit, 7 fractional bits |
| CP (15 kHz numerology) | short normal CP = 4 samples, long normal CP = 5 samples at N=64 |
| ACH validation outer GDS (this branch) | **1110 × 1675 µm** |
| Compact CORE (this branch) | 6.72 20.16 1085.84 1088.64 |
| Historical shrink die (pre-ACH baseline) | 1092.66 × 1108.80 µm / 1.211541 mm² |
| ACH antenna diodes | 7 |
| ACH setup slack | +3.88 ns (max-SS worst MET) |
| ACH hold slack | +0.08 ns (min-FF worst MET) |
| ACH power | 0.134196 W **vectorless estimate** |

Command bytes on `din`: `0x40` FFT2, `0x41` FFT64, `0x42` IFFT64, `0x43` IFFT2,
`0x44` FFT3, `0x45` DFT12, `0x46`/`0x47` OFDM RX short/long, `0x48`/`0x49`
OFDM TX short/long, `0x4A` ECHO, `0x4B` MAGIC, `0x4C`/`0x4D` SRAM read/write.

### Frozen chip interface

The top-level **logical** pinout is frozen (22-pin target):

Inputs: `rst_n`, `clk`, `din[7:0]`, `din_valid_i`  
Outputs: `din_ready_o`, `dout[7:0]`, `dout_valid_o`  
Power: `VDD`

All commands and data use that byte stream. No extra mode/debug/SRAM pins.

See [`butterfold_proto/docs/architecture/final_frozen_pin_configuration.md`](butterfold_proto/docs/architecture/final_frozen_pin_configuration.md)
and [`butterfold_proto/AGENTS.md`](butterfold_proto/AGENTS.md).

### Arithmetic (shared core)

- Radix-2: \(X_0 = x_0 + W x_1\), \(X_1 = x_0 - W x_1\)
- Radix-3: algebraic 3-point DFT with one shared complex multiply
- DFT12: 3×4 Good-Thomas (4 radix-3 + 12 radix-2)
- FFT64/IFFT64: iterative radix-2 DIT, 6 stages; IFFT applies final `/64`
- Twiddles are constant ROM/logic, not SRAM

Do not silently change arithmetic scaling; Python golden models are the spec.

---

## Full device-level LVS

Team LVS of record is **Netgen device-level LVS**, not pin-only black-box
connectivity. LibreLane default `setup.tcl` is not the team method.

ACH validation GDS (`93f2aba1…`):

1. Magic 8.3 reads the ACH GDS (`MAGIC_EXT_USE_GDS=1`)
2. Standard cells extract to real `nfet_05v0` / `pfet_05v0`
3. Source is the filled ECO powered netlist plus official GF180 `CELL_SPICE_MODELS`
4. Official `gf180mcuD_setup.tcl`
5. The two SRAM macros use the **PDK-supported hard-macro blackbox**

Result: **Circuits match uniquely** (**11537** devices, **11552** nets).

Report: [`07_lvs.md`](butterfold_proto/physical/reports/d03_ach_resized/07_lvs.md)  
Evidence: [`lvs_summary.rpt`](butterfold_proto/physical/reports/d03_ach_resized/evidence/lvs/lvs_summary.rpt)

Historical shrink LVS (11612 devices / 11623 nets) is on SHA `f193cb1b…` only:
[`signoff/07_lvs.md`](butterfold_proto/physical/reports/signoff/07_lvs.md).

---

## Density and Integration Status

Official GF180 `density.drc` uses `CHIP = extent.sized(0.0)` and therefore
scores the **full 1110 × 1675 µm** ACH validation GDS bbox. A 1110 × 1110
clip was diagnostic only and is **not** signoff evidence.

| Rule | Limit | Official 1110×1675 | Classification |
|---|---|---|---|
| DCF.1d COMP | ≤ 70% | **23.56%** | **PASS** |
| DCF.1b COMP | ≥ 25% | **23.56%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| PL.8 Poly2 | ≥ 14% | **17.93%** | **PASS** |
| M1.4 Metal1 | > 30% | **21.71%** | **BELOW NOMINAL THRESHOLD ON ACH VALIDATION ENVELOPE** |
| M2.4 Metal2 | > 30% | **13.08%** | **INTEGRATOR FILL PENDING** |
| M3.4 Metal3 | > 30% | **16.41%** | **INTEGRATOR FILL PENDING** |
| M4.4 Metal4 | > 30% | **2.49%** | **INTEGRATOR FILL PENDING** |
| M5.4 Metal5 | > 30% | **2.53%** | **INTEGRATOR FILL PENDING** |
| MT.3 MetalTop | > 30% | **2.53%** | **INTEGRATOR FILL PENDING** |

M2.4–MT.3 remain integrator fill pending. DCF.1b and M1.4 are **not** marked
PASS on this ACH envelope.

MSLOT (unified `table_name=main`): **0 items**.

Report: [`06_drc.md`](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md)  
Evidence: [`official_full_envelope_summary.rpt`](butterfold_proto/physical/reports/d03_ach_resized/evidence/density/official_full_envelope_summary.rpt)

Historical shrink density (35.72% COMP, M1 33.21%) applies only to SHA
`f193cb1b…`.

---

## Canonical GDS (this branch)

On `def-integration-resized` there is **one** current GDS:

| | |
|---|---|
| Path | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| SHA-256 | `93f2aba11dab0df4e3c9431ff2e2c060fce066da17924ad1ed2657b19e4e5dd7` |
| Size | **1110 × 1675 µm** (intentional ACH envelope) |
| Role | Canonical resized ACH validation GDS |
| Classification | ACH_VALIDATION_ONLY — **not** final D03_A manufacturing GDS |

Pad controls are pending `D03_A.def`. The previous main/pre-ACH baseline
(`f193cb1b…`, 1092.66 × 1108.80 µm) is historical only.

Manifest: [`10_final_artifacts.md`](butterfold_proto/physical/reports/d03_ach_resized/10_final_artifacts.md)

---

## Signoff Reports and Evidence

A clone of this repository is the reviewer package.

| Location | What it is |
|---|---|
| [`butterfold_proto/physical/reports/d03_ach_resized/`](butterfold_proto/physical/reports/d03_ach_resized/README.md) | **Current** ACH validation reports |
| [`butterfold_proto/physical/reports/d03_ach_resized/evidence/`](butterfold_proto/physical/reports/d03_ach_resized/evidence/) | Native ACH OpenSTA / OpenROAD / KLayout / Netgen / Icarus copies |
| [`butterfold_proto/physical/reports/signoff/`](butterfold_proto/physical/reports/signoff/README.md) | **Historical** pre-ACH shrink baseline (SHA `f193cb1b…` on `main`) |
| `butterfold_proto/physical/results/` | Large local databases (not recommended for git) |
| [`gds/butterfold_top.gds`](gds/butterfold_top.gds) | Canonical resized ACH validation GDS on this branch |

Start here:

1. [ACH README](butterfold_proto/physical/reports/d03_ach_resized/README.md)
2. [ACH dashboard](butterfold_proto/physical/reports/d03_ach_resized/11_signoff_summary.md)
3. [Functional log](butterfold_proto/physical/reports/d03_ach_resized/evidence/functional/interval10_regression.log)
4. [Setup](butterfold_proto/physical/reports/d03_ach_resized/01_setup_max_ss.md) · [Hold](butterfold_proto/physical/reports/d03_ach_resized/02_hold_min_ff.md)
5. [DRC / density / MSLOT](butterfold_proto/physical/reports/d03_ach_resized/06_drc.md)
6. [Full LVS](butterfold_proto/physical/reports/d03_ach_resized/07_lvs.md)
7. [Final artifacts](butterfold_proto/physical/reports/d03_ach_resized/10_final_artifacts.md)

---

## Functional verification

ACH-validation interval-10 foundry-SRAM regression
([log](butterfold_proto/physical/reports/d03_ach_resized/evidence/functional/interval10_regression.log))
passed:

ECHO, MAGIC, SRAM R/W, FFT2, IFFT2, FFT3, DFT12 (`0x45`), FFT64 (`0x41`),
IFFT64 (`0x42`), OFDM RX short/long (`0x46`/`0x47`), OFDM TX short/long
(`0x48`/`0x49`).

RTL and golden models were not modified to obtain that result.

From `butterfold_proto/`:

```bash
make -f Makefile.gf180_sram vectors
make -f Makefile.gf180_sram behavioral
make -f Makefile.gf180_sram foundry-functional
make -f Makefile.gf180_sram reset-recovery
```

`foundry-functional` uses the official GF180 SRAM Verilog in FUNCTIONAL mode
(no Icarus `-gspecify`). The committed tapeout evidence used
`TX_BYTE_INTERVAL=10` (production). The default TB localparam is 1 unless
overlaid.

Python golden generators under `butterfold_proto/golden/` are the
specification. Do not change them to make RTL pass.

---

## Project map

| Path | Role |
|---|---|
| [`butterfold_proto/rtl/`](butterfold_proto/rtl/) | Production RTL (`butterfold_top` and shared core) |
| [`butterfold_proto/verification/tb/`](butterfold_proto/verification/tb/) | Production testbenches |
| [`butterfold_proto/golden/`](butterfold_proto/golden/) | Golden models and vectors (spec) |
| [`butterfold_proto/physical/`](butterfold_proto/physical/) | LibreLane/OpenROAD flow, SDC, signoff reports |
| [`gds/butterfold_top.gds`](gds/butterfold_top.gds) | Canonical resized ACH validation GDS on this branch (1110 × 1675 µm; not final D03_A) |
| [`info.yaml`](info.yaml) | Chipathon project metadata |
| `legacy/` | Obsolete implementations — not source of truth |
| `build/` | Ignored simulation artifacts |

ACH validation P&R/STA used LibreLane 3.0.2 and OpenROAD `26Q1-1024`
(ODB-schema compatible with LibreLane). Historical shrink reports used
OpenROAD/OpenSTA `26Q2-254-g61932e897`. Magic 8.3.636, KLayout 0.30.8,
Netgen 1.5.318, OpenPDKs `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`.

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
