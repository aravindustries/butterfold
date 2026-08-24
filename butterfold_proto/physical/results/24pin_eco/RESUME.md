# 24-pin physical signoff — pause checkpoint

Branch: `pin-redesign-24` (do not switch/create/merge).
Paused: 2026-08-24. Do not auto-commit. Do not overwrite `gds/butterfold_top.gds` yet
(that file is still the old 22-pin SHA `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6`).

When resuming, say: continue 24-pin physical signoff from `physical/results/24pin_eco/RESUME.md`.

## What already passed (do not redo)

### RTL (previous task)
Behavioral + foundry SRAM, interval-1 and interval-10, backpressure suite. Golden unchanged.

### LibreLane clean P&R
`physical/librelane/runs/butterfold_top_24pin_38p4_9t/`
- Tag: `butterfold_top_24pin_38p4_9t`
- Command used:

```
PDK_ROOT=/foss/pdks PDK=gf180mcuD librelane --manual-pdk --pdk-root /foss/pdks \
  -p gf180mcuD -s gf180mcu_fd_sc_mcu9t5v0 \
  --run-tag butterfold_top_24pin_38p4_9t --to OpenROAD.IRDropReport -j 16 \
  physical/librelane/config.json
```

- Synthesis: 24 ports including `dout_ready_i`, `VDD`, `VSS`; exactly 2 SRAM; `TX_BYTE_INTERVAL=10`.
- Pre-fill post-DRT ODB: `.../46-odb-reportdisconnectedpins/butterfold_top.odb`
- DRT violations = 0; antenna after LibreLane = 0; PDN VDD/VSS connected.
- LibreLane extracted max-SS **before ECO**: setup WNS **-7.35 ns** (same RC/slew class as 22-pin).

### Extracted-aware ECO (new netlist; do not replay 22-pin instance ECO)
Scripts:
- `physical/scripts/24pin_extracted_setup_close.tcl`
- `physical/scripts/24pin_hold_eco.tcl`
- `physical/scripts/24pin_extracted_sta.tcl`

**Authoritative routed database (use this):**
- ODB: `physical/results/24pin_eco/hold_eco/routed.odb`
- DEF: `physical/results/24pin_eco/hold_eco/routed.def`
- Powered netlist: `physical/results/24pin_eco/hold_eco/butterfold_top.final.pnl.v`

Native OpenRCX STA on that ODB (`24pin_extracted_sta.tcl`):
- max-SS setup: WNS **0.00**, TNS **0.00**, setup violators **none**
- min-FF hold: WNS **0.00**, TNS **0.00**, hold violators **none**
- max slew / max cap violator reports **empty** (data/reset)
- `dout_ready_i` setup slack ~**6.19 ns MET**
- OpenROAD antenna after hold ECO: **0 nets, 0 pins**, **16** `antenna` cells
- Die: **1093.710 × 1120.590 µm = 1.225600 mm²** (≤ 1.25)
- Pins: **24** including `dout_ready_i`, `VDD`, `VSS`
- SRAM: **2**

IR (`set_pdnsim_net_voltage`):
- VDD connected, worst drop **2.59 mV** (0.05%)
- VSS connected, worst drop **1.27 mV** (0.03%)
- Vectorless power ~**0.265 W** (TT, not VCD)

### GDS (not promoted)
Preferred streamout (LibreLane Magic methodology):
- `physical/results/24pin_eco/magic_gds/butterfold_top.magic.gds`
- SHA-256: `94f7fbd56b45cdb38c216834d6e6d8bf86293a589c3e51bcb27690b7a6fc1093`

KLayout DEF streamout (0.5 nm dbu; Magic extract needed rescale; **do not promote**):
- `physical/results/24pin_eco/gds/butterfold_top.gds`
- SHA-256: `99e374359f6fa0f51c389eba64daf6bfe48a873e251930e8cf60457ec8905727`

### Density (same ratios on both GDS files)
| Rule | Value | Status |
|---|---|---|
| DCF.1b COMP | 25.76% | PASS (≥25%) |
| DCF.1d COMP | 25.76% | PASS (≤70%) |
| PL.8 Poly2 | 19.78% | PASS (≥14%) |
| M1.4 | 30.08% | PASS (>30%) |
| M2.4–MT.3 | 20.27 / 25.43 / 3.23 / 3.39 / 3.39% | **INTEGRATOR FILL PENDING** |

## What was in flight when paused

1. **KLayout DRC on Magic GDS** (the one that matters). Log:
   `physical/results/24pin_eco/drc_magic/klayout_full.log`
   Last seen in **CO.6** (this rule took ~22 min on the KLayout GDS).
   First KLayout-streamout DRC already finished with **13319** items
   (`PP.2/NP.2/NW.*` plus 14 `CO.6a`) — treat that as the wrong GDS, not the
   Magic streamout.

   Resume DRC if the process died:

```
python3 /foss/pdks/gf180mcuD/libs.tech/klayout/tech/drc/run_drc.py \
  --path=$(pwd)/physical/results/24pin_eco/magic_gds/butterfold_top.magic.gds \
  --variant=D --topcell=butterfold_top --run_mode=flat \
  > physical/results/24pin_eco/drc_magic/klayout_full.log 2>&1
```

2. **MSLOT unified** (`table_name=main`) not yet run on Magic GDS.

3. **Full device LVS not uniquely matched.**
   - Layout spice (Magic GDS extract): `physical/results/24pin_eco/lvs_magic/extract/butterfold_top.spice`
   - Source: `hold_eco/butterfold_top.final.pnl.v` + `CELL_SPICE_MODELS`
   - Stdcell **classes uniquely match**; top **pins equivalent** (`dout_ready_i`, `VDD`, `VSS`)
   - Only count mismatch: antenna **layout 5 vs source 16**
   - Top: **7 badnets, 18 badelements** (several badnets look like netgen symmetry)
   - Do **not** call LVS PASS until `Final result: Circuits match uniquely`

## Resume order

1. Let Magic-GDS KLayout DRC finish (or restart it). Expect ~1 hour. Geometric
   PASS means no `[ERROR]` besides density min-metal if density is included.
2. Unified MSLOT on Magic GDS (`table_name=main`).
3. Debug LVS antenna extract (5 vs 16) until unique match.
4. Copy Magic GDS SHA into reviewer reports. **Only then** copy that exact file
   over repo-root `gds/butterfold_top.gds`.
5. Replace `physical/reports/signoff/*.md` with 24-pin numbers.
   22-pin markdown is already archived at
   `physical/reports/archive/22pin_pre_vss_ready/`.

## Tracked vs untracked

Tracked edits (keep):
- `physical/constraints.sdc` (`dout_ready_i` input delay)
- `physical/librelane/config.json` (duplicate key removed)

Untracked / gitignored (needed to resume, do not `git add` giant runs):
- `physical/librelane/runs/butterfold_top_24pin_38p4_9t/`
- `physical/results/24pin_eco/` (gitignored under `physical/results/`)
- `physical/scripts/24pin_*.tcl` and `streamout_core_gds.py` (small; OK to track)
- `physical/reports/archive/`
- `drc_run_*` at proto root (scratch; do not commit)
