# Two-SRAM physical timing report

## 1. Flow architecture

`physical/` is a new production physical flow for the authoritative mapped
two-SRAM netlist.  It performs synthesis handoff, snapped floorplanning,
three macro-placement experiments, I/O placement, 20-um macro row halos,
tap/endcap insertion, PDN generation and connectivity checking,
timing/routability-driven global placement, placement repair, detailed
placement, CTS, setup/hold repair, global routing, detailed routing, OpenRCX
extraction, and setup/hold reporting.  The default retained arrangement is C.

Reproduction:

```sh
make -C physical floorplan ARRANGEMENT=C
make -C physical place ARRANGEMENT=C
make -C physical cts ARRANGEMENT=C
make -C physical route ARRANGEMENT=C
make -C physical timing ARRANGEMENT=C
```

Generated databases and reports are isolated under
`physical/results/<arrangement>/` and are git-ignored.

## 2. Technology setup

| View | Installed collateral |
|---|---|
| PDK | `/foss/pdks/gf180mcuD` |
| Technology LEF | `gf180mcu_fd_sc_mcu9t5v0__nom.tlef` |
| Standard-cell LEF | `gf180mcu_fd_sc_mcu9t5v0.lef` |
| Standard-cell Liberty | `gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib` |
| SRAM LEF | `gf180mcu_fd_ip_sram__sram256x8m8wm1.lef` |
| SRAM Liberty | `gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib` |
| Extraction model | `rules.openrcx.gf180mcuD.nom` |
| Corner | SS, 125 C, 4.50 V |
| Site | `GF018hv5v_green_sc9`, 0.56 x 5.04 um |
| Signal routing | Metal2--Metal5 |
| Clock routing | Metal3--Metal5; Metal4 estimated RC |

No generic library or abstract SRAM timing substitute was used.  The database
contains exactly two `sram256x8m8wm1` hard macros and no 512x8 macro.

## 3. Floorplan and PDN

The snapped core is 1117.20 x 1113.84 um, or 1,244,382.048 um2.  Each SRAM is
431.86 x 340.88 um.  Two 20-um halo rectangles occupy an effective
359,444.0 um2, leaving 884,938.0 um2 geometrically.  Row cutting and site
snapping leave 312,759 sites, or 882,731 um2 of legal standard-cell row area.

The retained arrangement C places the macros horizontally at the top of the
partition.  The low-byte macro is R0 at (20.0, 752.96) um.  The high-byte macro
is MY at (923.72, 752.96) um, putting the two inner signal-pin edges across a
40-um shared-logic channel.  A preliminary Metal1 follow-pin plus Metal4/5
stripe PDN connects the standard cells and both SRAMs.  OpenROAD power-grid
checks report both supply-domain nets fully connected.  Three isolated
Metal3/Metal4 candidate-via warnings were emitted on VSS, but alternative
connections kept the complete ground grid connected.

The mapped handoff names its constant supply nets `one_` and `zero_`; the
physical database uses these as the VDD/VSS domain aliases.  This naming is a
netlist-handoff detail, not an RTL or pin-interface change.

## 4. Macro-placement study

All values below are post-place with estimated placement parasitics and the
same 55% placement density.

| Arrangement | Geometry | Setup WNS (ns) | Setup TNS (ns) | Result |
|---|---|---:|---:|---|
| A | horizontal, both R0 | -2.05 | -654.58 | rejected |
| B | vertical, both R0 | -3.16 | -1020.46 | rejected |
| C | horizontal, facing-pin mirror | -1.91 | -677.47 | retained |

Arrangement C had the best WNS and preserves direct, symmetric access to the
parallel byte lanes.  Arrangement B caused both the worst timing and the
largest legalizer displacement.  The final detailed route had no pin-access
failure on either macro.

## 5. Timing by physical stage

| Stage | Setup WNS (ns) | Setup TNS (ns) | Hold WNS (ns) | Notes |
|---|---:|---:|---:|---|
| Synthesis | -0.53 | -15.27 | +0.72 | 176 setup endpoints |
| Post-place, C | -1.91 | -677.47 | +0.36 | ideal clock, placement RC |
| Post-CTS repair | -0.04 | -0.63 | +0.026 | 15 setup endpoints after repair |
| Global route, pre-opt | -0.50 | -40.09 | +0.07 | routed estimate |
| Global-route repair trial | -1.03 | -120.12 | positive | rejected remap; 324 endpoints |
| Detailed route + OpenRCX | **+0.20** | **0.00** | -0.65 overall | zero setup endpoints; hold caveat below |

