# Scalar Multiplier Final Timing Report

## 1. Baseline

The audited baseline reproduced exactly: 436,616.813 um2, WNS -0.53 ns,
TNS -15.27 ns, and 176 violating endpoints at 61.44 MHz.  The DFT12 phase/input
path is worst at -0.53 ns; the registered scalar-operand paths follow at
-0.47 ns.

## 2. Exact multiplier path

The representative path starts at mapped resettable flop `_20324_`, Q signal
`u_transform_scheduler_core.u_mixed_radix_butterfly.scalar_operand[3]`, and
ends at `_20265_`, D/Q signal
`u_transform_scheduler_core.u_mixed_radix_butterfly.low_rr_reg[16]`.
Equivalent paths terminate in the other low partial-product registers.  The
source is the registered signed 10-bit scalar operand; the other multiply
operand is the registered signed 8-bit coefficient.  The product is signed
18-bit.  The reported instance is phase 0 (`rr` low chunk); radix-2 and radix-3
share this same physical multiplier.

Path decomposition from the mapped report:

| Portion | Cumulative delay |
|---|---:|
| Source flop CLK-to-Q | 1.54 ns |
| Initial multiplier gates | 4.64 ns |
| Multiplier carry/XOR network | 14.58 ns |
| Destination enable/select and slice | 16.27 ns |
| Endpoint setup requirement | 15.80 ns |
| Slack | -0.47 ns |

The multiply network, not post-multiply formatting, dominates.  The final
AND/NOR/MUX portion adds about 1.69 ns, including the destination register's
phase-controlled update.  There is no high/low reconstruction on this path;
the full exact 18-bit low product is captured directly.

## 3. Width/sign audit

| Item | Declared | Effective/mapped | Required | Signed |
|---|---:|---:|---:|---|
| `scalar_coefficient_reg` | 8 | 8 | 8 | yes |
| `scalar_operand_reg` | 10 | 10 | 10 | yes |
| coefficient alias | 8 | optimized alias | 8 | yes |
| operand alias | 10 | optimized alias | 10 | yes |
| multiply expression/context | initially context-expanded to 18 | reduced by Yosys to 8x10 | 8x10 | yes |
| `scalar_partial` | 18 | 18 | 18 | yes |
| low/high partial registers | 18 | 18 | 18 | yes |

Yosys explicitly reports converting the multiply to signed, then removing ten
top bits from its context-expanded A port and eight from B.  The resulting
physical arithmetic is therefore the intended signed 8x10 multiply; there is
no accidental wider multiplier left to remove.  Concatenations forming low
chunks are unsigned-magnitude values with a leading zero; high chunks are
explicitly sign extended.  No unsized literal affects the multiply boundary.

## 4. Candidate A: exact-width/cast cleanup

The aliases and explicit `$signed` calls were replaced experimentally by one
standalone signed 8x10-to-18-bit product assignment.  All behavioral commands
remained bit-exact, but ABC produced a substantially worse multiplier network:

| Area | WNS | TNS | Multiplier slack | DFT slack |
|---:|---:|---:|---:|---:|
| 434,313.734 um2 | -1.79 ns | -631.32 ns | -1.79 ns family | no longer limiting |

The candidate was rejected and fully reverted.

## 5. Candidate B: partial-product capture cleanup

The eight partial-product payload registers were moved to a dedicated fixed
phase-capture block without payload reset.  This preserved latency, one product
per clock, and bit-exact behavior.  Although it removed reset semantics from
guarded payload, the changed flop/mux mapping worsened timing:

| Area | WNS | TNS | Multiplier slack | DFT slack |
|---:|---:|---:|---:|---:|
| synthesis completed; not retained | -1.13 ns | -124.12 ns | -1.13 ns family | no longer limiting |

It was rejected and fully reverted.

## 6. Candidate C: product-register retime

Not implemented.  A fixed product register would delay all partial-product
destinations one cycle.  Because phase 7 is already specially registered before
`ii` reconstruction, a correct implementation also requires shifting product
reconstruction and the arithmetic-valid handoff.  This is not a small cleanup,
and it cannot cure the independent unchanged -0.53 ns DFT path.  The risk/cost
therefore fails this task's retain criterion.

## 7. Retained RTL

