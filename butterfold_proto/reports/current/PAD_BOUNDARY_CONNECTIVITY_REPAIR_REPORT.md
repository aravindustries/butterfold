# ButterFold pad-boundary connectivity repair

## 1. Root cause

The pad-placement flow placed 21 die-edge BTerms independently with
`place_pins`, then marked every external signal net special. Global and
detailed signal routing therefore skipped those nets. The selected GF180 pad
masters expose `PAD` as `Metal5 RECT 25 20 50 45` in both `in_c` and `bi_t`.
The west BTerms happened to overlap hierarchical bond-pad metal; east and north
BTerms did not. Net names and labels were complete, but eleven physical
boundaries were open.

An experiment clearing the special flag proved that ordinary TritonRoute is
not the right pad escape mechanism: it reported `DRT-0073 No access point` for
the pad `PAD` ports. The retained method gives the BTerm intentional ownership
of the I/O cell's transformed Metal5 PAD conductor, then keeps the external net
special. This is encoded in ODB/DEF before stream-out and does not add detached
GDS geometry.

## 2. Pre-repair connectivity

| Signals | Side | Count | BTerm / PAD ITerm | dbWire | Direct overlap | Extracted |
|---|---|---:|---|---|---|---|
| `pad_din_valid_i`, `pad_din[7:0]`, `pad_din_ready_o` | west | 10 | present / present | none | accidental | yes |
| `pad_clk`, `pad_rst_n` | north | 2 | present / present | none | no | no |
| `pad_dout[7:0]`, `pad_dout_valid_o` | east | 9 | present / present | none | no | no |

All 21 individual entries are preserved in the baseline matrix at
`physical/results/padframe/lvs/baseline_11_vs_21/` and in the superseded LVS
diagnostic report. Authoritative pre-repair connected logical pins: **10/21**.

## 3. Count discrepancy

The original KLayout report's “11 terminals” counted ten ButterFold logical
terminals plus global substrate terminal `SUB`. The later “10/21” count
excluded `SUB` and counted only logical signals. It was not a post-repair
result and no terminal was lost between the two diagnostics.

## 4. Physical repair method

`physical/padframe_connect_signal_pads.tcl` maps each logical BTerm to its
actual pad instance, reads the placed `PAD` ITerm bounding box, destroys the
independent die-edge BPin, and creates a firm Metal5 BPin on that exact
rectangle. The script errors on missing BTerms, instances, PAD ITerms, layers,
geometry, or nets. It is sourced by both the full flow and route-resume flow.

The authoritative route was rebuilt from the existing CTS ODB. The signal
router retained the external nets as special (their conductor is already the
PAD port), routed the core, and converged to zero violations. No production RTL
or functional netlist connectivity changed.

## 5. Post-repair ODB connectivity

`physical/lvs_diagnostic.tcl` compares every BPin layer/rectangle against the
corresponding placed PAD ITerm. It reports `BOUNDARY_CONNECTED=21/21`.
All BTerms and PAD ITerms are on the same logical net, and every BPin rectangle
equals its transformed Metal5 PAD rectangle. `dbWire` is intentionally absent
on these special boundary nets because the terminal is the PAD conductor, not
a separately routed core pin.

## 6. Post-repair extracted connectivity

`make -C physical lvs-diagnostic` reopens the regenerated GDS and checks each
top label against hierarchical conductive pad geometry. Every signal has a DEF
pin, stream-out DEF pin, GDS label, top conductor, and hierarchical conductor:

```text
LAYOUT_TOP_SIGNAL_TERMINALS=21
REFERENCE_TOP_SIGNAL_TERMINALS=21
```

This is the required boundary-connectivity checkpoint, not a claim that the
remaining device/leaf full-LVS comparison passes.

## 7. DRC

OpenROAD detailed routing completed with `Number of violations = 0` in
`physical/results/padframe/route/pad_boundary_full_route.log`.
`physical/results/padframe/route/detailed_route_drc.rpt` is zero bytes because
the tool emits an empty report for a clean run. **Routing DRC: PASS (0).** This
is not full foundry GDS DRC.

## 8. Fresh extracted STA

All three SPEFs were regenerated from the repaired routed ODB. Values below are
the first slack in the corresponding current reports (ns).

| Corner / RC | Overall setup | Overall hold | Internal setup | Internal hold | SRAM setup | SRAM hold | Input setup | Input hold |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SS 125C 4.50 V / max | +0.05 | +0.72 | +0.10 | +0.75 | +1.01 | +0.75 | +1.47 | +0.72 |
| TT 25C 5.00 V / nom | +7.44 | +0.28 | +7.44 | +0.32 | +7.85 | +0.32 | +9.99 | +0.28 |
| FF -40C 5.50 V / min | +10.68 | +0.09 | +10.68 | +0.14 | +10.85 | +0.14 | +13.65 | +0.09 |

Thus 61.44-MHz setup, internal hold, SRAM setup/hold, and candidate input
setup/hold pass. The separate 5-pF output-pad transition blocker remains:
worst SS pad slew is 4.61 ns against the 1.0-ns Liberty limit. It was not
changed in this task.

## 9. New candidate GDS

- Path: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- Timestamp: 2026-08-11 22:20:15 +0200
- Size: 33,440,022 bytes
- Old SHA-256: `f4601ed31b30a58fb2b5c8aface9db1b62759e842c79f3d53788de2ec21c5da1`
- New SHA-256: `beedd2310bbe56e0ff14a1391c59bec4da8625eb234b285dc4a46fff0ec8424c`
- Reopen/parse: PASS
- Boundary signal connectivity: 21/21
- SRAMs: 2 x 256x8; no 512x8

## 10. Remaining LVS issues

Full LVS is **not expected to pass yet**. Standard-cell, `in_c`/`bi_t` I/O,
and SRAM leaf-model terminal/hierarchy alignment from the original diagnostic
remain unresolved. No mismatches were waived and the top was not black-boxed.
The post-repair full GF180 device extraction was not used to claim a pass; this
task closes only boundary connectivity.

## 11. Power/ground status

**PROVISIONAL.** Standard-cell, SRAM, and pad supplies use common special/global
nets (`one_`/VDD/DVDD/VNW and `zero_`/VSS/DVSS/VPW), and `dvdd`/`dvss` pad
instances remain present. The KLayout deck extracts substrate `SUB`, while the
reference uses `zero_`; final supply/substrate LVS model alignment remains an
open leaf/power verification task. No ground signal pin was invented.

## Integrity

Production RTL, arithmetic, SRAM architecture, command protocol, logical
interface, placement, CTS, and core architecture are unchanged. Only physical
top-terminal geometry, rerouted generated artifacts, fresh parasitics/reports,
stream-out collateral, and diagnostics were changed.
