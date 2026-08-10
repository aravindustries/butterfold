# ButterFold

ButterFold is a minimum-area, half-duplex GF180 lower-PHY transform engine for
one-RB, 15 kHz operation.

## Current architecture

- 16-bit signed internal datapath with 7 fractional bits
- 2 x GF180 256x8 SRAM macros; no 512x8 waveform SRAM
- one shared mixed-radix butterfly and one scalar multiplier
- FFT initiation interval: 8 cycles/butterfly
- FFT128/IFFT128: 3,601 cycles
- externally scheduled 50% grid-aligned symbol allocation contract
- frozen 22-pin logical interface

## Current status

The core and pad-aware input/clock candidate are detailed-routed and extracted
timing-clean at 61.44 MHz. Routing DRC is zero. Input-pad transitions and the
clock root are valid. Output-pad electrical closure at the assumed 5 pF load
is still in progress; do not begin clock gating from an assumption that the
complete pad specification is frozen.

No GDS was streamed from the current authoritative run. See
[`physical/results/CURRENT_RUN.md`](physical/results/CURRENT_RUN.md) for the
authoritative ODB, DEF, SPEFs, DRC report, STA directory, and required future
GDS merge collateral.

## Project map

- `rtl/`: authoritative production RTL
- `verification/tb/`: authoritative testbenches
- root `gen_*.py`, `two_point_golden.py`, and `vectors/`: immutable golden
  generators/reference data (kept at stable paths to preserve byte-identical
  behavior)
- `timing/`: synthesis and pre-layout STA
- `physical/`: reusable floorplan, CTS, routing, extraction, and signoff flow
- `reports/current/`: active architecture and physical reports
- `reports/history/`: superseded/rejected engineering studies
- `experiments/`: isolated non-authoritative studies
- `legacy/`: obsolete compatibility RTL/testbenches
- `build/`: ignored generated simulation artifacts

## Verification

```bash
make -f Makefile.gf180_sram behavioral
make -f Makefile.gf180_sram foundry-functional
make -f Makefile.gf180_sram padframe-smoke
make -f Makefile.gf180_sram reset-recovery
```

## Physical flow

```bash
make -C physical padframe-build
make -C physical padframe-electrical
make -C physical padframe-signoff
```

Full placement/routing targets are documented in `physical/README.md` and
`physical/Makefile`. Generated results remain under `physical/results/`.
