# ButterFold first LVS report

## 1. Verdict

The first reproducible, PDK-deck LVS run completed, but **LVS FAILS**.  This is
not a tool-launch failure and it is not waived.  The installed GF180 KLayout
deck extracted the candidate GDS and produced a 70 MiB comparison database.
It reported `ERROR : Netlists don't match`.  A deliberately broken clock-net
reference also failed, as required.

The immediate blockers are:

- the GDS-derived top has 11 extracted terminals while the physical reference
  has 21 signal terminals;
- standard-cell extracted subcircuits contain an additional extracted
  substrate terminal and do not compare to their PDK SPICE reference forms;
- the extracted I/O cells expose reduced/different terminal sets (for example,
  `bi_t` extracts six terminals versus fifteen in the PDK SPICE view);
- the SRAM and all compared foundry leaf families consequently fail hierarchy
  comparison, preventing a meaningful top-level connectivity match.

No RTL, ODB, DEF, GDS geometry, constraints, placement, routing, SRAM
architecture, or pad configuration was changed.

## 2. GDS provenance

- GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- SHA-256: `f4601ed31b30a58fb2b5c8aface9db1b62759e842c79f3d53788de2ec21c5da1`
- Expected hash: identical (**PASS**)
- Top: `butterfold_padframe_top`
- Size: 33,440,022 bytes
- Timestamp: 2026-08-10 18:37:21 +0200
- Routed ODB provenance: `physical/results/padframe/route/route.odb`
- Routed DEF provenance: `physical/results/padframe/route/route.def`

The candidate stream-out inventory previously reopened and verified two
`gf180mcu_fd_ip_sram__sram256x8m8wm1` references, zero 512x8 SRAM references,
and the current padframe.  The post-route physical netlist independently has
exactly two 256x8 SRAM instances and no 512x8 instance.  It contains 11
`in_c`, 10 `bi_t`, one `dvdd`, one `dvss`, and eight `cor` instances (four
named placement-corner instances plus four wrapper corner instances).  See
`reports/current/CANDIDATE_GDS_STREAMOUT_REPORT.md` and
`physical/results/padframe/route/butterfold_padframe_physical.v`.

## 3. Reference-netlist provenance

- Authoritative source:
  `physical/results/padframe/route/butterfold_padframe_physical.v`
- Source SHA-256:
  `d7d8c8bea1aac58dfb0b266e1282577dbc5d8c51f7f4ae96ccd5cf69f410254b`
- Generated reference:
  `physical/results/padframe/lvs/reference_physical.cdl`
- Raw generated reference:
  `physical/results/padframe/lvs/reference_physical_raw.cdl`

`physical/lvs_reference.tcl` reads the post-route physical Verilog, links it
against the exact production LEFs, and asks OpenROAD to write CDL with the PDK
master views.  `physical/prepare_lvs_reference.py` then performs two mechanical
operations: it assigns anonymous physical power/well terminals according to
the same VDD/VNW/DVDD and VSS/VPW/DVSS global-connect policy used by P&R, and
it includes only PDK subcircuits reachable from instantiated cells.  It does
not alter signal connectivity.  This normalization was necessary because the
physical Verilog omits implicit power/well pins.

The physical reference preserves CTS cells, the clock root, isolation and
timing-repair cells, pads, SRAMs, standard cells, fillers/taps where represented,
and the post-route signal connectivity.  It is not derived from pre-P&R RTL.

## 4. PDK and installed tools

- PDK: `gf180mcuD`
- PDK root: `/foss/pdks/gf180mcuD`
- Installed PDK version link:
  `ciel/gf180mcu/versions/7b70722e33c03fcb5dabcf4d479fb0822d9251c9/gf180mcuD`
- KLayout: `/foss/tools/klayout/klayout`, version 0.30.8
- Magic: `/foss/tools/bin/magic`, version 8.3.636
- Netgen: `/foss/tools/bin/netgen`, version 1.5.318