The routed database is DRC-clean after four TritonRoute iterations.  OpenRCX
extracted 11,563 nets, 63,888 resistance segments, 63,888 ground capacitors,
and 137,164 coupling capacitors.  The route uses 950,713 um of wire and 89,236
vias.  The detailed-router DRC report is empty.

The -0.65-ns extracted hold result comprises eight **external `din` input**
paths under the deliberately baseline-matched 0.0-ns minimum input delay; its
hold TNS is -3.25 ns.  Internal register/SRAM hold WNS is +0.69 ns.  Thus the
core is internally hold-clean, but full-chip hold closure requires either a
frozen external minimum-delay contract of at least 0.65 ns or pad/input-path
hold repair when real pad timing is available.  No timing exception or
invented I/O delay was used to hide this distinction.

## 6. DFT12 physical path

The measured DFT12 family starts at `_19542_`, the physical register for
`dft12_phase[2]`, and ends at `_19199_`.  Source and endpoint are at
(428.96, 372.96) and (614.32, 141.12) um; endpoint Manhattan separation is
417.20 um.  The extracted path arrives at 17.59 ns against 18.10 ns required,
for **+0.51 ns slack**.  Excluding launch-clock insertion, its data-path time
is approximately 15.53 ns.

The full extracted report shows that nearly all incremental delay is cell and
logic delay: individual routed-net increments round to 0.00--0.01 ns, whereas
the long decode/mux gate chain contributes the remaining delay.  Consequently
the family is logic-dominated, although locality plus selective sizing and
buffering were sufficient to move it from -0.53 ns synthesis slack to +0.51
ns extracted slack.  Fanout on the reported phase source is small; no broad
DFT RTL retime is physically justified.

## 7. Multiplier physical path

The scalar family was measured from registered scalar coefficient/operand
cells; its worst sampled path is `_20287_` to `_20196_`.  Their coordinates
are (884.24, 715.68) and (1051.12, 685.44) um, a 197.12-um Manhattan
separation.  The extracted path arrives at 17.14 ns against 18.05 ns required,
for **+0.90 ns slack**; its data-path time after launch-clock insertion is
approximately 15.05 ns.

This path is also predominantly multiplier/gate delay, not wire delay.  CTS
and repair used sizing, pin swaps, a small number of buffers, and safe cloning;
no multiplier replication or RTL change was made.

## 8. Physical optimization history

| Step | Macro | Strategy | Std-cell area (um2) | Setup WNS/TNS (ns) | Hold WNS/TNS (ns) | DFT (ns) | Multiplier (ns) | SRAM worst (ns) | Congestion |
|---|---|---|---:|---|---|---:|---:|---:|---|
| 0 | n/a | synthesis | 436,616.813 | -0.53/-15.27 | +0.72/0 | -0.53 | -0.47 | +0.88 | n/a |
| 1 | A | timed placement | about 457,390 plus physical-only cells | -2.05/-654.58 | +0.36/0 | negative | negative | positive | zero global overflow |
| 2 | B | timed placement | comparable | -3.16/-1020.46 | positive | negative | negative | positive | routable |
| 3 | C | timed placement | 458,196.88 plus macros | -1.91/-677.47 | positive | negative | negative | positive | retained |
| 4 | C | CTS + setup/hold repair | 476,872.70 | -0.04/-0.63 | +0.026/0 | near zero | near zero | positive | routable |
| 5 | C | global RC, before repair | 476,872.70 | -0.50/-40.09 | +0.07/0 | negative | near zero | positive | guides complete |
| 6 | C | aggressive routed repair | 483,344.467 | -1.03/-120.12 | positive | remapped | remapped | positive | rejected estimate |
| 7 | C | detailed route + OpenRCX | 483,344.467 | **+0.20/0** | -0.65/-3.25 external; **+0.69 internal** | **+0.51** | **+0.90** | **+0.69 hold** | zero DRC |

The global-route repair estimator was pessimistic and produced a worse mapping;
the final extracted route nevertheless closes setup.  The flow retains all
stage databases so this unstable repair can be disabled or tuned in subsequent
signoff work rather than silently treated as a guaranteed improvement.

## 9. SRAM timing and lane skew

Extracted per-macro timing is symmetric at report resolution:

| Check | High-byte SRAM (ns) | Low-byte SRAM (ns) | Status |
|---|---:|---:|---|
| Address setup, worst | +1.82 | +1.82 | PASS |
| Write-data setup, worst | +1.81 | +1.81 | PASS |
| Control setup, worst | +2.78 | +2.78 | PASS |
| SRAM read-data capture | +4.54 | +4.54 | PASS |
| Internal/SRAM hold, worst | +0.69 | +0.69 | PASS |

