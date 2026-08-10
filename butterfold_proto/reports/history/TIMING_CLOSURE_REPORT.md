# ButterFold 61.44-MHz timing-closure report

## 1. Baseline

The audited authoritative two-SRAM checkpoint reproduced the expected baseline:

| Metric | Baseline |
|---|---:|
| Standard-cell area (SRAM excluded) | 407,373.926 µm² |
| Minimum edge-triggered period | 18.89 ns |
| Estimated fmax | 52.94 MHz |
| WNS at 61.44 MHz | -3.04 ns |
| TNS at 61.44 MHz | -1,082.99 ns |

The dominant edge-triggered path family was the folded scalar-multiplier and
result-selection cone. The overall report also exposed low-phase wrapper-latch
paths into the FFT SRAM interface; Section 4 explains why those latches were
not a valid physical implementation.

Tools used were Yosys 0.64 (`/foss/tools/bin/yosys`) and OpenSTA 3.1.0
(`/foss/tools/bin/sta`).

## 2. Constraint audit

The final run uses the same audited setup methodology as the baseline:

- Clock: `core_clk` on input port `clk`.
- Period: 16.276041667 ns (61.44 MHz).
- Waveform: rise 0.0 ns, fall 8.1380208335 ns.
- Clock uncertainty: 0.0 ns.
- Input delays: 0.0 ns on `din[*]` and `din_valid_i`.
- Output delays: 0.0 ns on `din_ready_o`, `dout[*]`, and `dout_valid_o`.
- No input transition or output load is invented. Consequently the I/O result
  is an internal-core synthesis baseline, not a board-interface signoff.
- Reset: `set_case_analysis 1` on asynchronous `rst_n` for normal-operation
  setup analysis.
- Standard cells: GF180 MCU 9-track 5-V
  `gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib`.
- SRAMs: two instances of
  `gf180mcu_fd_ip_sram__sram256x8m8wm1`, timed with its
  `ss_125C_4v50` Liberty.
- Timing exceptions: no false paths, multicycle paths, clock groups, or
  disabled timing arcs are defined.

The flow flattens `butterfold_top`, maps all sequential cells with the Liberty,
maps combinational logic with ABC, and rejects residual generic multiply, add,
subtract, mux, flop, or latch cells. SRAM macros remain hard macros.

## 3. Critical-path Pareto

The retained STA infrastructure reports the top 50 setup paths. At the final
checkpoint their leading families are:

| Family | Top-50 count | Worst slack | Representative source → destination | Observation |
|---|---:|---:|---|---|
| Scalar multiplier/partial-product capture | 1 | -0.69 ns | `scalar_operand[4]` register → folded partial-product register | 8×10 signed product logic, reconstruction, and final capture mux |
| Result metadata/scratch-selection fanout | 49 | -0.46 ns | `result_meta_read_pointer[1]` → result/scratch-selection registers | broad deterministic result selection; many endpoints share one source cone |
| SRAM data setup | outside violating top 50 | +0.08 ns | edge register → SRAM D | passes, but has little pre-layout margin |
| SRAM address setup | outside violating top 50 | +0.25 ns | edge register → SRAM A | passes |
| SRAM control setup | outside violating top 50 | +2.41 ns | input/control register → SRAM control | passes |
| SRAM CLK→Q capture | outside violating top 50 | +4.50 ns | SRAM Q → edge register | macro plus short external capture logic |

There are 378 setup-violating endpoints in the final ideal-clock synthesis
model. WNS is set by the multiplier; most TNS is the replicated
result/scratch-selection family rather than a single isolated endpoint. The
worst reported pre-layout hold slack is +0.32 ns at an I/O-fed register. This is
not a substitute for post-CTS/post-route hold closure.

## 4. Latch/SRAM investigation

The wrapper's low-phase transparent latches were introduced to avoid a
zero-delay event-order race in the official functional Verilog model. That
model delays its internal clock/control observation; without staging, a
same-timestep RTL control change can be sampled differently from a physical
setup/hold event.

The real SRAM Liberty instead specifies ordinary address, data, CEN, GWEN, and
WEN setup/hold checks to the rising CLK edge. A synthesized low-phase latch
that closes on that same edge cannot guarantee that its Q reaches the macro
before the macro samples it. Explicit STA of that implementation produced a
-2.43 ns latch-to-SRAM failure. It is therefore **not** an intentional
half-cycle physical architecture.

