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

**TEAM-SIDE REVIEWER SIGNOFF COMPLETE (22-pin compact core)**

This is the compact 22-pin ButterFold production chip. It does **not** use
ACH DEF / `FP_DEF_TEMPLATE`. VSS counts toward the pin limit.

| | |
|---|---|
| Technology | GF180 MCU / OpenPDKs `gf180mcuD` |
| Standard cells | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | exactly **2 ×** `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Clock | **38.4 MHz** / 26.041667 ns |
| TX pacing | `TX_BYTE_INTERVAL = 10` |
| Canonical GDS | [`gds/butterfold_top.gds`](gds/butterfold_top.gds) |
| GDS SHA-256 | `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |
| Die | **1092.66 × 1108.80 µm** (1.211541 mm²) ≤ 1110 × 1110 |
| CORE | `6.72 20.16 1085.84 1088.64` |
| Physical terminals | **22** including VDD and VSS |
| Status pin | `stream_status_o` (READY in input phase, VALID in output phase) |
| Setup | **PASS** — max-SS worst MET **+0.079 ns** |
| Hold | **PASS** — min-FF worst MET **+0.027 ns** |
| Routing | **PASS** — GRT overflow 0, DRT 0 |
| LVS | **PASS** — Circuits match uniquely |

---

## Signoff Dashboard

Full package:
[`11_signoff_summary.md`](butterfold_proto/physical/reports/pin22_signoff/11_signoff_summary.md)

Empty OpenSTA `-violators` dumps mean zero violations.

| Check | Status | Result | Report | Evidence |
|---|---|---|---|---|
| ACH DEF / `FP_DEF_TEMPLATE` | **NOT USED** | compact LibreLane floorplan | [00](butterfold_proto/physical/reports/pin22_signoff/00_manifest.md) | [fill](butterfold_proto/physical/reports/pin22_signoff/evidence/routing/fill.log) |
| Functional regression | **PASS** | Foundry-SRAM Icarus, `TX_BYTE_INTERVAL=10`; FINAL-PIN OVERALL RESULT: PASS | [12](butterfold_proto/physical/reports/pin22_signoff/12_functional.md) | [log](butterfold_proto/physical/reports/pin22_signoff/evidence/functional/interval10_regression.log) |
| Stream-status protocol | **PASS** | STREAM-STATUS RESULT: PASS | [12](butterfold_proto/physical/reports/pin22_signoff/12_functional.md) | [log](butterfold_proto/physical/reports/pin22_signoff/evidence/functional/stream_status.log) |
| Max-SS setup | **PASS** | `max_ss_125C_4v50` worst MET **+0.079 ns**, TNS 0, 0 violations | [01](butterfold_proto/physical/reports/pin22_signoff/01_setup_max_ss.md) | [STA](butterfold_proto/physical/reports/pin22_signoff/evidence/setup/sta_filled.log) |
| Min-FF hold | **PASS** | `min_ff_n40C_5v50` worst MET **+0.027 ns**, TNS 0, 0 violations | [02](butterfold_proto/physical/reports/pin22_signoff/02_hold_min_ff.md) | [STA](butterfold_proto/physical/reports/pin22_signoff/evidence/hold/sta_capfix_ff.log) |
| Electrical | **PASS** | slew/cap/fanout = 0 | [03](butterfold_proto/physical/reports/pin22_signoff/03_electrical.md) | [rpt](butterfold_proto/physical/reports/pin22_signoff/evidence/electrical/elec_filled.rpt) |
| Reset electrical | **PASS** | slew 0, cap 0 | [04](butterfold_proto/physical/reports/pin22_signoff/04_reset.md) | [violators](butterfold_proto/physical/reports/pin22_signoff/evidence/reset/reset_visible.rpt) |
| Routing | **PASS** | GRT overflow 0, DRT 0, opens/shorts/unrouted 0 | [08](butterfold_proto/physical/reports/pin22_signoff/08_routing_pg_ir.md) | [GRT](butterfold_proto/physical/reports/pin22_signoff/evidence/routing/capfix_route.log) / [fill](butterfold_proto/physical/reports/pin22_signoff/evidence/routing/fill.log) |
| PG connectivity | **PASS** | VDD connected, VSS connected | [08](butterfold_proto/physical/reports/pin22_signoff/08_routing_pg_ir.md) | [PSM](butterfold_proto/physical/reports/pin22_signoff/evidence/ir/ir_power.log) |
| Antenna | **PASS** | 0 violating nets / 0 pins, **23** diodes | [05](butterfold_proto/physical/reports/pin22_signoff/05_antenna.md) | [OpenROAD](butterfold_proto/physical/reports/pin22_signoff/evidence/routing/fill.log) / [KLayout](butterfold_proto/physical/reports/pin22_signoff/evidence/antenna/klayout_antenna.lyrdb) |
| Non-fill geometric DRC | **PASS** | 0 items, CO.6a = 0 | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [main](butterfold_proto/physical/reports/pin22_signoff/evidence/drc/main.lyrdb) / [contact](butterfold_proto/physical/reports/pin22_signoff/evidence/drc/contact.lyrdb) |
| DCF.1d minimum-clear | **PASS** | COMP **36.338%** ≤ 70% | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [density](butterfold_proto/physical/reports/pin22_signoff/evidence/density/density.log) |
| DCF.1b | **PASS** | COMP **36.338%** ≥ 25% | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [density](butterfold_proto/physical/reports/pin22_signoff/evidence/density/density.log) |
| Poly2 PL.8 | **PASS** | **27.600%** ≥ 14% | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [density](butterfold_proto/physical/reports/pin22_signoff/evidence/density/density.log) |
| M1.4 | **PASS** | **33.325%** > 30% | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [density](butterfold_proto/physical/reports/pin22_signoff/evidence/density/density.log) |
| M2.4–MT.3 | **INTEGRATOR FILL PENDING** | 19.75 / 25.26 / 3.42 / 4.62 / 4.62 % | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [density](butterfold_proto/physical/reports/pin22_signoff/evidence/density/density.log) |
| MSLOT | **PASS** | 0 items | [06](butterfold_proto/physical/reports/pin22_signoff/06_drc.md) | [lyrdb](butterfold_proto/physical/reports/pin22_signoff/evidence/mslot/mslot.lyrdb) |
| Full device-level LVS | **PASS** | Circuits match uniquely; **11568** devices / **11582** nets; 2 SRAM; 22 pins | [07](butterfold_proto/physical/reports/pin22_signoff/07_lvs.md) | [summary](butterfold_proto/physical/reports/pin22_signoff/evidence/lvs/lvs_summary.rpt) |
| IR | **CHARACTERIZED** | VDD worst **1.82 mV** (0.04% of 4.5 V); VSS worst **2.26 mV** (0.05%) | [08](butterfold_proto/physical/reports/pin22_signoff/08_routing_pg_ir.md) | [IR](butterfold_proto/physical/reports/pin22_signoff/evidence/ir/ir_power.log) |
| Power | **INFO** | **0.1465 W** vectorless, no VCD/SAIF | [09](butterfold_proto/physical/reports/pin22_signoff/09_power.md) | [power](butterfold_proto/physical/reports/pin22_signoff/evidence/power/power_vectorless_max_ss.rpt) |
| GDS geometry | **PASS** | 1092.66 × 1108.80 µm ≤ 1110 × 1110; 22 BTERMs | [00](butterfold_proto/physical/reports/pin22_signoff/00_manifest.md) | [sha](butterfold_proto/physical/reports/pin22_signoff/evidence/gds/butterfold_top.gds.sha256) |

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

