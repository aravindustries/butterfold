# DFT12 Timing-Closure Report

## 1. Baseline

The audited GF180 synthesis/STA checkpoint reproduced exactly:

| Metric | Result |
|---|---:|
| Standard-cell area | 436,616.813 um2 |
| Minimum period | 16.80 ns |
| Estimated Fmax | 59.51 MHz |
| WNS at 61.44 MHz | -0.53 ns |
| TNS | -15.27 ns |
| Violating endpoints | 176 |

## 2. Exact DFT12 critical path

The worst path starts at mapped flop `_19541_`, whose Q is
`u_transform_scheduler_core.dft12_phase[1]`, and ends at `_20677_`, the
resettable input flop for
`u_transform_scheduler_core.u_mixed_radix_butterfly.x1_i_ext[15]`.
The active phase depends on the operation; the path is the phase-dependent x1
selection shared by radix-3 and radix-2 operations.  The mapped cone is:

```
dft12_phase[1]
 -> phase decode/address selection
 -> 12-entry dft12_ram indexed-read mux
 -> final-odd versus unity-proxy selection/negation
 -> shared FFT/DFT/small-operation input mux
 -> butterfly x1_i_ext[15]
```

The phase flop CLK-to-Q is 1.45 ns.  Initial phase decode and fanout consumes
5.16 ns (inverter, NOR3, OAI21 and buffer, reaching 6.61 ns).  The first
MUX4/MUX2 pair adds 1.65 ns.  The remaining indexed-read, sign selection and
shared-input logic adds 8.02 ns, producing 16.27 ns data arrival.  The endpoint
setup requirement is 15.75 ns, hence -0.53 ns slack.  The critical fanouts are
4 at the phase flop, 9 after the NOR3 decode, and 10 at the decode buffer.

The next path family begins at butterfly `scalar_operand[3]` and ends at
`low_rr_reg[16]`; four representative scalar-multiplier endpoints are at
-0.47 ns.

## 3. DFT12 schedule

The fixed Good-Thomas/PFA schedule uses 4 radix-3 and 12 radix-2 operations.
Addresses are local 4-bit DFT scratch indices.  `F-even`, `F-odd`, `O-even`,
and `O-odd` below are the FFT4-even, FFT4-odd, final-even and final-odd phases.

| Op | Phase/radix | Sources | Scratch destinations / final outputs |
|---:|---|---|---|
| 0 | radix-3 | 0,4,8 | 0,4,8 |
| 1 | radix-3 | 9,1,5 | 1,5,9 |
| 2 | radix-3 | 6,10,2 | 2,6,10 |
| 3 | radix-3 | 3,7,11 | 3,7,11 |
| 4 | F-even radix-2 | 0,2 | 0,2 |
| 5 | F-odd radix-2 | 1,3 | 1,3 |
| 6 | O-even radix-2 | 0,1 | outputs 0,6 |
| 7 | O-odd radix-2, W4=-j | 2,3 | outputs 3,9 |
| 8 | F-even radix-2 | 4,6 | 4,6 |
| 9 | F-odd radix-2 | 5,7 | 5,7 |
| 10 | O-even radix-2 | 4,5 | outputs 4,10 |
| 11 | O-odd radix-2, W4=-j | 6,7 | outputs 7,1 |
| 12 | F-even radix-2 | 8,10 | 8,10 |
| 13 | F-odd radix-2 | 9,11 | 9,11 |
| 14 | O-even radix-2 | 8,9 | outputs 8,2 |
| 15 | O-odd radix-2, W4=-j | 10,11 | outputs 11,5 |

The CRT input map is `n=(4*n1+9*n2) mod 12`; the final output map is
`k=(4*k1+3*k2) mod 12`.  Every operation uses the existing
PREPARE -> ISSUE -> WAIT_RESULT sequencing; results are consumed only after the
shared butterfly result handshake.

## 4. Optimization candidates

Four independently synthesized candidates were evaluated.  Every candidate
passed the complete behavioral numerical regression before its timing result
was accepted or rejected.

| Candidate | Change | Area (um2) | WNS (ns) | TNS (ns) | Decision |
|---|---|---:|---:|---:|---|
| Baseline | Current dynamic phase/index selection | 436,616.813 | -0.53 | -15.27 | retained |
| A | Register src0/src1/src2, destinations and radix context in PREPARE | 447,121.786 | -0.86 | -143.83 | reject |
| B | Register all six selected complex operands plus uop/twiddles | 458,225.107 | -0.71 | -218.12 | reject |
| C | Register only critical x1 I/Q payload in PREPARE | 442,275.725 | -1.56 | -541.12 | reject |
| D | Drive address/radix selection from existing registered phase one-hot | 438,123.974 | -0.99 | -124.42 | reject |