The final wrapper cleanly separates the two needs:

- Functional/foundry-model simulation retains the low-phase compatibility
  staging.
- Synthesis connects edge-stable physical controls directly to the macro,
  with local GF180 drive-strength cells on CEN, GWEN/WEN, address, and data.
- No latch is present in the mapped production netlist.

Official GF180 functional simulation still passes. The final physical SRAM
setup and hold checks all pass in pre-layout STA, but the +0.08 ns data-setup
margin is small and requires physical signoff after placement, CTS, routing,
and extraction.

## 5. Optimization history

| Step | Change | Area (µm²) | Period | Fmax | WNS | TNS | FFT II | FFT cycles |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | Audited production baseline | 407,373.926 | 18.89 ns | 52.94 MHz | -3.04 ns | -1,082.99 ns | 8 | 3,601 |
| 1 | Operand preselection, result pipeline cut, deterministic controller/scratch mux cleanup, physical wrapper correction | retained in final | — | — | -0.89 ns | — | 8 | 3,601 |
| 2 | Timing-driven drive-2 sequential mapping | 438,550.157 | 16.96 ns | 58.96 MHz | -0.69 ns | -106.05 ns | 8 | 3,601 |

Rejected experiments included indiscriminate drive-4 flops, explicit wide
input buffers, reset removal, a hand-written Booth multiplier, signed-magnitude
precomputation, and physical low-phase latches. They either failed to improve
timing proportionally, increased area, failed official SRAM regression, or
were physically invalid; none remains in the final RTL.

## 6. Final butterfly architecture

The arithmetic remains one shared mixed-radix butterfly and one simultaneous
8×10 scalar multiplier. The retained changes are local retiming:

1. Deterministic next-phase multiplier operands are selected into narrow
   registers before the multiply cycle.
2. Serialized partial products retain the existing bit widths, signedness,
   reconstruction, and wrap/truncation semantics.
3. Product reconstruction/scaling is registered in an elastic combine stage.
4. Radix-2/radix-3 final additions and result handoff occur after that cut.

The combine cut adds one cycle to first-result latency. It does not add a
multiplier or butterfly lane and does not alter arithmetic values.

## 7. Updated modulo schedule

The modulo controller still launches a butterfly every eight clocks. For each
slot, phases 0–3 perform the four physical half-word reads while the current
butterfly executes its serialized scalar phases; phases 4–7 commit the prior
result's four half-word writes. The added combine register shifts result
availability by one clock, but the existing pending-result slot absorbs that
latency. Instrumentation measured:

- launch cadence: 8 clocks;
- result cadence: 8 clocks;
- first launch-to-result latency: 18 clocks;
- FFT128/IFFT128 total: 3,601 clocks.

Thus latency increased locally while initiation interval and total transform
schedule remained unchanged.

## 8. SRAM timing

At `ss_125C_4v50` and 61.44 MHz:

| Check | Worst slack |
|---|---:|
| SRAM CLK→Q to register | +4.50 ns |
| Address setup | +0.25 ns |
| Data setup | +0.08 ns |
| Control setup | +2.41 ns |
| Address hold | +1.28 ns |
| Data hold | +0.89 ns |
| Control hold | +0.72 ns |

The representative SRAM read path consumes approximately 8.58 ns of macro
CLK→Q and 2.27 ns of external logic/capture delay, for about 10.85 ns total.
The macros' Liberty timing arcs are active; they are not ideal black boxes.

## 9. Verification

| Verification | Result |
|---|---|
| FFT2 / IFFT2 / FFT3 / DFT12 | PASS |
| FFT128 / IFFT128 | PASS, bit-exact |
| OFDM_RX short/long | PASS, bit-exact |
| OFDM_TX short/long | PASS, bit-exact |
| ECHO / MAGIC | PASS |
| SRAM READ / WRITE and full sweep | PASS |
| Behavioral SRAM regression | PASS |
| Official GF180 SRAM regression | PASS |
| Fast stress | PASS |
| 61.44-MHz paced stress | PASS |
| Scheduled/backpressure stress | PASS |
| Reset recovery | PASS |
| Protected Python/vector diff | empty |

Reset recovery was exercised with the new valid-guarded combine stage; payload
state is not externally observable until its valid state is asserted.

