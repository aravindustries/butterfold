# ButterFold hierarchical LVS milestone

## Result

**PASS.** The current candidate GDS and current post-route physical netlist
match uniquely at the foundry-leaf hierarchy. A deliberately disconnected
clock-isolation input fails comparison, proving the check is not vacuous.

## Provenance

- Top: `butterfold_padframe_top`
- GDS: `physical/results/padframe/gds/butterfold_padframe_candidate.gds`
- SHA-256: `a7820a96542f2b443ea2f5e44cf227d777583f751d031f629d542aea3fde8f4d`
- Reference source: `physical/results/padframe/route/butterfold_padframe_physical.v`
- Generated reference: `physical/results/padframe/lvs/reference.spice`
- Layout extraction: Magic 8.3 from the actual candidate GDS
- Comparison: Netgen 1.5.318
- GF180 setup: `/foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl`
- Reproduction: `make -C physical lvs`

The ODB, DEF, physical Verilog, and GDS have matching top, timestamp/run
provenance, 21 logical signal boundaries, two 256x8 SRAMs, no 512x8 SRAM, and
the current padframe hierarchy. The current hash supersedes the stale
`beedd231...` intermediate candidate; no artifact was restored from Git.

## Comparison scope

GF180 standard cells, I/O pads, and both SRAM macros are treated as verified
leaf cells. LVS verifies each leaf type, formal pin interface, instance count,
and routed boundary connectivity. It does not extract or compare their internal
transistors. The ButterFold top is not black-boxed; its GDS interconnect is
extracted by Magic using PDK LEF pin-access geometry.

The current padframe is a single-supply implementation. The modeled hierarchy
normalizes `VDD`, `DVDD`, and `VNW` to the power network and `VSS`, `DVSS`, and
`VPW` to ground on both comparison sides. This is an explicit leaf-boundary
supply model, not a waiver of signal connectivity.

## Metrics

- Top signal terminals: **21 / 21 MATCH**
- Modeled leaf instances: **13,788** (11,702 electrically visible to Netgen;
  remaining zero-pin physical-only filler/endcap leaves carry no compared net)
- Standard-cell leaf connectivity: **PASS**
- I/O-pad leaf connectivity: **PASS**
- SRAM256x8 macro instances: **2 / 2 MATCH**
- SRAM512x8 macro instances: **0**
- Layout/reference nets: **11,733 / 11,733**
- Unexplained unmatched nets: **0**
- Unexplained unmatched instances: **0**
- Negative control: **FAIL AS EXPECTED** (one `u_clk_iso` input disconnected)
- Netgen result: **Circuits match uniquely.**

Full transistor LVS and full GF180 GDS signoff DRC were not run. The GDS stays
classified as a candidate because the 5-pF output-pad slew issue remains open.
Production RTL, routed ODB/DEF, and candidate GDS were not modified by LVS.
