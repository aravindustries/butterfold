# 07 — LVS

## Netgen (LibreLane digital LVS)

**PASS** — `Circuits match uniquely.` 11629 devices, 11638 nets, 2 SRAM,
pins including VDD/VSS equivalent.

## KLayout GDS vs CDL

**FAIL** — `ERROR : Netlists don't match`. Top-level was **not compared**:
layout subcircuits keep lowercase GDS names; the SPICE reader upcases the
CDL. `run_lvs.py` has no downcase switch. This is name-case integration, not
a scored open/short list.

Not re-run after dummy fill (density already hard-stops tapeout; KLayout LVS
is ~6.5 h). Existing log is the comparison that ran on the pre-dummy GDS.

## Evidence

| Item | Path |
|---|---|
| Native Netgen LVS report | [evidence/lvs/netgen_lvs_summary.rpt](evidence/lvs/netgen_lvs_summary.rpt) |
| Native Netgen log | [evidence/lvs/netgen_lvs.log](evidence/lvs/netgen_lvs.log) |
| KLayout LVS log | [evidence/lvs/klayout_lvs.log](evidence/lvs/klayout_lvs.log) |

Search the Netgen report for `Final result: Circuits match uniquely.`
Search the KLayout log for `ERROR : Netlists don't match`.

- Netgen 1.5.318; Magic extract from filled DEF; schematic `butterfold_top.final.pnl.v` SHA `fd1abecb…`
- KLayout 0.30.8 `run_lvs.py` variant D; layout GDS SHA `5a99213a…`; CDL SHA `415ad8aa…`
