# Two-SRAM ButterFold Architecture Experiment

**EXPERIMENTAL ONLY — the authoritative three-SRAM RTL is unchanged.**

## Executive result

The two existing 256x8 macros are capacity-sufficient and already support the
required direct paths in the transform core.  Removing the waveform macro and
its top-level banks/arbitration remains bit-exact and retains the 3,601-cycle,
eight-cycle-per-butterfly FFT.  It also reduces mapped standard-cell area from
484,854.45 to 395,136.00 um^2 and hard-macro area from 503,825.15 to
294,424.87 um^2.  The trade is symbol overlap: paced RX and TX command intervals
become approximately 8,062/8,094 and 8,305/8,337 clocks, respectively.

Verdict: **STRONG CANDIDATE — USER THROUGHPUT DECISION REQUIRED**.

## Memory capacity and mapping

The two parallel 256x8 macros provide 4,096 bits, exactly 128 complex samples
at 32 bits/sample.  No second full-symbol storage was added.

| Dataset | Size | Experimental lifetime/location |
|---|---:|---|
| FFT/IFFT body | 128 complex, 4,096 bits | Scratch, in-place |
| RX CP | 9/10 complex | Discarded on arrival |
| RX extracted RB | 12 complex | Existing small output path |
| TX FDIQ input/DFT12 | 12 complex | Existing DFT12 register storage |
| TX mapped/IFFT body | 128 complex | Scratch, in-place |
| TX CP | 9/10 complex | Reread from scratch; never stored separately |

RX natural-order body sample `n` is sign-extended from Q1.7 and written to
scratch address `bit_reverse7(n)`.  The iterative DIT FFT therefore produces
natural-order bins, from which bins 1..12 are extracted.  TX maps DFT12 results
to natural IFFT bins, performs the in-place IFFT, then reads samples 119..127
(short) or 118..127 (long), followed by samples 0..127.  Each sample uses the
physical half-word addresses `{sample,0}` for I and `{sample,1}` for Q.

Scratch ownership is deterministic:

| Owner | Access | Start | Release |
|---|---|---|---|
| RX capture | writes bit-reversed body | after CP discard | sample 127 stored |
| FFT/IFFT engine | serialized read/write | complete resident input/map | final write |
| RX extractor | reads bins 1..12 | FFT final write | bin 12 returned |
| TX mapper | clears/maps writes | DFT12 completion | all bins mapped |
| TX serializer | CP/body reads | IFFT final write | last body Q byte |
| standalone diagnostic | input/compute/result serialization | command | final record |

During TX waveform output the small FDIQ/DFT12 structures could theoretically
capture and compute the next 12-point block, but the experiment deliberately
uses the minimum single-job control.  Preserving that overlap would require a
new pending-command/DFT context.  Progressive scratch reuse is not useful for
starting the next IFFT: although individual body locations die after readout,
the next in-place transform needs unrestricted access to the whole scratch.

## Verification and cycle measurements

Behavioral and official GF functional regressions pass every command (FFT2,
IFFT2, FFT3, DFT12, FFT128, IFFT128, RX short/long, TX short/long) with the
unchanged references.  Official elaboration contains two 256x8 instances and
no 512x8 model.  Fast and paced alternating stress both pass numerically.

| Operation | Fast command interval | 16-clock waveform interval | Symbol budget | Paced gap | Paced duty |
|---|---:|---:|---:|---:|---:|
| RX short | 4,226 | 8,062 (derived from measured 3,677 post-input + paced capture) | 4,384 | 3,678 | 54.38% |
| RX long | 4,230 | 8,094 (same measured post-input method) | 4,416 | 3,678 | 54.56% |
| TX short | 4,210 | 8,305 measured | 4,384 | 3,921 | 52.79% |
| TX long | 4,212 | 8,337 measured | 4,416 | 3,921 | 52.97% |

FFT128 and IFFT128 each remain 3,601 compute clocks (448 butterflies at a
steady eight-cycle cadence plus 17 clocks fill/boundary/drain overhead).
The unchanged continuous stress remains numerically PASS but exposes the lost
physical cadence: paced TX has a 3,937-cycle boundary gap and 8,305-cycle
command initiation interval.  Consequently uninterrupted paced RX and TX are
both **NO** for this minimal single-job experiment.  Fast-mode command intervals
fit within a symbol budget, but fast RX input is a burst, not a 1.92-Msample/s
waveform and is not evidence of continuous air-interface capture.

