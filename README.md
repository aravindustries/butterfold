# ButterFold

ButterFold is a **minimum-area, half-duplex GF180MCU** digital baseband
transform engine for a one-resource-block, 15 kHz-SCS lower-PHY proof of
concept. It is **not** a complete modem or RFIC.

Chipathon 2026 team: **D03_ButterFold**.

One folded mixed-radix arithmetic core is shared across TX and RX. The same
hardware performs DFT12, FFT64, and IFFT64. Area minimization and hardware
reuse are primary design objectives.

Authoritative implementation: [`butterfold_proto/`](butterfold_proto/).
Do not infer intended behavior from `legacy/` or other sibling trees.

---

## Current Implementation Status

**TEAM-SIDE REVIEWER SIGNOFF COMPLETE**

This repository contains the current team-side ACH-integrated reviewer
implementation with the organizer Metal2 corner keep-out. Final
organizer-level integration/fill may occur later.

| | |
|---|---|
| Technology | GF180 MCU / OpenPDKs `gf180mcuD` |
| Standard cells | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | exactly **2 ×** `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Clock | **38.4 MHz** / 26.041667 ns |
| TX pacing | `TX_BYTE_INTERVAL = 10` |
| Canonical GDS | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| GDS SHA-256 | `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| ACH outer bbox | **1110 × 1675 µm** (organizer pin/integration envelope) |
| Compact CORE | `6.72 20.16 1085.84 1088.64` → **1079.12 × 1068.48 µm** |
| Metal2 keep-out | **(0, 0)–(2.0, 65.0) µm** — zero Metal2 in final GDS |
| Template pins | **23 / 23** matched |
| Setup | **PASS** — max-SS WNS **+0.119382 ns** |
| Hold | **PASS** — min-FF WNS **+0.180110 ns** |
| Routing | **PASS** — GRT overflow 0, DRT 0 |
| LVS | **PASS** — Circuits match uniquely |

The compact ButterFold implementation occupies the CORE above. The extra
outer height is organizer ACH integration / pin geometry, not expanded
standard-cell placement.

---

## Signoff Dashboard

Full package:
[`11_signoff_summary.md`](butterfold_proto/physical/reports/m2_fix/11_signoff_summary.md)

Official GF180 `density.drc` evaluates the full 1110 × 1675 µm GDS extent
(`CHIP = extent.sized(0.0)`). Empty OpenSTA `-violators` dumps mean zero
violations.