The two SRAM clock branches are separately recognized by CTS and balanced with
no observable high/low-byte arrival mismatch at 0.01-ns report precision.
Corresponding address/control and data-lane margins are equal, so the parallel
16-bit logical port has no current lane-skew concern.  Final silicon signoff
still requires extracted foundry-corner STA.

## 10. Clock tree

CTS recognized two macro sinks and 2,002 register sinks.  It built a 3--4-level
register tree and a two-level macro branch.  The routed database contains 120
named clock buffers occupying 9,686.477 um2.  Representative insertion delay
is about 2.0 ns, extracted setup/hold skew is -0.09 ns, and reported leaf
transition is approximately 0.4--0.6 ns.  Timing repair resized 145 gates,
inserted 14 setup buffers, cloned 9 gates, swapped 63 pins, and inserted 7 hold
buffers at the accepted CTS stage.

## 11. Congestion and routability

Global placement reported no routing overflow in all retained trials.  The
final design completed macro pin access (1,120 generated macro access points,
336 valid via access points) with no pin lacking an access point.  TritonRoute
reduced 4,558 initial detailed-route violations to zero.  No persistent
macro-edge hotspot or pin-access failure remains.  High-fanout `rst_n` (1,465
sinks) remains visible to the router and is a future physical-optimization
candidate, but it is not on the final setup-critical path.

## 12. Area

| Quantity | Area/count |
|---|---:|
| Synthesis standard cells | 436,616.813 um2 |
| Final placed standard cells including tap/endcap/repair/CTS | 483,344.467 um2 |
| Physical-only increase | 46,727.654 um2 |
| Tap/endcap contribution before CTS repair | about 37,069.946 um2 |
| CTS/timing-repair net increase beyond tap/endcap | about 9,657.708 um2 |
| Standard-cell instances | 12,775 |
| Buffer/inverter instances | 1,260 |
| Clock buffers | 120 / 9,686.477 um2 |
| SRAM macros | 2 / 294,424.874 um2 |

Final standard-cell utilization is 54.76% of the actual snapped legal row
region (or 38.84% of gross core area), below the preferred 65% planning point
and below the 500,000-um2 preferred physical limit.

## 13. Final physical timing verdict

```text
61.44-MHz PHYSICAL SETUP CLOSURE: PASS
PHYSICAL HOLD CLOSURE: FAIL (external input minimum-delay contract only)
INTERNAL/SRAM HOLD CLOSURE: PASS
```

Final extracted setup WNS is +0.20 ns, TNS is 0, and there are zero setup
violating endpoints.  Overall hold WNS is -0.65 ns, TNS -3.25 ns across eight
external input endpoints; internal hold WNS is +0.69 ns.  The worst setup path
is now result-metadata/control logic (`_20048_` to `_19199_`), not DFT12 or the
multiplier.  The worst hold path is `din[7]` to `_20813_` under a zero minimum
input delay.

## 14. RTL and architectural integrity

Production RTL modified: **NO**.

The physical flow consumes the existing authoritative mapped handoff.  It
retains 16-bit precision, exactly two 256x8 SRAMs, one scalar multiplier, one
shared butterfly, FFT II=8, FFT128/IFFT128=3,601 cycles, the 50% scheduling
contract, the 22-pin interface, and the complete debug protocol.

## 15. Physical-flow readiness

```text
Reusable two-SRAM physical flow: YES
Placement: PASS
CTS: PASS
Global route: PASS
Detailed route: PASS (zero DRC)
OpenRCX extraction: PASS
```

This is a credible preliminary implementation, not foundry signoff.  Remaining
signoff work includes a real pad/interface timing model, multi-corner RC/timing,
antenna/fill treatment, LVS/DRC against final GDS, and power/IR analysis.

## 16. Final verdict and next task

```text
61.44 MHz physically credible: CONDITIONAL
Remaining timing problem primarily: CLOCK / external-interface hold contract
Ready for clock-gating task: NO
```

Physical locality, sizing, buffering, cloning, CTS, and routed extraction close
the internal 61.44-MHz setup deficit without RTL retiming.  The one recommended
next task is **pad-aware I/O hold closure and multi-corner extracted timing
signoff**: freeze real input minimum delays/pad models, repair the eight input
hold paths, and revalidate setup/hold across corners.  Clock gating should wait
until that interface timing baseline is frozen.