The production reset-recovery test passes on the authoritative top.  Applied
unchanged to the isolated direct top it has a zero-time/back-to-back testbench
driver race and reports shifted FFT2 operands; the normal final-pin regression,
including all individual commands, and both SRAM models pass.  This is an
experimental-harness limitation, not a changed golden criterion.

## Physical area

Installed LEF geometry is 431.860 x 340.880 um (147,212.4368 um^2) for 256x8
and 431.860 x 484.880 um (209,400.2768 um^2) for 512x8.

| Metric | Three-SRAM authoritative | Two-SRAM experimental |
|---|---:|---:|
| SRAM count | 3 | 2 |
| SRAM area | 503,825.15 | 294,424.87 um^2 |
| Standard-cell area | 484,854.45 | 395,136.00 um^2 |
| Combined raw area | 988,679.60 | 689,560.87 um^2 |

Hard-macro saving is 209,400.28 um^2 (41.56% of baseline SRAM area).
Cell-logic saving is 89,718.45 um^2 (18.50%), principally removal of waveform
banks, ownership, arbitration, queues, and their selection logic.  Combined raw
saving is 299,118.73 um^2 (30.25%).  The mapped experiment contains 1,240
resettable DFFs, 544 non-reset DFFs, 27 latches, 1,683 mux2 cells, and 145 mux4
cells; sequential area is 155,593.27 um^2.

OpenROAD geometrically placed adjacent R0 macros with 10, 20, and 30 um
planning halos without placement errors.  Using the 1,244,382 um^2 snapped
quarter-core scenario:

| Halo | Effective macro footprint | Remaining cell region | Cell utilization |
|---:|---:|---:|---:|
| 10 um | 326,134.47 | 918,247.53 | 43.03% |
| 20 um | 359,444.07 | 884,937.93 | 44.65% |
| 30 um | 394,353.67 | 850,028.33 | 46.48% |

At the 20-um planning point, future standard-cell headroom is 135,826.76 um^2
at 60% utilization, 180,073.65 um^2 at 65%, and 224,320.55 um^2 at 70%.

## Synthesis-level timing

The identical ss_125C_4v50, 16.276-ns audited constraint method reports:

| Metric | Three-SRAM | Two-SRAM |
|---|---:|---:|
| Minimum period | 21.67 ns | 18.55 ns |
| Estimated fmax | 46.15 MHz | 53.90 MHz |
| WNS at 61.44 MHz | -5.39 ns | -3.04 ns |
| TNS | -1,255.92 ns | -773.60 ns |
| Violating reported endpoints | 909 | 542 |

The former worst 512-SRAM-Q waveform/control path disappears.  The overall
worst reported path is now the intentionally unresolved low-phase latch to FFT
SRAM GWEN setup path.  The worst edge-triggered path is 18.05 ns through the
shared multiplier/add/select arithmetic cone (slack -2.28 ns).  This is still
pre-layout and does not close 61.44 MHz.

## Future integration and power structure

Low-area future commands naturally attach to the idle scratch owner: ECHO uses
one payload register and serializer; MAGIC uses constant response muxing; SRAM
READ/WRITE reuse the 16-bit physical scratch port with a small address/data
register and idle-only ownership.  No opcodes are assigned here.  Extra DFT or
debug modes can reuse the command decode and shared butterfly but need a
separate area/timing study.

Natural future ICG enables exist for the butterfly/multiplier (idle during
capture/output), FFT controller (idle outside transform), DFT12 controller
(idle outside TX/standalone DFT), and serializers (idle outside output).  The
GF180 9-track library contains `icgtn_*` and `icgtp_*` cells.  No clock gates or
unsupported power claims were added.

## Decision

The two-SRAM architecture creates sufficient Padframe-A area headroom that
there is **no compelling area-only reason** to reduce the 16-bit datapath to
14 bits.  Its physical case is strong, but paced continuous-symbol throughput
falls to roughly 53--55% duty in the minimal controller.

**STRONG CANDIDATE — USER THROUGHPUT DECISION REQUIRED.**

Recommended next task: decide whether the measured ~53--55% allocation duty is
acceptable; if accepted, integrate the two-SRAM architecture as authoritative
and perform focused 61.44-MHz timing closure.  No such integration is performed
by this experiment.
