# ButterFold area compliance — pre-DEF shrink

**THIS PROVES AREA COMPLIANCE.**

Full signoff will be rerun after the official final `D03_A.def` arrives.
This is **not** final D03 integration and **not** tapeout signoff.

Branch: `shrink-area` (forked from current `main`).
Implementation run: `physical/librelane/runs/shrink_area_demo`

## Organizer maximum vs ButterFold size

| | Width (µm) | Height (µm) |
|---|---:|---:|
| Organizer maximum (Block A) | 1110 | 1110 |
| Previous production | 1092.66 | 1119.54 |
| **New shrunk implementation** | **1092.66** | **1108.80** |
| Margin to 1110 | **17.34** | **1.20** |

Measured from generated DEF `DIEAREA (0 0) (2185320 2217600)` at 2000 dbu/µm,
and independently from demonstration GDS top-cell bbox `(0, 0) – (1092.66, 1108.80)`.

```
AREA_LIMIT_PASS = YES
width  1092.66 ≤ 1110
height 1108.80 ≤ 1110
```

## Floorplan used

Production LibreLane config now has:

```
FP_SIZING = absolute
DIE_AREA  = [0, 0, 1092.66, 1108.80]
CORE_AREA = [6.72, 20.16, 1085.84, 1088.64]
```

Clock unchanged: **38.4 MHz / 26.041667 ns**.
No ACH template. No guessed pad-control pins. No `D03_A.def`.

## SRAM

| | |
|---|---|
| Count | **2** × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| SRAM0 (`u_lo`) | 51.120, 720.560, R0/N |
| SRAM1 (`u_hi`) | 531.120, 720.560, R0/N |
| Inside core | YES |
| Overlap | NO |

Placement is the proven production locations, unchanged.

## Placement and routing (organizer-facing)

| Check | Result |
|---|---|
| Placement | **PASS** (legal; DPL max displacement 0.0 µm) |
| Global routing | **PASS**, overflow **0** |
| Detailed routing | **PASS**, violations **0** |
| Unrouted nets | **0** |
| Opens | **0** |
| Shorts | **0** |
| Disconnected pins | **0** |

```
AREA + ROUTABILITY DEMONSTRATION = PASS
```

## Timing (pre-ECO feasibility, not closed)

Extracted STA after this clean route, 38.4 MHz / 26.041667 ns:

| | |
|---|---|
| max-SS setup WNS | **−8.483 ns** |
| max-SS setup TNS | **−3152.055 ns** |
| max-SS setup violations | **796** |
| min-FF hold WNS / TNS | **0 / 0** |
| min-FF hold slack | **+0.423 ns** |
| max-SS slew / cap / fanout | 559 / 55 / 0 |

This is a **pre-ECO starting point**. The previous production post-route
LibreLane starting point was approximately **−9.51 ns** at the same 38.4 MHz
target and was later closed. The shrink did not fundamentally damage timing
feasibility.

`rst_n` still has ~1461 sinks. A regional reset tree will be rebuilt after
the official DEF. It was not rebuilt on this temporary pre-DEF layout.

## Demonstration GDS

Streamed for area evidence only. **Canonical `gds/butterfold_top.gds` was not overwritten.**

| | |
|---|---|
| Path | `physical/results/shrink_area/butterfold_top.gds` |
| SHA-256 | `8f48cd4e9329b05b8e064323025529daef90a7a646997230b2f95cbf87aa8496` |
| Top-cell bbox | 1092.66 × 1108.80 µm |

No full KLayout, density, MSLOT, LVS, or IR was run.

## Final D03 integration

```
OFFICIAL D03_A.def: NOT YET AVAILABLE
FULL SIGNOFF: PENDING THAT DEF
```