| Check | Status | Result | Report | Evidence |
|---|---|---|---|---|
| Organizer Metal2 keep-out | **PASS** | 1 rect (0,0)–(2.0,65.0) µm; final GDS intersection 0 | [delta](butterfold_proto/physical/reports/m2_fix/organizer_def_delta.md) | [audit](butterfold_proto/physical/reports/m2_fix/evidence/m2_audit/final_m2_intersection.json) |
| ACH DEF / template | **PASS** | 23 BTERMs, 21/21 functional, VDD/VSS, M2 1/1 | [template](butterfold_proto/physical/reports/m2_fix/00_template_apply.md) | [pins](butterfold_proto/physical/reports/m2_fix/evidence/template/template_pins.rpt) |
| Functional regression | **PASS** | Foundry-SRAM Icarus, `TX_BYTE_INTERVAL=10`; FINAL-PIN OVERALL RESULT: PASS | [12](butterfold_proto/physical/reports/m2_fix/12_functional.md) | [log](butterfold_proto/physical/reports/m2_fix/evidence/functional/interval10_regression.log) |
| Max-SS setup | **PASS** | `max_ss_125C_4v50` WNS **+0.119382 ns**, TNS 0, 0 violations | [01](butterfold_proto/physical/reports/m2_fix/01_setup_max_ss.md) | [STA](butterfold_proto/physical/reports/m2_fix/evidence/setup/max_ss_setup_summary.rpt) |
| Min-FF hold | **PASS** | `min_ff_n40C_5v50` WNS **+0.180110 ns**, TNS 0, 0 violations | [02](butterfold_proto/physical/reports/m2_fix/02_hold_min_ff.md) | [STA](butterfold_proto/physical/reports/m2_fix/evidence/hold/min_ff_hold_summary.rpt) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](butterfold_proto/physical/reports/m2_fix/03_electrical.md) | [log](butterfold_proto/physical/reports/m2_fix/evidence/electrical/extract_elec.log) / [fanout](butterfold_proto/physical/reports/m2_fix/evidence/electrical/fanout.rpt) |
| Reset electrical | **PASS** | slew 0, cap 0 | [04](butterfold_proto/physical/reports/m2_fix/04_reset.md) | [violators](butterfold_proto/physical/reports/m2_fix/evidence/reset/reset_visible_violators.rpt) |
| Routing | **PASS** | GRT overflow 0, DRT 0, opens/shorts/unrouted 0 | [08](butterfold_proto/physical/reports/m2_fix/08_routing_pg_ir.md) | [GRT](butterfold_proto/physical/reports/m2_fix/evidence/routing/grt_summary.rpt) / [DRT](butterfold_proto/physical/reports/m2_fix/evidence/routing/drt_summary.rpt) |
| PG connectivity | **PASS** | VDD connected, VSS connected | [08](butterfold_proto/physical/reports/m2_fix/08_routing_pg_ir.md) | [PSM](butterfold_proto/physical/reports/m2_fix/evidence/pg/psm_connectivity.rpt) |
| Antenna | **PASS** | 0 violating nets / 0 pins, **3** diodes | [05](butterfold_proto/physical/reports/m2_fix/05_antenna.md) | [OpenROAD](butterfold_proto/physical/reports/m2_fix/evidence/antenna/openroad_check_antennas.rpt) |
| Non-fill geometric DRC | **PASS** | 0 items, CO.6a = 0 | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [summary](butterfold_proto/physical/reports/m2_fix/evidence/drc/non_fill_drc_summary.rpt) |
| DCF.1d minimum-clear | **PASS** | COMP **23.75%** ≤ 70% | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [density](butterfold_proto/physical/reports/m2_fix/evidence/density/official_full_envelope_summary.rpt) |
| DCF.1b | **BELOW NOMINAL STANDALONE THRESHOLD ON ACH INTEGRATION ENVELOPE** | COMP **23.75%** < 25% | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [density](butterfold_proto/physical/reports/m2_fix/evidence/density/official_full_envelope_summary.rpt) |
| Poly2 PL.8 | **PASS** | **18.06%** ≥ 14% | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [density](butterfold_proto/physical/reports/m2_fix/evidence/density/official_full_envelope_summary.rpt) |
| M1.4 | **BELOW NOMINAL STANDALONE THRESHOLD ON ACH INTEGRATION ENVELOPE** | **21.77%** < 30% | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [density](butterfold_proto/physical/reports/m2_fix/evidence/density/official_full_envelope_summary.rpt) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 13.42 / 16.59 / 2.34 / 2.67 / 2.67 % | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [density](butterfold_proto/physical/reports/m2_fix/evidence/density/official_full_envelope_summary.rpt) |
| MSLOT | **PASS** | 0 items | [06](butterfold_proto/physical/reports/m2_fix/06_drc.md) | [lyrdb](butterfold_proto/physical/reports/m2_fix/evidence/mslot/mslot_unified.lyrdb) |
| Full device-level LVS | **PASS** | Circuits match uniquely; **11621** devices / **11640** nets; 2 SRAM | [07](butterfold_proto/physical/reports/m2_fix/07_lvs.md) | [summary](butterfold_proto/physical/reports/m2_fix/evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD worst **0.153 V** (3.40% of 4.5 V); VSS worst **0.090 V** (2.00%) | [08](butterfold_proto/physical/reports/m2_fix/08_routing_pg_ir.md) | [IR](butterfold_proto/physical/reports/m2_fix/evidence/ir/irdrop_summary.rpt) |
| Power | **INFO** | **0.136970 W** vectorless, no VCD/SAIF | [09](butterfold_proto/physical/reports/m2_fix/09_power.md) | [power](butterfold_proto/physical/reports/m2_fix/evidence/power/vectorless_power.rpt) |
| GDS / integration geometry | **PASS** | outer 1110 × 1675 µm; CORE ≤1110 × 1110; 0 rows above 1088.64 | [00](butterfold_proto/physical/reports/m2_fix/00_manifest.md) | [bbox](butterfold_proto/physical/reports/m2_fix/evidence/gds/gds_sha_bbox.rpt) / [floorplan](butterfold_proto/physical/reports/m2_fix/evidence/floorplan/core_rows_sram.rpt) |

---

## Architecture

ButterFold reuses one mixed-radix butterfly across TX and RX. The system is
half-duplex TDD; slot scheduling is **external**.

| Path | What it does |
|---|---|
| TX | 12 FDIQ complex samples → DFT12 → map to natural IFFT bins 1..12 → IFFT64 → CP insert → TDIQ |
| RX | TDIQ → CP remove → FFT64 → extract natural FFT bins 1..12 → 12 FDIQ samples |
| Diagnostics | FFT2 / IFFT2 / FFT3 / DFT12 / FFT64 / IFFT64 / ECHO / MAGIC / SRAM R/W |

**FFT size is 64**, not 128. Older 128-point notes under `legacy/` are superseded.

| Item | Value |
|---|---|
| External samples | signed 8-bit Q1.7, interleaved I then Q |
| Internal datapath | signed 16-bit, 7 fractional bits |
| CP (15 kHz, N=64) | short normal CP = 4 samples, long normal CP = 5 samples |

Command bytes on `din`: `0x40` FFT2, `0x41` FFT64, `0x42` IFFT64, `0x43` IFFT2,
`0x44` FFT3, `0x45` DFT12, `0x46`/`0x47` OFDM RX short/long, `0x48`/`0x49`
OFDM TX short/long, `0x4A` ECHO, `0x4B` MAGIC, `0x4C`/`0x4D` SRAM read/write.

### Logical chip interface

Logical ButterFold I/O (byte-stream core):

- Inputs: `rst_n`, `clk`, `din[7:0]`, `din_valid_i`
- Outputs: `din_ready_o`, `dout[7:0]`, `dout_valid_o`
- Power: `VDD`

All commands and data use that byte stream. No extra mode, debug, or SRAM pins
on the logical interface.

The ACH physical template adds organizer boundary geometry (23 BTERMs:
21 functional + VDD + VSS). That is the physical integration envelope, not a
change to the logical command protocol.

See [`final_frozen_pin_configuration.md`](butterfold_proto/docs/architecture/final_frozen_pin_configuration.md)
and [`AGENTS.md`](butterfold_proto/AGENTS.md).

### Arithmetic (shared core)

- Radix-2: \(X_0 = x_0 + W x_1\), \(X_1 = x_0 - W x_1\)
- Radix-3: algebraic 3-point DFT with one shared complex multiply
- DFT12: 3×4 Good-Thomas (4 radix-3 + 12 radix-2)
- FFT64/IFFT64: iterative radix-2 DIT, 6 stages; IFFT applies final `/64`
- Twiddles are constant ROM/logic, not SRAM

Do not silently change arithmetic scaling. Python golden models are the spec.

---

## Canonical Reviewer GDS

| | |
|---|---|
| Path | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| SHA-256 | `af6758ea9759ce7d48cb3b78bfea4cb13fdba6af8b18af94d56e73a09e6c8cd3` |
| ACH outer bbox | **1110 × 1675 µm** |
| Compact CORE | 1079.12 × 1068.48 µm (`6.72 20.16 1085.84 1088.64`) |
| Metal2 keep-out | (0, 0)–(2.0, 65.0) µm, **zero** Metal2 |

This is the GDS used for DRC, official density, MSLOT, antenna, Magic
extraction, and Netgen LVS.

Manifest: [`10_final_artifacts.md`](butterfold_proto/physical/reports/m2_fix/10_final_artifacts.md)

---

## Full device-level LVS

Team LVS of record is **Netgen device-level LVS**, not pin-only black-box
connectivity. LibreLane default `setup.tcl` is not the team method.

1. Magic 8.3 reads the GDS (`MAGIC_EXT_USE_GDS=1`)
2. Standard cells extract to real `nfet_05v0` / `pfet_05v0`
3. Source is the filled ECO powered netlist plus official GF180 `CELL_SPICE_MODELS`
4. Official `gf180mcuD_setup.tcl`
5. The two SRAM macros use the PDK-supported hard-macro blackbox

Result: **Circuits match uniquely** (**11621** devices, **11640** nets).

Report: [`07_lvs.md`](butterfold_proto/physical/reports/m2_fix/07_lvs.md)  
Evidence: [`lvs_summary.rpt`](butterfold_proto/physical/reports/m2_fix/evidence/lvs/lvs_summary.rpt)

---

## Reviewer evidence

A clone of this repository is the reviewer package.

1. [Signoff dashboard](butterfold_proto/physical/reports/m2_fix/11_signoff_summary.md)
2. [m2-fix report package](butterfold_proto/physical/reports/m2_fix/README.md)
3. [Functional log](butterfold_proto/physical/reports/m2_fix/evidence/functional/interval10_regression.log)
4. [Setup](butterfold_proto/physical/reports/m2_fix/01_setup_max_ss.md) · [Hold](butterfold_proto/physical/reports/m2_fix/02_hold_min_ff.md)
5. [DRC / density / MSLOT](butterfold_proto/physical/reports/m2_fix/06_drc.md)
6. [Full LVS](butterfold_proto/physical/reports/m2_fix/07_lvs.md)
7. [Final artifacts](butterfold_proto/physical/reports/m2_fix/10_final_artifacts.md)

Native OpenSTA / OpenROAD / KLayout / Netgen / Icarus copies live under
[`evidence/`](butterfold_proto/physical/reports/m2_fix/evidence/).

---

## Functional verification

Foundry-SRAM Icarus regression
([log](butterfold_proto/physical/reports/m2_fix/evidence/functional/interval10_regression.log))
passed at `TX_BYTE_INTERVAL=10`:

ECHO, MAGIC, SRAM R/W, FFT2, IFFT2, FFT3, DFT12 (`0x45`), FFT64 (`0x41`),
IFFT64 (`0x42`), OFDM RX short/long (`0x46`/`0x47`), OFDM TX short/long
(`0x48`/`0x49`). Reset-recovery also **PASS**.

From `butterfold_proto/`:

```bash
make -f Makefile.gf180_sram vectors
make -f Makefile.gf180_sram behavioral
make -f Makefile.gf180_sram foundry-functional
make -f Makefile.gf180_sram reset-recovery
```

`foundry-functional` uses the official GF180 SRAM Verilog in FUNCTIONAL mode
(no Icarus `-gspecify`). The default TB localparam is 1 unless overlaid;
committed evidence used `TX_BYTE_INTERVAL=10`.

Python golden generators under [`butterfold_proto/golden/`](butterfold_proto/golden/)
are the specification. Do not change them to make RTL pass.

---

## Project map

| Path | Role |
|---|---|
| [`butterfold_proto/rtl/`](butterfold_proto/rtl/) | Production RTL (`butterfold_top` and shared core) |
| [`butterfold_proto/verification/tb/`](butterfold_proto/verification/tb/) | Production testbenches |
| [`butterfold_proto/golden/`](butterfold_proto/golden/) | Golden models and vectors (spec) |
| [`butterfold_proto/physical/`](butterfold_proto/physical/) | LibreLane/OpenROAD flow, SDC, signoff reports |
| [`gds/butterfold_top.gds`](gds/butterfold_top.gds) | Canonical reviewer GDS |
| [`info.yaml`](info.yaml) | Chipathon project metadata |
| `legacy/` | Obsolete implementations — not source of truth |

Physical implementation used LibreLane 3.0.2, OpenROAD `26Q1-1024`, Magic 8.3,
KLayout 0.30.8, Netgen 1.5, OpenPDKs `gf180mcuD`.

---

## Integration Note

The repository contains the current ACH-integrated reviewer implementation.
Organizer-level final integration may introduce the final `D03_A` boundary,
pad-control details, and minimum-metal fill. The design will be reverified
if that integration changes the submitted physical artifact.

---

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
