# ButterFold — modular DFT-s-OFDM chip (GF180 PPA)

A 5G-NR-inspired **DFT-s-OFDM** transform chip (K=12 subcarriers, M=128 FFT/IFFT,
CP=9/10), decomposed into the **six hardware modules** specified in
`butterfold_module_io.md` and integrated into one top (`rtl/butterfold_top.v`).

This repo carries the RTL plus a fast **area / timing / power** flow on the open
**GF180MCU** PDK, comparing two ways to build the FFT scratch memory — a flip-flop
**register file** vs a **GF180 SRAM macro**.

## The 6 modules (+ top)
| module | role |
|---|---|
| `scheduler_addr_control` | sequences DFT-12 / FFT-128 / IFFT-128; generates addresses, CP and mapping control |
| `unified_mixed_radix_core` | 128×16 complex scratch memory + shared complex multiplier + radix-2 butterfly |
| `twiddle_source` | quantized Q1.7 twiddle ROM (with conjugation for inverse) |
| `subcarrier_map_extract` | TX map / RX extract between 12 subcarriers and the 128-bin grid |
| `fdiq_io_adapter` | frequency-domain I/Q byte ↔ 16-bit complex packing |
| `tdiq_io_adapter_cp` | time-domain I/Q packing + CP insert/remove |
| `butterfold_top` | wires all six to the chip interface |

## Layout
| path | what |
|---|---|
| `butterfold_module_io.md` | the spec — single source of truth |
| `rtl/` | the 6 modules + structural top (register-file memory) |
| `rtl_sram/` | SRAM-macro core variant (4× GF180 `sram128x8`) + macro blackbox |
| `scripts/` | PPA + schematic-generation flows |
| `schematics/` | architecture + netlist schematics |
| `butterfold_sim/` | Python cycle / fixed-point transform model |
| `PPA.md` | how to reproduce the area/timing/power numbers |
| `REPORT.md` | results + explanations |

## Run the PPA (inside the IIC-OSIC-TOOLS container, from repo root)
```bash
bash scripts/ppa_regfile.sh    # register-file memory -> area, timing, power, schematic
bash scripts/ppa_sram.sh       # SRAM-macro memory    -> area, timing, power
bash scripts/gen_schematics.sh # (re)generate the schematics
```

See **[REPORT.md](REPORT.md)** for the numbers and **[PPA.md](PPA.md)** for the
per-metric commands.
