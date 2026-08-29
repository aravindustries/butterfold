# D03/ACH DEF-template audit

Branch: `def-integration`  
Date: 2026-08-28

## Package

| Item | Value |
|---|---|
| Package | `D03.def/D03/project_defs/` |
| Selected variant | **ACH** (`D03_selected_variants.json`) |
| Participant pin count | **23** |
| Pad map `pin_count` | 23 |
| Interface origin | 350 µm, 910 µm |
| User slot | 1110 µm × 1675 µm |

## Official DEFs

| File | SHA-256 | Role |
|---|---|---|
| `D03_ACH_padring.def` | `ac1aed87ee53b70e9db7b93c45d8a145e1a253075320fd231210cd0a3bbce95d` | Full-chip padring: DESIGN `D03_ACH_padring`, 552 pad/filler COMPONENTS, 221 PINS named `N01`/`W08`/`W08_Y`/…, **no DIEAREA**. Coordinates are full-chip. |
| `D03_ACH.def` | `13a068191b9d827cc31cb0fc2fa36f25ecadb91d84730637ed9055323bc8e7c9` | Organizer **translation** of the padring into the user slot: DESIGN `D03_ACH`, DIEAREA `(0 0) (222000 335000)` @ 200 dbu/µm = **1110 × 1675 µm**, 135 PINS using participant names plus pad extras (`_PU`/`_PD`/`_CS`/`_OUT`/`_IN`/…). No COMPONENTS. |

No `*.lef` / `*.tlef` in the D03 package. IO cells are `gf180mcu_fd_io__*` from the installed PDK (`/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io`). No extra LEFs added to production config.

## Native ApplyDEFTemplate probes

LibreLane 3.0.2 `apply_def_template.py` / `defutil.relocate_pins`, OpenROAD-librelane 26Q1, against the existing production floorplan ODB (name-match probe only; old die is 1092.66 × 1119.54 µm).

### 1. Official padring DEF — strict

**FAIL.** Template pin names are pad slots (`N01`, `W08_Y`, …). Zero name overlap with `butterfold_top` (`clk`, `din[0]`, …). Full-chip coordinates and missing DIEAREA are not a user-project floorplan.

Do not apply this file as `FP_DEF_TEMPLATE` against core-only `butterfold_top`. It is the organizer assembly padring.

Log: `evidence/d03_ach/template/padring_strict.log`

### 2. Official translated `D03_ACH.def` — strict

**FAIL.** Inputs `clk`/`rst_n`/`din[]`/`din_valid_i` match. Outputs do **not**: bidirectional pads are split (`din_ready_o_OUT`, `dout_OUT[7]`, …) and 112 pad-control extras exist. Strict match requires identical signal-pin sets.

Log: `evidence/d03_ach/template/ach_strict.log`

This file **is** the organizer mapping (coordinate translation). It is not LibreLane-strict against a 23-terminal core.

### 3. 23-pin extract `d03_ach_user_template.def`

Built by `physical/librelane/gen_d03_ach_user_template.py` from official `D03_ACH.def` geometry only:

- input pads: cell **Y** (exact names)
- output/bi pads used as outputs: cell **A** (`*_OUT`)
- `VDD`/`VSS`: official Metal2 abutment rectangles

SHA-256: `1bba6ba77d205e953f04bc4874f461b003613e47073e9ab54bd2481729f14a39`

Strict + `--copy-def-power`: **FAIL** on VDD/VSS only. LibreLane matching excludes POWER/GROUND from the *template* set but includes them in the *design* set when copy-power is on. All 21 signal pins match.

Permissive + `--copy-def-power`: **PASS**. Warnings only for that VDD/VSS matching quirk. All 23 terminals written at official translated coordinates (ODB dbu 2000):

| Pin | Edge | Template box (µm, from DEF 200 dbu) |
|---|---|---|
| VSS | West | x=0, six Metal2 straps ~71.36–143.64 |
| clk … din[0], din_ready_o, dout_valid_o, dout[7], dout[6] | West | x=0 |
| dout[5] … dout[0], VDD | North | y=1674–1675 |

Log: `evidence/d03_ach/template/user23_permissive_power.log`

Permissive mode is **not** used to hide slot-name mismatches. It is required only for LibreLane’s POWER/GROUND matching quirk; every participant signal pin is present in the template.

## Production `FP_DEF_TEMPLATE`

```
dir::d03_ach_user_template.def
```

Resolved: `butterfold_proto/physical/librelane/d03_ach_user_template.def`

`FP_TEMPLATE_MATCH_MODE`: `permissive`  
`FP_TEMPLATE_COPY_POWER_PINS`: `true`

## Die / core (required by template)

Proven production floorplan used **relative** 60% util (config `DIE_AREA` was ignored; actual die 1092.66 × 1119.54 µm).

The ACH user slot is 1110 × 1675 µm. Absolute sizing is required so template pins lie on the die:

| | µm |
|---|---|
| DIE_AREA | 0, 0, 1110, 1675 |
| CORE_AREA | 6.72, 20.16, 1103.20, 1653.12 (9T site 0.56 × 5.04, same margin multiples as the proven relative flow) |
| FP_SIZING | absolute |

SRAM instances left at 51.120 / 531.120, 720.560 — still inside the new core.

## LEFs

Unchanged PDK set: 9T tech LEF, 9T cell LEF, SRAM LEF. No organizer LEF, no fabricated LEF, no IO LEF in the core config (pads are not instantiated in `butterfold_top`).

## Old pin overrides

This branch has no `IO_PIN_ORDER_CFG`, `pin_order.cfg`, or `place_power_pins_north.tcl`. `FP_DEF_TEMPLATE` is the pin authority. LibreLane skips IO placement when the template is set.
