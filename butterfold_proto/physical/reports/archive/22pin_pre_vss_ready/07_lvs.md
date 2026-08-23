# 07 — LVS

## Full device-level Netgen LVS (team signoff)

**PASS** — `Final result: Circuits match uniquely.`

This is the team-side LVS of record.

| Side | Methodology |
|---|---|
| Layout | Magic 8.3.636 native GDS extraction, `MAGIC_EXT_USE_GDS=1`, `MAGTYPE=mag` |
| GDS | pre-fill team GDS SHA `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |
| Stdcells | extracted to real `nfet_05v0` / `pfet_05v0` (not LEF abstracts) |
| SRAM | official hard-macro blackbox: `MAGIC_EXT_ABSTRACT_CELLS` + SRAM LEFview; count **2** |
| Source | ECO powered netlist `butterfold_top.final.pnl.v` + official `CELL_SPICE_MODELS` |
| SRAM source | transistor SRAM spice **not** read (pin-accurate black box) |
| Setup | official `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl` |
| Compare | Netgen 1.5.318 `-blackbox -json` (`-blackbox` applies to empty SRAM/fill only) |

Proof this is not pin-only LVS:

| Cell | Layout devices | Source devices | Result |
|---|---|---|---|
| `...__and2_1` | 3×`pfet_05v0` + 3×`nfet_05v0` | same | uniquely matched |
| `...__inv_1` | 1+1 MOSFET | same | uniquely matched |
| `...__nand2_1` | 2+2 MOSFET | same | uniquely matched |
| `...__dffrnq_1` | 14+14 MOSFET | same | uniquely matched |
| `...__antenna` | 2 diodes | same | uniquely matched |
| SRAM `sram256x8m8wm1` | 0 devices (abstract) | 0 devices (blackbox) | 2 instances |

Top: 11629 devices / 11638 nets each side. `badnets=[]` `badelements=[]`. Pins including `VDD`/`VSS` equivalent.

Antenna: GDS/OpenROAD inventory is **14** instances. After official `gf180mcuD_setup.tcl` `property parallel` on the antenna class, Netgen reports **13** equivalent devices on **both** sides (two diodes share one `I` net and merge). Not a missing diode.

Fill/`filltie`/`endcap` are device-less; the PDK setup ignores those classes. `fillcap_*` contain MOSFETs and compared.

Magic extract feedback: 503 `nmos`/`ndiff` illegal-overlap notes (GF180 device-recognition) and 3 pale “device missing 1 terminal” notes. They did not produce LVS bad nets/devices.

Dummy-filled GDS `e02fb870…` was not used.

## Existing DEF/LEF Netgen (not full LVS)

The earlier uniquely-matched Netgen run (`MAGIC_EXT_USE_GDS=0`, LEF abstracts, `lvs -blackbox`) remains **hierarchical pin-equivalence LVS**. Layout spice had **0 MOSFET primitives**. It is preserved as evidence and is **not** the team full-LVS result.

## KLayout GDS vs OpenROAD CDL

**FAIL** — `ERROR : Netlists don't match` (unchanged). Layout MOSFETs vs OpenROAD CDL zero-device stubs. This is **not** the team LVS of record. Native pair dump is preserved.

## Evidence

| Item | Path |
|---|---|
| Methodology audit of the old pin-LVS | [evidence/lvs/existing_netgen_methodology_audit.rpt](evidence/lvs/existing_netgen_methodology_audit.rpt) |
| Official stdcell source preflight | [evidence/lvs/source_model_preflight.rpt](evidence/lvs/source_model_preflight.rpt) |
| Magic GDS device-extract preflight | [evidence/lvs/layout_device_extraction_preflight.rpt](evidence/lvs/layout_device_extraction_preflight.rpt) |
| Preflight `and2_1` spice (6 MOSFETs) | [evidence/lvs/gf180mcu_fd_sc_mcu9t5v0__and2_1.spice](evidence/lvs/gf180mcu_fd_sc_mcu9t5v0__and2_1.spice) |
| Cell-level `and2_1` vs CELL_SPICE_MODELS | [evidence/lvs/and2_vs_spice.rpt](evidence/lvs/and2_vs_spice.rpt) |
| SRAM / diode / filler treatment | [evidence/lvs/sram_diode_filler_treatment.rpt](evidence/lvs/sram_diode_filler_treatment.rpt) |
| Full Netgen LVS summary | [evidence/lvs/full_netgen_lvs_summary.rpt](evidence/lvs/full_netgen_lvs_summary.rpt) |
| Full Netgen native report | [evidence/lvs/full_netgen_lvs.rpt](evidence/lvs/full_netgen_lvs.rpt) |
| Full Netgen log | [evidence/lvs/full_netgen_lvs.log](evidence/lvs/full_netgen_lvs.log) |
| Full Netgen JSON | [evidence/lvs/full_netgen_lvs.json](evidence/lvs/full_netgen_lvs.json) |
| Full LVS script | [evidence/lvs/full_lvs_script.lvs](evidence/lvs/full_lvs_script.lvs) |
| Prior pin-level Netgen (not full LVS) | [evidence/lvs/netgen_lvs_summary.rpt](evidence/lvs/netgen_lvs_summary.rpt) |
| KLayout pair dump | [evidence/lvs/klayout_lvs_circuit_pairs.rpt](evidence/lvs/klayout_lvs_circuit_pairs.rpt) |

Search the full report for `Final result: Circuits match uniquely.` and `pfet_05v0 (3)`.
