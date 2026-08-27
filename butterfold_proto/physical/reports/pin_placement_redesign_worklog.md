# North/West pin-placement overnight worklog

Branch: `pin-placement-redesign`. Do not auto-commit. Do not overwrite `gds/butterfold_top.gds` until the promotion gate.

## Attempt 1 — configuration

- Added `physical/librelane/pin_order.cfg` (WEST inputs, NORTH outputs, empty E/S, `$6` virtual slots on east-north for VDD/VSS).
- Set `IO_PIN_ORDER_CFG` in `physical/librelane/config.json`.
- Added north-edge `place_pin` for existing VDD/VSS in `pdn_sram.tcl` (no new ports, PDN grid unchanged).
- RTL/golden/SDC/die/SRAM/clock untouched.

## Attempt 2 — LibreLane to CustomIOPlacement

LibreLane `--to Odb.CustomIOPlacement` completed (tag `butterfold_top_nw_pins_38p4_9t`).

CustomIOPlacement:
- WEST: 11 signal pins (spread on 250 tracks)
- NORTH: 10 signal pins + 6 virtual slots
- EAST/SOUTH: empty

`place_pin` in `pdn_sram.tcl` ran **before** `pdngen`, so VDD/VSS Metal4 shapes at the north edge were **islands** (PSM-0038 / PSM-0069). Reverted that PDN_CFG change.

## Attempt 3 — clean PDN + post-PDN north VDD/VSS

New tag `butterfold_top_nw_pins_38p4_9t_b`. PDN: all VDD/VSS shapes connected.

After CustomIOPlacement:
- WEST 11 / NORTH 10 signal pins as specified; EAST 0 SOUTH 0
- Then `place_power_pins_north.tcl` overlapped Metal4 PDN at x≈944.6/947.9 and the north edge
- Dump: **PIN_SIDES_PASS** NORTH=12 WEST=11 EAST=0 SOUTH=0 TOTAL=23

Continuing LibreLane `--from OpenROAD.GlobalPlacement --to OpenROAD.IRDropReport`.

## Attempt 4 — LibreLane P&R

Tag `butterfold_top_nw_pins_38p4_9t_c`. Exit 0.

- DRT violations = 0 (iter 0:371 → 4:0)
- GRT overflow = 0
- Antenna 0 nets / 0 pins; 13 antenna cells
- Disconnected pins = 0; power grid violations = 0
- Post-DRT pin dump: **PIN_SIDES_PASS** N=12 W=11 E=0 S=0
- Die 1.223277 mm²
- LibreLane extracted max-SS setup WNS **-8.27 ns** (same class as prior first-extract; ECO required)
- LibreLane IR without VSRC is pessimistic (~147/216 mV); VDD/VSS shapes connected

ODB of record for ECO: `45-odb-reportdisconnectedpins/butterfold_top.odb`

## Attempt 5 — extracted ECO + hold

Setup ECO (SS + max RCX, then GRT/DRT): setup path slack **+0.22 ns** then after hold-ECO re-STA **+1.62 ns MET**, TNS 0.
Hold ECO (FF + min RCX, 2 hold buffers): after reroute **+0.25 ns MET**, TNS 0.
DRT 0 both ECO routes. Antenna 0/0 after 21 diodes + 3 jumpers (final count 34).
Slew/cap/fanout/reset violator files empty on SDC-only STA.

## Attempt 6 — Magic GDS, density, fill, DRC, LVS

Magic streamout of ECO DEF: SHA `2610bd72…`. Density DCF.1b 24.74% (COMP min) and M1.4 29.15% failed because ECO ODB had no stdcell fillers.
Native `filler_placement` (25696 fillers) + restream: SHA `cd6a1dfc51892b1b0b4a3ff3fa3ff28454a6f4bcbb41619f5ddb0cb1e85af9e3`.
Density after fill: DCF.1d **34.40% PASS**; DCF.1b/PL.8/M1.4 PASS; M2–MT integrator fill pending.
MSLOT unified: **0 items**.
Full KLayout main+antenna: antenna 0 items; **6 × CO.6a** (M1 EOL overlap on contact).
Full Magic-GDS Netgen LVS: stdcells uniquely match, SRAM 2; **top does not uniquely match** (antenna 10 vs 30, VDD/VSS pin equate).

Canonical `gds/butterfold_top.gds` not overwritten.

## Attempt 7 — CO.6a diagnosis and native repair

Six CO.6a markers were all MX `gf180mcu_fd_sc_mcu9t5v0__aoi221_2` Metal1
contact EOL (5 nm short of 0.06 µm). Foundry cell GDS is identical; isolated
cell DRC = 0; flattened MX instance DRC = 1; `aoi221_1` MX = 0.

Instances `_09888_ _10690_ _13682_ _13744_ _15985_ _17407_` swapped to
`aoi221_1` via OpenROAD `swapMaster` on `hold_eco/routed.def` (ECO ODBs are
PATH 26Q2 schema 0.129; DEF import is the schema-safe path). Localized DRT
cleanup: **0 violations**. Antenna 0/0, 35 diodes. Fillers 25705. Magic
restream SHA `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12`.

Official KLayout main-deck: **clean, 0 items, CO.6a = 0**.

## Attempt 8 — LVS unique match + distributed IR + promotion

Antenna 35→31 both sides once the filled source netlist had
`global_connect` (filler/antenna VDD/VSS were `_noconnect_*` after fill
`write_verilog`). Devices 12770 / nets 12761 uniquely match. SRAM 2.

IR: VDD/VSS grids connected. Distributed Metal4/5 VSRC: VDD 7.42 mV, VSS
7.39 mV. North-edge physical terminals unchanged.

Setup +1.62 ns MET, hold +0.25 ns MET. Density DCF.1d 34.39% PASS. MSLOT 0.

Promoted byte-identical GDS to `gds/butterfold_top.gds` (SHA `6d66a476…`).

## Attempt 7 — CO.6a diagnosis (6 MX aoi221_2)

Authoritative KLayout main-deck on Magic GDS SHA `cd6a1dfc…`: 6 × CO.6a only.

All six markers are the same class: MX-oriented `gf180mcu_fd_sc_mcu9t5v0__aoi221_2`
Metal1 contact EOL, 5 nm short of the 0.06 µm enclosure. Foundry cell GDS is
byte-identical to the streamed cell. Isolated cell DRC = 0; flattened MX
instance DRC = 1; R0 instances = 0. `aoi221_1` / `aoi221_4` MX = 0.

Instances: `_13682_ _17407_ _13744_ _09888_ _15985_ _10690_`.

Native repair: swap those six masters to `aoi221_1` via openroad-librelane
reading `hold_eco/routed.def` (ECO ODBs are PATH 26Q2 schema 0.129; DEF import
is schema-safe). Then localized rip/reroute, filler_placement, Magic restream.

Evidence: `physical/reports/signoff/evidence/drc/co6a_before_markers.rpt`
and `co6a_before_6markers.lyrdb`.
