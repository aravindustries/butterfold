# North/West pin-placement re-closure — audit

Branch: `pin-placement-redesign` (from current `main`).
RTL / golden / clock / SRAM / SDC: frozen. No `dout_ready_i`.

## Proven runbook (reuse, do not reinvent)

| Item | Value |
|---|---|
| Orchestrator | LibreLane 3.0.2 `--manual-pdk` `gf180mcuD` / `gf180mcu_fd_sc_mcu9t5v0` |
| Production tag | `butterfold_top_38p4_interval10_production_9t` |
| Clock | 38.4 MHz / 26.041667 ns, `TX_BYTE_INTERVAL=10` |
| Die | `1116.640 × 1113.840` µm (≤ 1.25 mm²; previous 1.223277 mm²) |
| SRAM | 2 × `sram256x8m8wm1` at `(51.120, 720.560)` and `(531.120, 720.560)` R0 |
| PDN | `pdn_sram.tcl`, Metal4/Metal5, rails Metal1, `PDN_ENABLE_PINS` |
| IO mechanism (old) | `IO_PIN_PLACEMENT_MODE=matching`, `IO_PIN_ORDER_CFG=null` → OpenROAD `place_pins` on all four sides |
| Extracted ECO | OpenROAD `repair_design` / `repair_timing` vs OpenRCX (SS-only setup, FF-only hold) |
| Team GDS | Magic streamout (`PRIMARY_GDSII_STREAMOUT_TOOL=magic`), not KLayout 0.5 nm DEF |
| Full LVS | Magic `MAGIC_EXT_USE_GDS=1` + `CELL_SPICE_MODELS` + Netgen `gf180mcuD_setup.tcl` |
| Density | DCF.1d COMP ≤ 70% team-side; M2.4–MT.3 integrator fill pending |
| MSLOT | unified `table_name=main`, not split `--table=mslot` |

## Previous terminal locations (production DEF, units 2000)

Die `(0,0)–(1092.66, 1119.54)` µm. 23 PINS.

| Terminals | Side (approx) |
|---|---|
| `clk`, `rst_n`, `din_ready_o`, `dout[0]`, `dout_valid_o` | WEST |
| `din[7:0]`, `din_valid_i` | NORTH |
| `dout[1]…dout[7]` | EAST |
| (none) | SOUTH |
| `VDD`/`VSS` | PDN stripe pins (interior/east origin); POWER/GROUND |

OpenROAD IO placement log: **21 signal I/Os** (VDD/VSS excluded from `place_pins`).

## New mechanism

LibreLane native `IO_PIN_ORDER_CFG` → `Odb.CustomIOPlacement` (`io_place.py`).
That script **skips POWER/GROUND**, so VDD/VSS north-edge access is added in `pdn_sram.tcl` via OpenROAD `place_pin` on existing ports (Metal4, east-north, overlapping the vertical PDN layer). No new ports.

Target: WEST 11 signal inputs, NORTH 10 signal outputs + VDD + VSS, EAST 0, SOUTH 0.