Physical/logical ButterFold I/O (22 terminals including VDD and VSS):

- Inputs: `rst_n`, `clk`, `din[7:0]`, `din_valid_i`
- Outputs: `stream_status_o`, `dout[7:0]`
- Power: `VDD`, `VSS`

`stream_status_o` is READY during the input/command phase and VALID during
the output phase. The host knows the phase from the command it issued.
Internal `din_ready` / `dout_valid` are not chip pins.

All commands and data use that byte stream. No extra mode, debug, or SRAM pins.

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
| SHA-256 | `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |
| Die | **1092.66 × 1108.80 µm** |
| CORE | `6.72 20.16 1085.84 1088.64` |

This is the GDS used for DRC, official density, MSLOT, antenna, Magic
extraction, and Netgen LVS.

Manifest: [`10_final_artifacts.md`](butterfold_proto/physical/reports/pin22_signoff/10_final_artifacts.md)

---

## Full device-level LVS

Team LVS of record is **Netgen device-level LVS**, not pin-only black-box
connectivity. LibreLane default `setup.tcl` is not the team method.

1. Magic 8.3 reads the GDS (`MAGIC_EXT_USE_GDS=1`)
2. Standard cells extract to real `nfet_05v0` / `pfet_05v0`
3. Source is the filled ECO powered netlist plus official GF180 `CELL_SPICE_MODELS`
4. Official `gf180mcuD_setup.tcl`
5. The two SRAM macros use the PDK-supported hard-macro blackbox

Result: **Circuits match uniquely** (**11568** devices, **11582** nets).

Report: [`07_lvs.md`](butterfold_proto/physical/reports/pin22_signoff/07_lvs.md)  
Evidence: [`lvs_summary.rpt`](butterfold_proto/physical/reports/pin22_signoff/evidence/lvs/lvs_summary.rpt)

---

## Reviewer evidence

A clone of this repository is the reviewer package.

1. [Signoff dashboard](butterfold_proto/physical/reports/pin22_signoff/11_signoff_summary.md)
2. [22-pin report package](butterfold_proto/physical/reports/pin22_signoff/README.md)
3. [Functional log](butterfold_proto/physical/reports/pin22_signoff/evidence/functional/interval10_regression.log)
4. [Setup](butterfold_proto/physical/reports/pin22_signoff/01_setup_max_ss.md) · [Hold](butterfold_proto/physical/reports/pin22_signoff/02_hold_min_ff.md)
5. [DRC / density / MSLOT](butterfold_proto/physical/reports/pin22_signoff/06_drc.md)
6. [Full LVS](butterfold_proto/physical/reports/pin22_signoff/07_lvs.md)
7. [Final artifacts](butterfold_proto/physical/reports/pin22_signoff/10_final_artifacts.md)

Native OpenSTA / OpenROAD / KLayout / Netgen / Icarus copies live under
[`evidence/`](butterfold_proto/physical/reports/pin22_signoff/evidence/).

---

## Functional verification

Foundry-SRAM Icarus regression
([log](butterfold_proto/physical/reports/pin22_signoff/evidence/functional/interval10_regression.log))
passed at `TX_BYTE_INTERVAL=10`:

ECHO, MAGIC, SRAM R/W, FFT2, IFFT2, FFT3, DFT12 (`0x45`), FFT64 (`0x41`),
IFFT64 (`0x42`), OFDM RX short/long (`0x46`/`0x47`), OFDM TX short/long
(`0x48`/`0x49`). Reset-recovery and stream-status protocol also **PASS**.

From `butterfold_proto/`:

```bash
make -f Makefile.gf180_sram vectors
make -f Makefile.gf180_sram behavioral
make -f Makefile.gf180_sram foundry-functional
make -f Makefile.gf180_sram reset-recovery
make -f Makefile.gf180_sram stream-status
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