No production RTL change was retained.  Both candidates were restored to the
accepted checkpoint.  The accepted phase-7 product register and `ii`
reconstruction retime remain intact.

## 8. Timing history

| Step | Change | Area (um2) | WNS | TNS | DFT slack | Multiplier slack |
|---|---|---:|---:|---:|---:|---:|
| Baseline/final | accepted RTL | 436,616.813 | -0.53 | -15.27 | -0.53 | -0.47 |
| A | standalone exact-width expression | 434,313.734 | -1.79 | -631.32 | secondary | -1.79 |
| B | non-reset fixed phase capture | not retained | -1.13 | -124.12 | secondary | -1.13 |

## 9. Final synthesis timing

| Metric | Final |
|---|---:|
| Minimum period | 16.80 ns |
| Fmax | 59.51 MHz |
| WNS at 61.44 MHz | -0.53 ns |
| TNS | -15.27 ns |
| Violating endpoints | 176 |
| Worst path | DFT12 `dft12_phase[1]` to butterfly `x1_i_ext[15]` |
| Second-worst family | scalar operand to low partial-product capture, -0.47 ns |

**SYNTHESIS-LEVEL 61.44-MHz SETUP CLOSURE: FAIL.**

## 10. SRAM timing

Fresh restored-baseline reports give address setup +1.13 ns, data setup
+1.32 ns, control setup +3.75 ns, and worst hold +0.96 ns (address +1.29 ns,
control +1.47 ns).  All SRAM checks pass.

## 11. Area

Starting and final area are 436,616.813 um2 (delta zero).  Utilization in the
884,937.926 um2 planning cell region is 49.34%; headroom to 65% is
138,592.839 um2.

## 12. Verification

| Test | Result |
|---|---|
| FFT2 / IFFT2 / FFT3 / DFT12 | PASS, bit-exact |
| FFT128 / IFFT128 | PASS, bit-exact |
| OFDM RX short / long | PASS, bit-exact |
| OFDM TX short / long | PASS, bit-exact |
| ECHO / MAGIC / SRAM READ / SRAM WRITE / full sweep | PASS |
| SRAM wrapper | PASS |
| Behavioral SRAM | PASS |
| Official GF180 SRAM | PASS |
| Fast / paced stress | PASS / PASS |
| Scheduled fast / paced stress | PASS / PASS |
| Reset recovery | PASS |
| Protected Python/vector diff | empty |

FFT II remains 8 and FFT128/IFFT128 remain 3,601 cycles.  Measured scheduled
intervals remain RX 4,226/4,230 and paced TX 8,305/8,337 cycles, preserving the
50% grid contract and all direction-transition rules.

## 13. Architectural integrity

Exactly one scalar multiplier and one shared butterfly remain.  The design
retains two 256x8 SRAM macros, 16-bit Q7-fractional arithmetic, the 22-pin top
interface, all command/debug protocols, and the modulo-8 FFT schedule.

## 14. Physical experiment

No production placement flow is available in the current project.  The only
local OpenROAD collateral is an area-study-only Padframe-A harness describing
the obsolete three-macro planning arrangement and one token standard cell; it
cannot place, CTS, or route the synthesized authoritative netlist.  Therefore:

- placement: not attempted (missing production floorplan/netlist flow);
- CTS/global route: not available;
- post-place/post-CTS/post-route setup and hold: not yet determined.

Using that nonfunctional harness would not provide meaningful evidence for the
residual DFT path.

## 15. Final verdict

| Question | Verdict |
|---|---|
| Multiplier critical path improved | NO; safe rewrites mapped worse and were reverted |
| DFT12 now dominant | YES, unchanged at -0.53 ns |
| 61.44-MHz synthesis setup | FAIL |
| 61.44-MHz preliminary physical setup | NOT YET DETERMINED |
| SRAM timing | PASS |
| Bit-exact | YES |
| FFT II=8 | YES |
| Area <465k | YES |

## 16. Recommended next task

Build and run one **physical-placement-driven DFT12 timing optimization** flow
for the authoritative two-SRAM netlist: real macro placement, standard-cell
placement, physical sizing/buffering, CTS, and global route at 61.44 MHz.  The
four prior DFT RTL retimes and both safe multiplier cleanups all worsened mapped
timing; placement locality, fanout repair, and cell sizing are now the justified
next levers rather than another architectural retime.