Installed LVS collateral:

- KLayout deck:
  `/foss/pdks/gf180mcuD/libs.tech/klayout/tech/lvs/gf180mcu.lvs`
- KLayout runner:
  `/foss/pdks/gf180mcuD/libs.tech/klayout/tech/lvs/run_lvs.py`
- Magic setup:
  `/foss/pdks/gf180mcuD/libs.tech/magic/gf180mcuD.magicrc`
- Netgen setup:
  `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl`

KLayout was selected because the PDK provides a complete installed extraction
and comparison deck, satisfying the preferred methodology.  The run used
variant C (5LM, 9K top metal), deep extraction, top-level pin comparison,
device combination, and purge.  No custom extraction deck was invented.

## 5. Library circuit views and handling

| Family | Authoritative circuit view | Handling | Result |
|---|---|---|---|
| `gf180mcu_fd_sc_mcu9t5v0` | `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice` | Fully extracted and compared at device/hierarchical level | FAIL |
| `gf180mcu_fd_io` | `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/spice/gf180mcu_fd_io.spice` | Fully extracted; actual `in_c`, `bi_t`, `dvdd`, `dvss`, and `cor` definitions included | FAIL |
| `gf180mcu_fd_ip_sram__sram256x8m8wm1` | `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/spice/gf180mcu_fd_ip_sram__sram256x8m8wm1.spice` | Full SRAM GDS extraction and full hierarchical SPICE reference; not arbitrarily black-boxed | FAIL |

The PDK supplies full GDS and transistor-level SPICE for the SRAM and I/O
cells, and the installed KLayout deck has SRAM marker/device support.  The
initial method therefore attempted full extraction rather than inventing a
black-box policy.  The result demonstrates that additional PDK-supported
hierarchy/terminal normalization is required before these macro comparisons
can succeed.  SRAM top-level connectivity is therefore **not yet verified by
LVS**, despite the correct two-instance inventory.

## 6. Reproducible command

Run:

```bash
make -C physical lvs
```

The target verifies the fixed GDS hash, derives the reference from the
authoritative post-route physical Verilog, runs the installed PDK KLayout LVS
deck, runs a known-bad negative control, and stores output under
`physical/results/padframe/lvs/`.  A real LVS mismatch makes the target return
nonzero.  The temporary modified reference is deleted after comparison; its
log and LVS database remain as evidence.

Important outputs:

- Layout extraction: `physical/results/padframe/lvs/good/butterfold_padframe_candidate.cir`
- Comparison database: `physical/results/padframe/lvs/good/butterfold_padframe_candidate.lvsdb`
- Run log: `physical/results/padframe/lvs/lvs_good_console.log`
- Negative-control log: `physical/results/padframe/lvs/lvs_negative_console.log`
- Machine summary: `physical/results/padframe/lvs/summary.txt`
- GDS hash record: `physical/results/padframe/lvs/gds.sha256`

These generated results are under the existing ignored physical-results tree;
the scripts, Makefile target, current-run metadata, and this report are source
collateral.

## 7. Top-level pin comparison

Reference top terminals (21):

`pad_clk`, `pad_din[7:0]`, `pad_din_ready_o`, `pad_din_valid_i`,
`pad_dout[7:0]`, `pad_dout_valid_o`, `pad_rst_n`.

GDS-extracted top terminals (11):

`pad_din_valid_i`, `pad_din[7:0]`, `pad_din_ready_o`, and extracted substrate
`SUB`.

Thus `pad_clk`, all eight `pad_dout` pins, `pad_dout_valid_o`, and `pad_rst_n`
are absent as equivalent top-level extracted pins, while `SUB` is extra.  This
is direct evidence that the candidate stream-out is not yet an LVS-clean
padframe deliverable.

## 8. Comparison result

KLayout's comparison database reports:

