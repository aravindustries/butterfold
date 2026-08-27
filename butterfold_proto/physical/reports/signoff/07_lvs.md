# 07 — LVS

## Full device-level Netgen LVS (team signoff)

**PASS** — `Final result: Circuits match uniquely.`

This is the team-side LVS of record for the North/West GDS.

| Side | Methodology |
|---|---|
| Layout | Magic 8.3.636 native GDS extraction, `MAGIC_EXT_USE_GDS=1`, `MAGTYPE=mag` |
| GDS | SHA `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` (not LEF abstracts) |
| SRAM | official hard-macro blackbox: `MAGIC_EXT_ABSTRACT_CELLS` + SRAM LEFview; count **2** |
| Source | filled powered netlist `butterfold_top.filled.pnl.v` + official `CELL_SPICE_MODELS` |
| SRAM source | transistor SRAM spice **not** read (pin-accurate black box) |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen 1.5.318 `-blackbox -json` |

| Item | Value |
|---|---|
| Layout GDS SHA | `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12` |
| Extracted SPICE SHA | `c639454969fc4dc445e717157f063d197e2dc628c6e6105a2b6c4dafa5a07336` |
| Source netlist SHA | `32224ebbd39de4f8d80b47acec102115fa883bbc4bbd7633adc758e23d9a4cdb` |
| Devices | 12770 vs 12770 |
| Nets | 12761 vs 12761 |
| SRAM | 2 |
| Antenna | 35 instances → 31 equivalent **both** sides (PDK `property parallel`) |
| Top ports | `VDD` `VSS` and all 21 signal ports equated |

Stdcell classes uniquely matched, including `aoi221_1` (157) and remaining
R0 `aoi221_2` (4). Fill/`filltie`/`endcap` are device-less; the PDK setup
ignores those classes. `fillcap_*` contain MOSFETs and compared.

Magic extract feedback: 503 `nmos`/`ndiff` illegal-overlap notes and 3
warnings — same class as the previous unique-match run. They did not produce
LVS bad nets/devices.

Antenna cell-class “disconnected node: VDD/VSS” notes during hierarchical
compare are the same harmless PDK-extract notes as the previous unique-match
run; top-level uniquely matched.

## LVS issues closed on this GDS

1. **Antenna reduction** — physical diodes were never removed. With a
   power-connected filled source netlist matching this GDS, Netgen reports
   **35→31 on both sides**.
2. **VDD/VSS top-port equate** — Mag extract already had `VDD`/`VSS` ports.
   The mismatch was source `_noconnect_*` on filler/antenna power pins
   because `global_connect` was not run before `write_verilog`. After
   `add_global_connection` + rewrite of the source netlist (GDS unchanged),
   ports equate.

## Evidence

| Item | Path |
|---|---|
| Full Netgen LVS summary | [evidence/lvs/full_netgen_lvs_summary.rpt](evidence/lvs/full_netgen_lvs_summary.rpt) |
| Full Netgen native report | [evidence/lvs/full_netgen_lvs.rpt](evidence/lvs/full_netgen_lvs.rpt) |
| Full Netgen log | [evidence/lvs/full_netgen_lvs.log](evidence/lvs/full_netgen_lvs.log) |
| Full Netgen JSON | [evidence/lvs/full_netgen_lvs.json](evidence/lvs/full_netgen_lvs.json) |
| Full LVS script | [evidence/lvs/full_lvs_script.lvs](evidence/lvs/full_lvs_script.lvs) |

Search the full report for `Final result: Circuits match uniquely.`
