# ButterFold Padframe-A Design Report

## 1. Design objective and result

ButterFold owns the Padframe-A cell selection, placement, and die-level timing contract.  This pass produced a concrete 22-allocation pin map, a GF180 pad wrapper, pad characterization, a localized `din[7]` hold repair, wrapper simulation, and a reproducible physical flow.  It did **not** achieve pad-level physical signoff: the first pad-aware place/CTS run exposed an unrepaired GF input-pad core-driver transition violation and a non-viable clock-tree result.  Consequently the wrapper is an implemented candidate, not a signed-off tapeout padframe, and the core-only routed timing numbers are not reused as pad-level signoff.

## 2. Selected GF180 pad cells

Installed collateral is under `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/{lef,lib,verilog}`.  The analyzed corners are `ss_125C_4v50`, `tt_025C_5v00`, and `ff_n40C_5v50`.  Signal/power pads are 75 x 350 um; corners are 355 x 355 um.

| Purpose | Cell | Drive/configuration | Timing model | Selection reason |
|---|---|---|---|---|
| clock, reset, `din`, valid | `gf180mcu_fd_io__in_c` | CMOS input, pulls off | GF Liberty | Fastest fully supported simple input; no specialized clock pad exists in this library. |
| ready, `dout`, valid | `gf180mcu_fd_io__bi_t` | output-only, `PDRV=00`, `SL=0` | GF Liberty | Smallest programmable drive adequate for the nominal 5 pF study; avoids fixed 24 mA `bi_24t`. |
| I/O supply | `gf180mcu_fd_io__dvdd`, `__dvss` | pad-ring supply | LEF/Verilog/Liberty | Native digital I/O supply continuity. |
| corners/fill | `__cor`, `__fill1/5/10/fillnc` | physical | LEF | Native ring geometry. |

`in_s` was rejected because its characterized minimum delay was slower (SS/TT/FF approximately 2.04/1.22/0.83 ns versus 1.67/1.01/0.72 ns for `in_c`) without a compensating clock-quality benefit.  Package ESD performance was not independently certified; selection relies on the PDK's I/O-cell intent.

## 3. Final logical 22-allocation map

The mapping is deterministic and preserves bus order. Coordinates are pad-row locations in micrometres.

| Pad | Side/location | Signal | Cell | Direction |
|---:|---|---|---|---|
| 1 | North 900 | `clk` | `in_c` | input |
| 2 | North 975 | `rst_n` | `in_c` | input |
| 3 | West 500 | `din_valid_i` | `in_c` | input |
| 4-11 | West 575-1100, 75 pitch | `din[0]` through `din[7]` | `in_c` | input |
| 12 | West 1175 | `din_ready_o` | `bi_t` | output |
| 13-20 | East 500-1025, 75 pitch | `dout[0]` through `dout[7]` | `bi_t` | output |
| 21 | East 1100 | `dout_valid_o` | `bi_t` | output |
| 22 | North 1050 | VDD/DVDD allocation | `dvdd` | power |

The `dvss` cell at South 1050 and four corner cells are supplemental ring infrastructure, not additional logical protocol allocations.  Final Padframe-A ownership must confirm that convention before tapeout.

## 4. Padframe architecture

`butterfold_padframe_top.sv` instantiates real GF pads around an unchanged `butterfold_top`:

```
external PAD -> in_c -> optional minimum-delay cells -> butterfold_top
butterfold_top -> bi_t (output-only, weakest drive) -> external PAD
```

Only `din[7]` has two `buf_1` cells. No input register, protocol cycle, transform logic, or core RTL was added.

## 5. Raw input timing and common-delay cancellation

At a 5 pF characterization load, `in_c` minimum PAD-to-Y delay is 1.67/1.01/0.72 ns at SS/TT/FF. Two `buf_1` cells raise it to 3.07/1.83/1.27 ns, adding 1.40/0.82/0.55 ns. Matched clock and data pads contribute common delay; therefore the pad delay itself does not automatically repair hold. The prior routed-core differential analysis required raw external hold of approximately 0.87 ns at its worst point (the historical eight paths all originated at `din[7]`, not eight different bits).

## 6. Hold-target study

| External target | Required delay over raw 0.87 ns | Candidate | Result before full route |
|---:|---:|---|---|
| 0.50 ns | 0.37 ns | one/two small buffers | feasible |
| 0.25 ns | 0.62 ns | two small buffers | feasible |
| 0.10 ns | 0.77 ns | two `buf_1` | selected; characterized added delay >=0.55 ns at FF and 1.40 ns at SS, but final correlated STA is pending |
| 0.00 ns | 0.87 ns | two buffers | insufficiently margin-qualified without routed MCMM STA |

The 0.10 ns choice is a target, not a frozen signed-off number.

## 7. Hold-repair implementation

Affected pin: `din[7]`. Cells: two `gf180mcu_fd_sc_mcu9t5v0__buf_1` in series. Characterized added delay is 0.55-1.40 ns over FF-SS. All other data bits and valid remain direct because the prior raw analysis showed positive hold. The final repair area could not be isolated from a completed placed database because the pad-aware flow did not reach placement completion.

## 8. External input specification status

Candidate clock is 61.44 MHz (16.276 ns). Candidate source constraints are maximum launch/board delay 0.20 ns after the preceding rising edge and minimum hold 0.10 ns after the sampling edge; equivalently the full-cycle input setup requirement is 16.076 ns before the sampling edge. The prior core-only conditional specification was max delay 1.82 ns and hold 0.97 ns. **No new input specification is frozen**, because extracted pad-aware STA did not complete.

## 9. Output timing and load sensitivity

Isolated `bi_t`, `PDRV=00`, characterized PAD delay:

| Load | FF max | TT max | SS max |
|---:|---:|---:|---:|
| 2 pF | 1.77 ns | 2.59 ns | 4.36 ns |
| 5 pF nominal | 1.99 ns | 2.90 ns | 4.90 ns |
| 10 pF | 2.38 ns | 3.51 ns | 5.91 ns |

At 5 pF the isolated minimum is 1.94/2.86/4.87 ns (FF/TT/SS). These are pad-only propagation values, not final clock-to-output specifications; core clock-to-Q, routing, and clock insertion remain to be included after successful route.

## 10. Reset

The core uses asynchronous active-low reset assertion and deassertion. The wrapper preserves that behavior through `in_c`; no release synchronizer was added. Recovery/removal was not signed off in the failed physical candidate. Until quantified, the safe system rule is to deassert reset while the clock is stopped or hold reset inactive for at least one complete clock period before sending a command. A reset-release synchronizer would change semantics and is not silently introduced.

## 11. Physical implementation

The candidate uses a 2235 x 2235 um die and a snapped core of (370.16,372.96)-(1864.80,1864.80). SRAM low/high macros remain adjacent/correlated at (390,1504.12) R0 and (1845,1504.12) MY with 20 um halo. Floorplan and PDN generation pass. Placement does not complete: GF `in_c` Y has a 1.0 ns library transition limit, while the best achievable value reported by resizer is 2.722 ns with 2.90 pF load. The subsequent experimental run without generic repair reached CTS but produced about -53.9 ns setup during post-CTS repair, so it was terminated as physically invalid. There is no final pad-aware route and no pad-aware DRC count. The validated core-only design remains DRC 0.

OpenROAD 26Q2 also crashes in `place_io_fill` for rotated GF pad rows; deterministic native `fill5` placement was prototyped but its instances trigger an STA graph crash. Pad filler closure is therefore another explicit tooling blocker.

## 12. Clock tree

The failed CTS candidate recognized the pad clock and created two downstream clock nets. It inserted 125 register-tree buffers, three macro-tree buffers, and four balance buffers, with a reported 3-4 level register tree. The pad-clock net itself had one sink. The resulting setup collapse means insertion delay/skew are not acceptable signoff values and are deliberately not frozen.

## 13. Multi-corner timing

| Corner/RC | Setup | Hold | Input | SRAM |
|---|---|---|---|---|
| SS/RCmax | NOT RUN: no valid route | NOT RUN | NOT SIGNED OFF | core-only previously PASS |
| TT/RCnom | NOT RUN: no valid route | NOT RUN | NOT SIGNED OFF | core-only previously PASS |
| FF/RCmin | NOT RUN: no valid route | NOT RUN | NOT SIGNED OFF | core-only previously PASS |

The reusable `padframe_signoff.tcl` is provided and refuses to run unless `route.odb` exists. This prevents accidental reuse of core-only timing as pad-level evidence.

## 14. Critical paths

Final pad-aware setup/hold paths are unavailable. The physical blocker is presently the pad-to-core electrical/clock architecture, not the frozen DFT12 or multiplier cones. Core-only evidence remains +0.20 ns setup, DFT12 +0.51 ns, multiplier +0.90 ns, and internal/SRAM hold +0.69 ns; these are historical context only.

## 15. Area

Core-only placed standard-cell area is 483,344.467 um2 at 54.76% legal-row utilization. Each selected signal/power pad is 26,250 um2 and each corner is 126,025 um2. There are 21 signal pads plus DVDD and supplemental DVSS, plus four corners. Final CTS, repair, filler, and utilization figures are not available from a valid pad-aware implementation.

## 16. Functional verification

| Test | Result |
|---|---|
| FFT2, IFFT2, FFT3, DFT12, FFT128, IFFT128 | PASS |
| OFDM RX/TX short and long | PASS |
| ECHO, MAGIC, SRAM READ/WRITE, full sweep | PASS |
| behavioral SRAM | PASS |
| official GF SRAM | PASS |
| reset recovery | PASS |
| pad-wrapper reset/ECHO/MAGIC/SRAM/FFT2 smoke | PASS |
| explicit input/output bit ordering in wrapper | PASS (no permutation) |

## 17. ButterFold pad-level specification

No pad-level timing specification is frozen. Candidate values pending successful extracted STA are: 61.44 MHz, maximum input launch/board delay 0.20 ns, input hold 0.10 ns, nominal output load 5 pF, and pad-only output delay 1.94-4.90 ns. Output clock-to-PAD min/max and reset recovery/removal remain unresolved.

## 18. Signoff scope

**DIE/PAD-LEVEL TIMING: FAIL (implementation incomplete)**  
**PACKAGE PARASITICS: NOT INCLUDED**  
**BOARD TIMING: SYSTEM-INTEGRATION RESPONSIBILITY**

## 19. Architectural integrity

- production ButterFold core RTL changed: NO
- 16-bit: YES
- 2 x 256x8 SRAM: YES; 512x8: NONE
- one multiplier / one shared butterfly: YES
- FFT II=8 and FFT128/IFFT128=3,601 cycles: YES
- 22 logical allocations and unchanged debug protocol: YES

## 20. Clock-gating readiness

**READY FOR CLOCK-GATING + POWER TASK: NO.** Clock gating must not begin until the input-pad drive boundary, CTS root, pad fillers, PG connectivity, route, DRC, reset checks, and extracted SS/TT/FF timing are closed.

## 21. Recommended next task

Perform exactly one focused **pad-to-core input/clock buffering and CTS-root repair**: insert and characterize explicit legal core-side receiver buffers for every `in_c` data/valid output and a dedicated clock receiver/root buffer, then rerun placement/CTS/route and extracted SS/TT/FF STA. This directly addresses the measured 2.722 ns pad-driver transition and failed CTS result without changing ButterFold core RTL.
