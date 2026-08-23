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

**TEAM-SIDE SIGNOFF COMPLETE.**

This is **not** final post-integration manufacturing signoff. Required
minimum-metal dummy fill is expected during Chipathon integration.

| | |
|---|---|
| Canonical team GDS | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| SHA-256 | `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |
| Minimum-clear density | **PASS** (DCF.1d COMP 36.18% ≤ 70%) |
| Minimum-metal density | **INTEGRATOR FILL PENDING** |

Dashboard: [`butterfold_proto/physical/reports/signoff/11_signoff_summary.md`](butterfold_proto/physical/reports/signoff/11_signoff_summary.md)

### Team-side signoff dashboard

| Check | Status | Result | Report | Native evidence |
|---|---|---|---|---|
| Functional regression | **PASS** | Foundry-SRAM Icarus, `TX_BYTE_INTERVAL=10`; FINAL-PIN OVERALL RESULT: PASS | [summary](butterfold_proto/physical/reports/signoff/evidence/functional/interval10_regression.rpt) | [log](butterfold_proto/physical/reports/signoff/evidence/functional/interval10_regression.log) |
| Max-SS setup | **PASS** | `max_ss_125C_4v50` WNS **+0.183361 ns**, TNS 0, 0 violations | [01](butterfold_proto/physical/reports/signoff/01_setup_max_ss.md) | [STA](butterfold_proto/physical/reports/signoff/evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | **PASS** | `min_ff_n40C_5v50` WNS **+0.152106 ns**, TNS 0, 0 violations | [02](butterfold_proto/physical/reports/signoff/02_hold_min_ff.md) | [STA](butterfold_proto/physical/reports/signoff/evidence/hold/min_ff_hold_summary.rpt) |
| Electrical | **PASS** | non-reset slew/cap/fanout violators = 0 | [03](butterfold_proto/physical/reports/signoff/03_electrical.md) | [slew](butterfold_proto/physical/reports/signoff/evidence/electrical/max_slew.rpt) / [cap](butterfold_proto/physical/reports/signoff/evidence/electrical/max_cap.rpt) / [fanout](butterfold_proto/physical/reports/signoff/evidence/electrical/fanout.rpt) |
| Reset electrical | **PASS** | slew 0, cap 0 (`rst_n` visible) | [04](butterfold_proto/physical/reports/signoff/04_reset.md) | [reset](butterfold_proto/physical/reports/signoff/evidence/reset/reset_electrical.rpt) |
| Antenna | **PASS** | 0 nets / 0 pins, **14** diodes | [05](butterfold_proto/physical/reports/signoff/05_antenna.md) | [OpenROAD](butterfold_proto/physical/reports/signoff/evidence/antenna/openroad_check_antennas.rpt) |
| Routing | **PASS** | GRT overflow 0, DRT violations 0 | [08](butterfold_proto/physical/reports/signoff/08_erc.md) | [GRT](butterfold_proto/physical/reports/signoff/evidence/routing/grt_summary.rpt) / [DRT](butterfold_proto/physical/reports/signoff/evidence/routing/drt_summary.rpt) |
| Minimum-clear density | **PASS** | DCF.1d COMP **36.18%** ≤ 70% | [06](butterfold_proto/physical/reports/signoff/06_drc.md) | [prefill](butterfold_proto/physical/reports/signoff/evidence/drc/density_prefill_summary.rpt) |
| Minimum-metal density | **INTEGRATOR FILL PENDING** | M2.4 / M3.4 / M4.4 / M5.4 / MT.3 still under 30% | [06](butterfold_proto/physical/reports/signoff/06_drc.md) | [prefill log](butterfold_proto/physical/reports/signoff/evidence/drc/density_prefill.rpt) |
| MSLOT | **PASS** | MSLOT.0–.9 = 0 items (unified official deck) | [06](butterfold_proto/physical/reports/signoff/06_drc.md) | [pass](butterfold_proto/physical/reports/signoff/evidence/drc/mslot_pass.rpt) |
| Full device-level LVS | **PASS** | Netgen: Circuits match uniquely; 11,629 devices / 11,638 nets | [07](butterfold_proto/physical/reports/signoff/07_lvs.md) | [summary](butterfold_proto/physical/reports/signoff/evidence/lvs/full_netgen_lvs_summary.rpt) |
| IR | **PASS** | VDD worst **1.01 mV**, VSS worst **1.13 mV** | [08](butterfold_proto/physical/reports/signoff/08_erc.md) | [IR](butterfold_proto/physical/reports/signoff/evidence/ir/power_grid.rpt) |
| Power | **INFO** | **~0.115 W vectorless estimate**, no VCD/SAIF | [09](butterfold_proto/physical/reports/signoff/09_power.md) | [power](butterfold_proto/physical/reports/signoff/evidence/power/vectorless_power.rpt) |
| Die area | **PASS** | **1.223277 mm²** ≤ 1.25 mm² | [00](butterfold_proto/physical/reports/signoff/00_manifest.md) | [area](butterfold_proto/physical/reports/signoff/evidence/area/final_area.rpt) |

Empty electrical/reset violator files are the native OpenSTA `-violators` dumps (zero violations).

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

| Item | Production value |
|---|---|
| Technology | GF180 MCU, OpenPDKs `gf180mcuD` |
| Standard cells | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | exactly **2 ×** `gf180mcu_fd_ip_sram__sram256x8m8wm1` (logical 256×16 via two 256×8 macros) |
| Clock | **38.4 MHz** / period **26.041667 ns** |
| TX pacing | `TX_BYTE_INTERVAL = 10` |
| External samples | signed 8-bit Q1.7, interleaved I then Q |
| Internal datapath | signed 16-bit, 7 fractional bits |
| CP (15 kHz numerology) | short normal CP = 4 samples, long normal CP = 5 samples at N=64 |
| Die | **1.223277 mm²** |
| Antenna diodes | 14 |
| Setup slack | +0.183361 ns (max-SS) |
| Hold slack | +0.152106 ns (min-FF) |
| Power | ~0.115 W **vectorless estimate** |

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
connectivity.

An earlier DEF/LEF Netgen run (`MAGIC_EXT_USE_GDS=0`) uniquely matched empty
standard-cell abstracts. That is **not** full LVS.

Final comparison:

1. Magic 8.3 reads the pre-fill team GDS (`MAGIC_EXT_USE_GDS=1`)
2. Standard cells extract to real `nfet_05v0` / `pfet_05v0`
3. Source is the ECO powered netlist plus official GF180 `CELL_SPICE_MODELS`
4. Official `gf180mcuD_setup.tcl`
5. The two SRAM macros use the **PDK-supported hard-macro blackbox** (LEFview /
   abstract). They were **not** transistor-flattened.

Result: **Circuits match uniquely** (11,629 devices, 11,638 nets).

Representative stdcell compares: `and2_1` 3 PFET + 3 NFET; `inv_1` 1+1;
`nand2_1` 2+2; `dffrnq_1` 14+14.

KLayout LVS against OpenROAD CDL **zero-device stubs** still fails and is
**not** the LVS of record.

Report: [`07_lvs.md`](butterfold_proto/physical/reports/signoff/07_lvs.md)  
Evidence: [`full_netgen_lvs_summary.rpt`](butterfold_proto/physical/reports/signoff/evidence/lvs/full_netgen_lvs_summary.rpt),
[`full_netgen_lvs.rpt`](butterfold_proto/physical/reports/signoff/evidence/lvs/full_netgen_lvs.rpt)

---

## Density and Integration Status

Team-side **maximum-density / minimum-clear** passes on the canonical pre-fill
GDS.

| Rule | Limit | Measured | Classification |
|---|---|---|---|
| DCF.1d COMP | ≤ 70% | 36.18% | **PASS** (minimum-clear) |
| DCF.1b COMP | ≥ 25% | 36.18% | PASS |
| PL.8 Poly2 | ≥ 14% | 27.54% | PASS |
| M1.4 Metal1 | > 30% | 33.29% | PASS |
| M2.4 Metal2 | > 30% | 19.03% | **INTEGRATOR FILL PENDING** |
| M3.4 Metal3 | > 30% | 24.25% | **INTEGRATOR FILL PENDING** |
| M4.4 Metal4 | > 30% | 3.40% | **INTEGRATOR FILL PENDING** |
| M5.4 Metal5 | > 30% | 3.90% | **INTEGRATOR FILL PENDING** |
| MT.3 MetalTop (5LM = Metal5) | > 30% | 3.90% | **INTEGRATOR FILL PENDING** |

M2.4–MT.3 are **not waived** foundry minima. Chipathon organizers stated that
minimum-clear must pass on the team GDS and that minimum-metal fill may be
added by integrators/organizers rather than each team.

The canonical repository GDS is intentionally the **pre-integration team GDS**.
Required minimum-metal dummy fill is expected during Chipathon integration.

MSLOT (official `mslot.drc` in the unified table that loads contact/vias):
**0 items** on Metal1–Metal5. A split-table `TABLE_NAME=mslot` crash is a PDK
invocation bug, not a PASS.

Report: [`06_drc.md`](butterfold_proto/physical/reports/signoff/06_drc.md)  
Evidence: [`density_prefill_summary.rpt`](butterfold_proto/physical/reports/signoff/evidence/drc/density_prefill_summary.rpt),
[`mslot_pass.rpt`](butterfold_proto/physical/reports/signoff/evidence/drc/mslot_pass.rpt)

---

## Canonical Team GDS

| | |
|---|---|
| Path | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| SHA-256 | `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |

This is the exact pre-fill ECO streamout that passed team-side signoff
(functional, setup/hold, electrical, reset, antenna, routing, min-clear,
MSLOT, geometric DRC tables, full device LVS, IR, area).

An experimental dummy-filled GDS (`e02fb870…`) was **not** promoted. Fill
polygons from that experiment are not the team submission.

Manifest: [`10_final_artifacts.md`](butterfold_proto/physical/reports/signoff/10_final_artifacts.md)

---

## Signoff Reports and Evidence

A clone of this repository is the reviewer package.

| Location | What it is |
|---|---|
| [`butterfold_proto/physical/reports/signoff/*.md`](butterfold_proto/physical/reports/signoff/README.md) | Human-readable per-check reports |
| [`butterfold_proto/physical/reports/signoff/evidence/`](butterfold_proto/physical/reports/signoff/evidence/) | Git-tracked native OpenSTA / OpenROAD / KLayout / Magic / Netgen / Icarus output |
| `butterfold_proto/physical/results/` | Large local implementation databases (typically gitignored) |
| [`gds/butterfold_top.gds`](gds/butterfold_top.gds) | Canonical tracked team layout |

Start here:

1. [Signoff README](butterfold_proto/physical/reports/signoff/README.md)
2. [Dashboard `11_signoff_summary.md`](butterfold_proto/physical/reports/signoff/11_signoff_summary.md)
3. [Functional log](butterfold_proto/physical/reports/signoff/evidence/functional/interval10_regression.log)
4. [Setup](butterfold_proto/physical/reports/signoff/01_setup_max_ss.md) · [Hold](butterfold_proto/physical/reports/signoff/02_hold_min_ff.md)
5. [DRC / density / MSLOT](butterfold_proto/physical/reports/signoff/06_drc.md)
6. [Full LVS](butterfold_proto/physical/reports/signoff/07_lvs.md)
7. [Final artifacts](butterfold_proto/physical/reports/signoff/10_final_artifacts.md)

---

## Functional verification

Committed interval-10 foundry-SRAM regression
([log](butterfold_proto/physical/reports/signoff/evidence/functional/interval10_regression.log))
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
| [`gds/butterfold_top.gds`](gds/butterfold_top.gds) | Canonical team GDS |
| [`info.yaml`](info.yaml) | Chipathon project metadata |
| `legacy/` | Obsolete implementations — not source of truth |
| `build/` | Ignored simulation artifacts |

Physical implementation used LibreLane 3.0.2, OpenROAD/OpenSTA
`26Q2-254-g61932e897`, Magic 8.3.636, KLayout 0.30.8, Netgen 1.5.318,
OpenPDKs `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`.

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
