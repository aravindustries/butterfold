# ButterFold scalar-multiplier pipeline timing report

## 1. Baseline

This focused pass started from the verified timing-optimized two-SRAM
checkpoint:

| Metric | Baseline |
|---|---:|
| Standard-cell area (SRAM excluded) | 438,550.157 µm² |
| Minimum setup period | 16.96 ns |
| Estimated fmax | 58.96 MHz |
| WNS at 61.44 MHz | -0.69 ns |
| TNS at 61.44 MHz | -106.05 ns |

The dominant family was a registered folded-multiplier operand through the
8x10 signed multiply and phase-selected partial-product capture.

## 2. Critical-path decomposition

Before this pass, the phase-7 path combined the registered coefficient and
operand, the scalar multiply, high/low `ii` reconstruction, and capture. The
local retime registers phase 7's 18-bit scalar product first. This moves the
`ii` reconstruction and complex-product handoff to the following cycle.

The retained scalar path now starts at `scalar_operand_reg` (reported by STA
as `scalar_operand[3]`) and terminates at a phase-0..6 partial-product DFF. Its
representative final timing is:

| Portion | Approximate cumulative arrival |
|---|---:|
| Source DFF CLK-to-Q | 1.54 ns |
| Multiplier XOR/XNOR carry network | 9.13 ns |
| Product/capture network | 15.73 ns |
| Final capture mux | 16.27 ns |
| Destination setup | 0.48 ns |
| Slack at 16.276 ns | -0.47 ns |

Operand phase decode and source selection are no longer in this path; they
occur while the previous product is executing and terminate at
`scalar_coefficient_reg` / `scalar_operand_reg`. The final chip WNS is now a
different DFT12 phase/input-selection path at -0.53 ns.

## 3. Old scalar schedule

The arithmetic decomposition is unchanged. Each signed 17-bit complex
operand component is represented as `signed_high*512 + unsigned_low`.

| Phase | Product | Coefficient | Operand chunk | Signed width | Destination |
|---:|---|---|---|---|---|
| 0 | rr low | `wr` | unsigned `operand_i[8:0]` | 8x10 -> 18 | `low_rr_reg` |
| 1 | iq low | `wi` | unsigned `operand_q[8:0]` | 8x10 -> 18 | `low_iq_reg` |
| 2 | rq low | `wr` | unsigned `operand_q[8:0]` | 8x10 -> 18 | `low_rq_reg` |
| 3 | ii low | `wi` | unsigned `operand_i[8:0]` | 8x10 -> 18 | `low_ii_reg` |
| 4 | rr high | `wr` | signed `operand_i[16:9]` | 8x10 -> 18 | `high_rr_reg` |
| 5 | iq high | `wi` | signed `operand_q[16:9]` | 8x10 -> 18 | `high_iq_reg` |
| 6 | rq high | `wr` | signed `operand_q[16:9]` | 8x10 -> 18 | `high_rq_reg` |
| 7 | ii high | `wi` | signed `operand_i[16:9]` | 8x10 -> 18 | formerly direct reconstruction |

Radix-3 uses the same eight phases with `operand=x1-x2` and the existing
`-j*sqrt(3)/2` coefficient. No radix equation or scaling point changed.

## 4. New multiplier-context pipeline

The retained implementation has three local timing stages:

1. **Context preparation:** deterministic phase N+1 coefficient and operand
   chunk are selected and registered in `scalar_coefficient_reg` and
   `scalar_operand_reg`.
2. **Multiply/capture:** one 8x10 signed multiplication is accepted every
   active clock. Phases 0..6 capture their original 18-bit partial products;
   phase 7 captures `final_scalar_product_reg` and asserts
   `final_scalar_pending`.
3. **Completion:** one cycle later, the registered phase-7 product is combined
   with `low_ii_reg`; the existing arithmetic/combine pipeline receives the
   same reconstructed four complex products.

Only an 18-bit product register and one valid bit are added to the phase-7
handoff. Full butterfly context is not duplicated.

## 5. New cycle schedule

The multiplier remains fully occupied during each active eight-cycle slot.
The completion stage overlaps the next butterfly's phase 0:

| Modulo cycle | Butterfly N-1 | Butterfly N | Butterfly N+1 |
|---:|---|---|---|
| 0 | completion/result handoff | phase 0 multiply | context phase 1 |
| 1 | pending writeback | phase 1 multiply | context phase 2 |
| 2 | pending writeback | phase 2 multiply | context phase 3 |
| 3 | pending writeback | phase 3 multiply | context phase 4 |
| 4 | SRAM writeback | phase 4 multiply | context phase 5 |
| 5 | SRAM writeback | phase 5 multiply | context phase 6 |
| 6 | SRAM writeback | phase 6 multiply | context phase 7 |
| 7 | SRAM writeback | phase 7 multiply/register | context N+1 phase 0 |

At the next cycle-0 edge, N completes while N+1 phase 0 is captured. The
pending-result mechanism therefore absorbs the extra phase-7 latency without
adding a ninth memory cycle.

## 6. Arithmetic equivalence

All eight scalar products retain their operands, signed widths, phase order,
18-bit capture, `high<<9 + low` reconstruction, complex add/subtract widths,
Q7 shift, and wrap/truncation locations. The only semantic change is temporal:
phase-7's already-computed 18-bit product is registered before reconstruction.
Behavioral and official-foundry-model regressions are bit-exact.