- matched top cells: **NO**;
- unmatched-net diagnostic messages: **183**;
- unmatched-pin diagnostic messages: **37**;
- unmatched-device messages enumerated after hierarchy comparison: **0**, but
  this is not a device PASS—the top comparison was blocked because the listed
  standard-cell, I/O, and SRAM subcircuits failed to compare;
- property mismatch messages: **0**;
- black-boxed cells: **NONE intentionally**;
- failed leaf families: standard cells, `bi_t`, `in_c`, `dvdd`, `cor`, and
  `gf180mcu_fd_ip_sram__sram256x8m8wm1` (the extracted hierarchy also exposes
  `dvss` with no matching reference-side peer at the same comparison level).

Representative terminal mismatch:

- extracted `gf180mcu_fd_sc_mcu9t5v0__and2_4`:
  `VDD A2 A1 Z VSS SUB`;
- PDK reference `gf180mcu_fd_sc_mcu9t5v0__and2_4`:
  `A1 A2 Z VDD VNW VPW VSS`;
- extracted `gf180mcu_fd_io__bi_t`: `A VDD DVSS DVDD PAD VSS`;
- PDK reference `gf180mcu_fd_io__bi_t`:
  `A CS DVDD DVSS IE OE PAD PD PDRV0 PDRV1 PU SL VDD VSS Y`.

These are evidence of unresolved extraction/hierarchy/pin-model alignment,
not permission to edit physical connectivity or waive mismatches.

## 9. Negative control

The flow made a temporary copy of the normalized reference and disconnected
the `Xu_clk_iso` input from `clk_iso`.  KLayout reported `Netlists don't
match`.  The temporary bad reference was discarded; the log and failed
comparison database were retained.

**KNOWN-BAD REFERENCE: FAIL AS EXPECTED.**

This proves that the comparison does not report a vacuous success.  It does
not compensate for the real candidate's failure.

## 10. Final LVS verdict

```text
AUTHORITATIVE GDS HASH:                      VERIFIED
REFERENCE POST-ROUTE CONNECTIVITY:           VERIFIED SOURCE
STANDARD CELLS:                              FAIL
2 x 256x8 SRAM INVENTORY:                    VERIFIED
2 x 256x8 SRAM LVS CONNECTIVITY:             FAIL / NOT ESTABLISHED
512x8 SRAM:                                  ABSENT
I/O PADS:                                    FAIL
UNMATCHED NET DIAGNOSTICS:                   183
UNMATCHED DEVICE DIAGNOSTICS:                NOT MEANINGFULLY ENUMERATED
UNMATCHED PIN DIAGNOSTICS:                   37
NEGATIVE CONTROL:                            FAIL AS EXPECTED
LVS:                                         FAIL
READY FOR FULL GDS DRC/LVS:                  NO
```

The candidate GDS remains a candidate; output-pad electrical/load closure is
still unresolved.  Full GF180 GDS DRC was **not run** in this task.

## LVS FAILURE ROOT-CAUSE AND REPAIR

The follow-up pin-provenance audit refuted the assumption that the 11 extracted
terminals were all 11 inputs.  They are nine logical inputs, one output
(`pad_din_ready_o`), and substrate `SUB`.  Both DEFs and the GDS contain all 21
correct label strings.  The first divergence is physical connectivity in the
authoritative routed database: all external nets have BTerms and pad `PAD`
ITerms but no routed wires.  West-edge pin rectangles overlap pad metal and are
recognized; east/north rectangles do not overlap pad metal and are isolated.

No stream-out-only metal or detached label was added because that would hide a
real pad-escape disconnection.  The GDS hash is unchanged, top checkpoint A is
10/21 logical terminals, and LVS remains FAIL.  The standard-cell, I/O, SRAM,
power/substrate, DEF, GDS-label, and bus-name evidence is documented in
`reports/current/BUTTERFOLD_LVS_DIAGNOSTIC_REPORT.md`.
