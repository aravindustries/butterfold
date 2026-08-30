> **Historical pre-ACH shrunk production baseline** (die 1092.66 × 1108.80 µm, SHA `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`). This is **not** the current `def-integration-resized` ACH validation GDS (`93f2aba1…`, 1110 × 1675 µm). See [`../d03_ach_resized/`](../d03_ach_resized/README.md).

# 00 — Signoff manifest

## Purpose

Tools, PDK identity, shrink-area filled ECO artifacts.

## Tool

| Item | Value |
|---|---|
| Branch | `shrink-area` |
| HEAD | `8def6b739e28a71ab91986f9ad42a1847751f293` |
| LibreLane | 3.0.2 |
| OpenROAD / OpenSTA | 26Q2-254-g61932e897 |
| Magic | 8.3.636 |
| KLayout | 0.30.8 |
| Netgen | 1.5.318 |
| PDK | gf180mcuD (`PDKPATH=/foss/pdks/gf180mcuD`) |
| SCL | `gf180mcu_fd_sc_mcu9t5v0` |
| SRAM | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| Clock | 38.4 MHz / 26.041667 ns |
| TX pacing | `TX_BYTE_INTERVAL=10` |

Chipathon density: team GDS must pass **minimum-clear / maximum-metal**.
Official `density.drc` maximum is **DCF.1d COMP ≤ 70%** only (no M2–MT max).
Minimum-metal M2.4–MT.3 is **integrator fill pending**.

`mslot.drc` **crashes** in split-table mode (`TABLE_NAME=mslot`, `contact` nil).
The same official `mslot.drc` **PASSES** with `table_name=main` (contact/vias
loaded): 0 items on Metal1–Metal5.

## Floorplan (frozen)

| Item | Value |
|---|---|
| `FP_SIZING` | absolute |
| DIE_AREA | `[0, 0, 1092.66, 1108.80]` |
| CORE_AREA | `[6.72, 20.16, 1085.84, 1088.64]` |

## Historical shrink GDS (this package)

| Artifact | SHA-256 |
|---|---|
| Filled Magic streamout / shrink team GDS | `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` |
| Previous main/pre-ACH `gds/butterfold_top.gds` | `f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906` |

All GDS-dependent checks in **this** `signoff/` directory used SHA `f193cb1b…`.

Die **1092.66 × 1108.80 µm = 1.211541 mm²** (≤ 1110 × 1110 and ≤ 1.25 mm²).

On `def-integration-resized`, repo-root `gds/butterfold_top.gds` has been
promoted to the ACH validation GDS SHA `93f2aba1…` (1110 × 1675 µm).
Do not use this directory’s metrics as the current branch GDS.

This is **not** final D03_A.def post-integration manufacturing signoff.
Minimum-metal fill remains integrator pending.

## Evidence

Native copies: [evidence/](evidence/). Heavy ODB/SPEF/GDS remain gitignored
under `physical/results/`.