## 10. Throughput

- FFT steady initiation interval: 8 cycles/butterfly.
- FFT128/IFFT128: 3,601 cycles.
- Fast measured feeder intervals: RX 4,226 cycles; TX 4,210 cycles.
- Scheduled paced intervals remain RX short/long 4,226/4,230 cycles and TX
  short/long 8,305/8,337 cycles.
- The frozen grid contract remains satisfied: 50% sustained allocation,
  RX→RX +2 symbols, TX→TX +2, RX→TX +3, TX→RX +1.

## 11. Final synthesis timing

| Metric | Final |
|---|---:|
| Minimum period | 16.96 ns |
| Estimated fmax | 58.96 MHz |
| WNS at 61.44 MHz | -0.69 ns |
| TNS at 61.44 MHz | -106.05 ns |
| Violating endpoints | 378 |
| Worst path | folded scalar multiplier operand register → partial-product register |

**SYNTHESIS-LEVEL 61.44-MHz SETUP CLOSURE: FAIL.**

The pass recovered 2.35 ns of WNS (77.3% of the original miss) and reduced TNS
by 976.94 ns (90.2%), but the remaining 0.69 ns miss is real and is not hidden
with a timing exception.

## 12. Final area

| Metric | Value |
|---|---:|
| Starting standard-cell area | 407,373.926 µm² |
| Final standard-cell area | 438,550.157 µm² |
| Delta | +31,176.230 µm² (+7.65%) |
| 20-µm-halo cell region | 884,937.926 µm² |
| Required utilization | 49.56% |
| Headroom to 60% | 92,412.599 µm² |
| Headroom to 65% | 136,659.495 µm² |
| Headroom to 70% | 180,906.391 µm² |

The mapped design has 11,772 cells, including 544 non-reset DFFs, 1,435
resettable DFFs, 8 settable DFFs, 1,913 mux2 cells, 144 mux4 cells, zero
latches, and exactly two SRAM macros (SRAM area excluded above).

## 13. Preliminary physical implementation

The available OpenROAD collateral is an area-study harness, not a complete
production place-and-route flow. It successfully initialized the snapped
1,117.20 × 1,113.84 µm core (1,244,382.048 µm²), placed the two parallel
431.86 × 340.88 µm SRAMs adjacent at R0 with a 20-µm planning halo, and passed
geometric placement checking. The macro origins are (20,20) and (491.86,20)
µm.

There is no production DEF/netlist integration, PDN, CTS configuration, or
routing configuration in this harness. Consequently standard-cell placement,
CTS, global route, detailed route, congestion, and extracted timing were not
available. A macro-only placement success is not routability or timing
signoff.

## 14. Physical timing

Post-placement, post-CTS, and post-route WNS/TNS are **not available**. Hold is
positive only in the ideal-clock pre-layout estimate. Final closure still
requires real placement, CTS, routing, extraction, and setup/hold STA.

## 15. Timing-closure verdict

| Question | Verdict |
|---|---|
| 61.44-MHz edge-triggered setup | **FAIL** (-0.69 ns) |
| SRAM-interface timing | **NEEDS PHYSICAL SIGNOFF** (all pre-layout checks pass) |
| 8-cycle FFT retained | **YES** |
| Bit-exact behavior retained | **YES** |
| Two-SRAM architecture retained | **YES** |
| Area comfortably below 65% planning utilization | **YES** (49.56%) |

## 16. Remaining critical paths

The exact dominant path is `scalar_operand[4]` through the mapped 8×10 signed
multiplier/partial-product logic and capture selection into a resettable
partial-product register: 16.59 ns arrival against 15.91 ns required, slack
-0.69 ns. The next family is the result metadata/scratch-selection cone at
-0.46 to -0.35 ns across many endpoints. SRAM setup/hold is no longer the
limiting family, though SRAM data setup has only +0.08 ns pre-layout margin.

Further local Boolean reshaping did not close the multiplier path. The next
change must pipeline the serialized scalar multiplier itself while retaining
per-phase context, rather than duplicating it or adding a timing exception.

## 17. Recommended next task

Perform one focused **internally pipelined scalar-multiplier phase-context
retiming pass**, preserving one scalar multiplier and the modulo-8 initiation
schedule, then rerun the same STA and full regression suite.