## 7. Optimization history

| Step | Change | Area (µm²) | Period | Fmax | WNS | TNS | Result |
|---|---|---:|---:|---:|---:|---:|---|
| 0 | Starting timing checkpoint | 438,550.157 | 16.96 ns | 58.96 MHz | -0.69 ns | -106.05 ns | baseline |
| 1 | Full product/tag pipeline plus completion context | 446,531.904 | worse | — | -1.64 ns | -527.04 ns | rejected |
| 2 | Phase-7-only product register/valid handoff | 436,616.813 | 16.80 ns | 59.51 MHz | -0.53 ns | -15.27 ns | retained |
| 3 | Uniform product/tag register for all phases | 438,564.269 | worse | — | -1.74 ns | -115.09 ns | rejected |
| 4 | Fixed eight-product shift pipeline | 437,932.051 | 17.86 ns | 55.98 MHz | -1.59 ns | -584.36 ns | rejected |

Drive-strength-only and mapping-effort trials were also rejected: global
drive-4 DFF mapping cost 460,776.557 µm² and worsened WNS to -0.67 ns; tighter
ABC delay targets did not improve the retained candidate.

## 8. Final timing

| Metric | Final |
|---|---:|
| Minimum setup period | 16.80 ns |
| Estimated fmax | 59.51 MHz |
| WNS at 61.44 MHz | -0.53 ns |
| TNS at 61.44 MHz | -15.27 ns |
| Violating endpoints | 176 |
| Worst path | `dft12_phase[1]` -> DFT12/butterfly input capture |
| Worst remaining multiplier path | `scalar_operand_reg` -> phase-0..6 partial product, -0.47 ns |

**SYNTHESIS-LEVEL 61.44-MHz SETUP CLOSURE: FAIL.**

The focused retime improves WNS by 0.16 ns and TNS by 90.78 ns. It removes
phase 7 from the dominant multiplier path, but the remaining 0.53-ns global
miss cannot be honestly reported as closure.

## 9. SRAM timing

| Check | Worst slack |
|---|---:|
| Address setup | +0.88 ns |
| Data setup | +1.32 ns |
| Control setup | +3.06 ns |
| Address hold | +1.28 ns |
| Data hold | +0.96 ns |
| Control hold | +0.72 ns |

**SRAM PRE-LAYOUT TIMING: PASS.** The task improved rather than consumed the
previously narrow SRAM setup margin. Physical signoff is still required.

## 10. Area

| Metric | Value |
|---|---:|
| Starting area | 438,550.157 µm² |
| Final area | 436,616.813 µm² |
| Delta | -1,933.344 µm² (-0.44%) |
| 20-µm-halo cell region | 884,937.926 µm² |
| Required utilization | 49.34% |
| Headroom to 65% | 138,592.839 µm² |

The mapped netlist retains exactly one scalar multiplier function, one shared
butterfly, and two 256x8 SRAM macros.

## 11. FFT schedule

- FFT initiation interval: 8 cycles/butterfly.
- FFT128: 3,601 cycles.
- IFFT128: 3,601 cycles.
- Startup/drain delta: 0 cycles versus the starting checkpoint.
- Scheduled intervals: RX short/long 4,226/4,230 cycles; TX short/long
  8,305/8,337 paced cycles.
- Frozen grid contract remains satisfied: 50% sustained allocation; RX->RX
  +2 symbols, TX->TX +2, RX->TX +3, TX->RX +1.

## 12. Verification

| Test | Result |
|---|---|
| FFT2 / IFFT2 / FFT3 / DFT12 | PASS |
| FFT128 / IFFT128 | PASS, bit-exact |
| OFDM RX short / long | PASS, bit-exact |
| OFDM TX short / long | PASS, bit-exact |
| ECHO / MAGIC / SRAM READ / SRAM WRITE | PASS |
| Full behavioral SRAM debug sweep | PASS |
| Behavioral SRAM full regression | PASS |
| Official GF180 SRAM full regression | PASS |
| Fast stress | PASS |
| 61.44-MHz paced stress | PASS |
| Scheduled/backpressure stress | PASS |
| Reset recovery | PASS |
| Protected Python/vector diff | empty |

## 13. Physical spot-check

The requested placement spot-check is conditional on synthesis WNS >= 0.
Because synthesis remains at -0.53 ns, no new placement/CTS/global-route run
was started. The existing two-SRAM macro-planning result remains applicable,
but it is not physical timing signoff.

## 14. Final verdict

| Question | Verdict |
|---|---|
| One scalar multiplier retained | YES |
| 8-cycle FFT II retained | YES |
| 16-bit bit-exact behavior retained | YES |
| Two-SRAM architecture retained | YES |
| 61.44-MHz synthesis setup | **FAIL (-0.53 ns)** |
| SRAM pre-layout timing | PASS |
| Area below 500k | YES |

## 15. Recommended next task

Perform exactly one focused **DFT12 phase/input-selection retiming pass**. The
new WNS path begins at `dft12_phase[1]`, traverses phase decode plus the DFT12
RAM/input-selection cone, and ends at butterfly input capture. It requires at
least 0.53 ns improvement at the audited corner. The same task should also
locally finish the remaining -0.47-ns phase-0..6 scalar capture paths if the
DFT retime exposes them as WNS; it must preserve the eight-cycle FFT II.