Candidate A tested registered indices/context. Candidate B tested registered
operands. Candidate D tested a fixed predecoded schedule control. Candidate C
was the smallest scratch-selection intervention. In every case, technology
mapping moved the critical cone to a worse payload-register or selection path;
none met the retain rule. All experimental RTL was removed.

## 5. Retained implementation

No production RTL change is retained.  The authoritative implementation is
the exact starting checkpoint.  This is preferable to landing a functionally
correct but slower or larger DFT implementation.

## 6. DFT12 latency

The performance trace measures 300 cycles from `DFT12_START` to `DFT12_DONE`.
Because no candidate was retained, latency is 300 cycles before and after
(delta 0).

## 7. Production effect

No production schedule changed.  Measured scheduled intervals remain:

| Mode | Interval (cycles) |
|---|---:|
| RX short / long | 4,226 / 4,230 |
| TX short / long, fast scheduled | 4,210 / 4,212 |
| TX short / long, paced resource interval | 8,305 / 8,337 |

The frozen grid contract remains satisfied: 50% sustained allocation; RX->RX
+2 symbols, TX->TX +2, RX->TX +3, and TX->RX +1.

## 8. Timing history

| Step | Area (um2) | Period (ns) | Fmax (MHz) | WNS (ns) | TNS (ns) | Endpoints |
|---|---:|---:|---:|---:|---:|---:|
| baseline/final | 436,616.813 | 16.80 | 59.51 | -0.53 | -15.27 | 176 |
| A indices/context | 447,121.786 | about 17.14 | about 58.36 | -0.86 | -143.83 | not retained |
| B operands | 458,225.107 | about 16.99 | about 58.87 | -0.71 | -218.12 | not retained |
| C x1 only | 442,275.725 | 17.84 | 56.06 | -1.56 | -541.12 | not retained |
| D one-hot decode | 438,123.974 | 17.26 | 57.92 | -0.99 | -124.42 | not retained |

## 9. Final timing

- Overall WNS/TNS: **-0.53 ns / -15.27 ns**.
- Worst path: `dft12_phase[1]` to butterfly `x1_i_ext[15]`, -0.53 ns.
- Second-worst family: scalar operand to low partial-product registers,
  -0.47 ns.
- DFT worst: -0.53 ns.
- Multiplier worst: -0.47 ns.

**SYNTHESIS-LEVEL 61.44-MHz SETUP CLOSURE: FAIL.**

## 10. SRAM timing

The restored final checkpoint remains fully positive.  Fresh audited reports
give address setup +1.13 ns, data setup +1.32 ns, control setup +3.75 ns, and
worst hold +0.96 ns (data; address +1.29 ns, control +1.47 ns).  SRAM timing:
**PASS** pre-layout.

## 11. Area

Starting and final area are both 436,616.813 um2 (delta 0).  Against the
884,937.926 um2 planning cell region, utilization is 49.34%.  Headroom to 65%
is 138,592.839 um2.

## 12. Verification

| Test | Result |
|---|---|
| FFT2 / IFFT2 / FFT3 | PASS |
| DFT12 existing golden and deterministic suite | PASS, bit-exact |
| FFT128 / IFFT128 | PASS, bit-exact |
| OFDM RX short / long | PASS, bit-exact |
| OFDM TX short / long | PASS, bit-exact |
| ECHO / MAGIC / SRAM READ / SRAM WRITE / full sweep | PASS |
| SRAM wrapper | PASS |
| Behavioral SRAM regression | PASS |
| Official GF180 SRAM regression | PASS |
| Fast stress / paced stress | PASS / PASS |
| Scheduled fast / scheduled paced | PASS / PASS |
| Reset recovery | PASS |
| Protected Python/vector diff | empty |

## 13. FFT invariants

FFT II remains 8 cycles. FFT128 and IFFT128 remain 3,601 cycles each. The FFT
controller and physical scratch schedule were untouched.

## 14. Scheduling contract

| Requirement | Result |
|---|---|
| 50% sustained grid allocation | PASS |
| RX->RX +2 | PASS |
| TX->TX +2 | PASS |
| RX->TX +3 | PASS |
| TX->RX +1 | PASS |

## 15. Physical spot-check

The physical check was conditional on synthesis WNS >= 0. Because final WNS is
-0.53 ns, no new placement/CTS/global-route timing run was started.

## 16. Final verdict

| Question | Verdict |
|---|---|
| DFT12 bit-exact | YES |
| One shared butterfly retained | YES |
| One scalar multiplier retained | YES |
| 8-cycle FFT retained | YES |
| Two-SRAM architecture retained | YES |
| 61.44-MHz synthesis setup | FAIL |
| SRAM timing | PASS |
| Area <465k | YES |

## 17. Recommended next task

Perform exactly one focused **remaining scalar-multiplier path cleanup**.  The
four -0.47 ns paths from registered `scalar_operand` through the scalar
multiply into low partial-product registers are now the most consistent next
target.  Do not mix another DFT restructure into that task.
