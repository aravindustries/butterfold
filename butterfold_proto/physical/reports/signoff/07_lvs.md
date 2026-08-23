# 07 — LVS

## Netgen (LibreLane digital LVS)

**PASS** — `Circuits match uniquely.` 11629 devices, 11638 nets, 2 SRAM,
pins including VDD/VSS equivalent.

This is the digital stdcell-level LVS for the ECO topology.

## KLayout GDS vs CDL

**FAIL** — `ERROR : Netlists don't match`.

Native `lvsdb` shows the SPICE reader **did** pair names case-insensitively:

| Layout (GDS extract) | Schematic (CDL after SPICE upcase) | Pair status |
|---|---|---|
| `butterfold_top` | `BUTTERFOLD_TOP` | **Skipped** |
| `gf180mcu_fd_sc_mcu9t5v0__*` (logic) | `GF180MCU_FD_SC_MCU9T5V0__*` | **NoMatch** (108 circuits) |
| empty fill/antenna/endcap | same, upcased | **Match** (5 circuits) |

114 / 114 circuits overlap case-insensitively. Exact-case overlap is 0.
**Top-level was paired**, then **Skipped** because child standard cells are
NoMatch.

Root cause of NoMatch (native device counts):

- Layout extract of `and2_1`: **6 MOSFETs**
- OpenROAD CDL `AND2_1`: **0 devices** (instance-only stub)
- SRAM extract: **18305 devices** vs schematic stub **0 devices**

The GF180 KLayout deck extracts transistors from GDS. The OpenROAD CDL does
not include the foundry stdcell/SRAM MOSFET CDL. Later open_pdks `gf180mcu.lvs`
is the same compare (`align` then `compare`); it does not add case folding or
stdcell black-boxing. Concatenating PDK `*.cdl` would still see extra extracted
well/substrate pins (e.g. layout `and2_1` 9 pins vs CDL 7).

This is **not** a scored open/short list of the top netlist. Digital connectivity
signoff remains **Netgen**.

Not re-run after dummy fill (fill is not the team GDS). Existing log/lvsdb are
the comparison on the pre-dummy GDS SHA `5a99213a…`.

## Evidence

| Item | Path |
|---|---|
| Native Netgen LVS report | [evidence/lvs/netgen_lvs_summary.rpt](evidence/lvs/netgen_lvs_summary.rpt) |
| Native Netgen log | [evidence/lvs/netgen_lvs.log](evidence/lvs/netgen_lvs.log) |
| KLayout LVS log | [evidence/lvs/klayout_lvs.log](evidence/lvs/klayout_lvs.log) |
| Native lvsdb circuit-pair dump | [evidence/lvs/klayout_lvs_circuit_pairs.rpt](evidence/lvs/klayout_lvs_circuit_pairs.rpt) |

Search Netgen for `Final result: Circuits match uniquely.`
Search KLayout log for `ERROR : Netlists don't match`.
Search the pair dump for `Skipped butterfold_top` and `Pair status counts`.

- Netgen 1.5.318; Magic extract from filled DEF; schematic `butterfold_top.final.pnl.v`
- KLayout 0.30.8 `run_lvs.py` variant D; layout GDS SHA `5a99213a…`; CDL SHA `415ad8aa…`
