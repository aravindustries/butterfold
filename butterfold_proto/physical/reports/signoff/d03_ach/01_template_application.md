# Template application (native LibreLane)

Run: `physical/librelane/runs/d03_ach_fp_template/`  
Command: `librelane --manual-pdk --pdk gf180mcuD --scl gf180mcu_fd_sc_mcu9t5v0 --run-tag d03_ach_fp_template --to Odb.ApplyDEFTemplate config.json`

| Item | Result |
|---|---|
| Status | **PASS** |
| Die | 0, 0, **1110, 1675** µm |
| Core | 6.72, 20.16, 1103.20, 1653.12 µm |
| Rows | 324 × 1958 sites (GF018hv5v_green_sc9) |
| `FP_DEF_TEMPLATE` | `dir::d03_ach_user_template.def` → absolute path next to `config.json` |
| Pin match | 21/21 signal pins exact; VDD/VSS copied (`FP_TEMPLATE_COPY_POWER_PINS`) |
| SRAM | 2 × sram256x8m8wm1 at 51.120,720.560 and 531.120,720.560 |

Pin coordinates match official `D03_ACH.def` translated_user boxes (input pad Y, output pad A). Evidence: `evidence/d03_ach/librelane/applied_pins.rpt`.

The LibreLane warning that the template die is 11100×16750 µm is a UNITS MICRONS 200 vs design 2000 reporting artifact. Placed pin dbu/2000 is 1110×1675.

IO placement and skip-IO GPL were skipped because the template is set. That is native LibreLane behavior; pins are applied in `Odb.ApplyDEFTemplate` before full GPL.
