# ButterFold Two-SRAM Production Integration Report

## 1. Architectural decision

The validated two-SRAM design is now the production ButterFold architecture.
It retains the 16-bit Q7-fractional datapath, the one-scalar folded butterfly,
and the modulo-8 FFT engine, while eliminating the dedicated waveform SRAM and
its bank/copy/arbitration logic.  RX samples are written directly to shared
scratch and TX samples are read directly from it.  This trades arbitrary
consecutive symbol allocation for 299,119 um^2 of measured raw macro-plus-cell
saving in the pre-debug comparison and much healthier placement margin.

Historical three-SRAM and workload-study reports remain in the repository to
document this decision.  Production builds no longer instantiate or time a
512x8 macro.

## 2. Frozen throughput specification

At 61.44 MHz with 15-kHz numerology, ButterFold supports externally scheduled,
half-duplex operation with at most 50% sustained grid-aligned symbol allocation.
This is a symbol-allocation restriction, not reduced FFT or waveform sample
rate.  The testable symbol-start rules are:

| Previous allocation | Next allocation | Earliest start |
|---|---:|---:|
| RX | RX | +2 symbol positions (one blank) |
| TX | TX | +2 symbol positions (one blank) |
| RX | TX | +3 symbol positions (two blanks) |
| TX | RX | +1 symbol position (adjacent legal) |

The measured non-grid fluid capacities remain 54.38--54.56% RX and
52.79--52.97% TX.  The frozen grid contract deliberately rounds this down to
the indefinitely sustainable 50% pattern.

## 3. Final memory architecture and ownership

Production elaboration contains exactly two
`gf180mcu_fd_ip_sram__sram256x8m8wm1` instances and zero 512x8 instances.  The
two byte macros operate in parallel as one synchronous, single-port 256x16
physical half-word memory.  Complex sample `n` occupies address `2n` for I and
`2n+1` for Q.

Scratch ownership is mutually exclusive and phase-derived:

| Owner | Access | Address/data source | Read consumer | Entry / release |
|---|---|---|---|---|
| RX capture | write | bit-reversed sample address, sign-extended I/Q | none | RX body / final body half-word |
| FFT/IFFT | read/write | modulo-8 controller | butterfly/controller | transform start / final write drain |
| TX waveform | read | CP/body sequencer | two-byte output serializer | TX output start / last Q byte |
| Standalone diagnostic | read through transform result protocol | transform address | diagnostic serializer | diagnostic transform / last result |
| SRAM debug read | read | captured 8-bit debug address | debug response register | idle debug request / read response |
| SRAM debug write | write | captured address and 16-bit payload | none | idle debug request / accepted write |
| Idle | none | none | none | all other phases |

The fixed priority at the physical port is transform, TX waveform, then
idle-only debug.  Consequently debug selection does not arbitrate with an
active transform.  The direct RX mapping remains natural time order to
bit-reversed scratch addresses to iterative DIT FFT to natural output bins.
Direct TX remains DFT12, natural subcarrier map, IFFT, then samples 119--127
(short CP) or 118--127 (long CP), followed by samples 0--127.

## 4. Production command table

Multi-byte 16-bit debug data is big-endian (high byte, then low byte).  Existing
diagnostic transform records retain their established five-byte format.

| Opcode | Name | Input bytes after opcode | Output bytes | Purpose | Scratch required |
|---:|---|---:|---:|---|---|
| 0x40 | FFT2 | 4 | 10 | 2-point FFT diagnostic | no full scratch |
| 0x41 | FFT128 | 256 | 640 | full FFT diagnostic | yes |
| 0x42 | IFFT128 | 256 | 640 | full IFFT diagnostic | yes |
| 0x43 | IFFT2 | 4 | 10 | 2-point IFFT diagnostic | no full scratch |
| 0x44 | FFT3 | 6 | 15 | 3-point diagnostic | no full scratch |
| 0x45 | DFT12 | 24 | 60 | 12-point DFT diagnostic | no full scratch |
| 0x46 | OFDM RX short | 274 | 24 | 9-sample CP RX | yes |
| 0x47 | OFDM RX long | 276 | 24 | 10-sample CP RX | yes |
| 0x48 | OFDM TX short | 24 | 274 | 9-sample CP TX | yes |
| 0x49 | OFDM TX long | 24 | 276 | 10-sample CP TX | yes |
| 0x4A | ECHO | 1 | 1 | byte-stream sanity check | no |
| 0x4B | MAGIC | 0 | 4 | silicon identity | no |
| 0x4C | SRAM READ | 1 address | 2 | logical 256x16 read | idle only |
| 0x4D | SRAM WRITE | address, high, low | 1 | logical 256x16 write | idle only |

Opcodes 0x4E--0xFF are available for future commands; 0x00--0x3F remain
unassigned/invalid.  No speculative future opcode has been reserved.

## 5. ECHO protocol

`4A pp` returns exactly `pp`.  It does not start arithmetic or access scratch.
The regression verifies `4A A5 -> A5` and command-boundary operation around
transform/debug commands.

## 6. MAGIC protocol

Opcode `4B` returns four bytes `42 46 4C 44`, ASCII `BFLD`, in that order.
The response is a literal independent of memory and arithmetic state.

## 7. SRAM READ/WRITE protocol

The visible memory is logical address 0--255, width 16.  `4D aa hh ll` performs
one write and returns the single completion byte `AC`.  `4C aa` issues the
synchronous read and returns `hh ll`.  Commands are accepted only while the
top-level command engine is idle; `din_ready_o` provides backpressure during
active work.  A comprehensive behavioral and foundry-model sweep covers all
256 addresses with zero, ones, alternating patterns, walking patterns, and a
deterministic address-dependent pattern.

## 8. Verification matrix

| Test | Behavioral SRAM | Official GF SRAM | Result |
|---|---|---|---|
| FFT2 / IFFT2 / FFT3 / DFT12 | PASS | PASS | bit-exact |
| FFT128 / IFFT128 | PASS | PASS | bit-exact |
| OFDM RX short/long | PASS | PASS | zero mismatches |
| OFDM TX short/long | PASS | PASS | zero mismatches |
| ECHO / MAGIC | PASS | PASS | exact bytes |
| SRAM fixed/walking/all-address sweep | PASS | PASS | exact readback |
| Transforms after arbitrary debug writes | PASS | PASS | no stale-data leakage |
| Fast ping-pong/backpressure stress | PASS | PASS in full foundry regression | no loss/corruption |
| 61.44-MHz paced TX stress | PASS | PASS in full foundry regression | exact pacing/output |
| Scheduled interval assertions | PASS | n/a | exact measured intervals |
| Reset recovery matrix | PASS | n/a | defined idle recovery |

The old continuous tests were retained.  They remain numerically correct by
honoring `din_ready_o`; their old one-allocation-per-symbol throughput criterion
is historical rather than the new production requirement.

## 9. Reset behavior

The reset-recovery failure in the isolated experiment was a testbench race:
the driver changed input with blocking assignments on the same positive edge
on which the DUT sampled it.  The bench now drives on the negative edge,
samples acceptance on the positive edge, and releases on the following
negative edge.  No RTL reset ambiguity was required to explain the failure.

Reset coverage includes idle, command capture, partial payload, RX capture,
FFT compute, TX output, partial SRAM write, SRAM read, ECHO/MAGIC output, and
between-job reset.  After each reset, `din_ready_o` is asserted,
`dout_valid_o` is clear, scratch/debug ownership is idle, and no stale output
appears.  Payload RAM/register contents need not be cleared because control and
valid state protect them.

## 10. FFT performance

The arithmetic core and modulo controller are unchanged.  Production OFDM
FFT/IFFT compute start-to-done is 3,601 cycles, with steady compute and result
cadence of eight cycles per butterfly.  Standalone diagnostic command latency
also includes result-stream backpressure and must not be confused with the
core compute interval.

## 11. Scheduling performance

The validated paced command intervals are 8,062/8,094 cycles for RX
short/long and 8,305/8,337 for TX short/long, giving 54.38/54.56% and
52.79/52.97% fluid capacity.  Grid-aligned regressions enforce the transition
matrix in Section 2.  Fast-input instrumentation measures RX feeder intervals
4,226/4,230 and TX 4,210/4,212; paced TX measures 8,305/8,337.  Illegal early
input is retained by the source while `din_ready_o` is low and is accepted
without loss when ownership becomes available.

## 12. Synthesis area

The audited GF180 ss_125C_4v50 flow reports:

| Metric | Validated two-SRAM pre-debug | Integrated production | Delta |
|---|---:|---:|---:|
| Standard-cell area | 395,136.000 | 407,373.926 um^2 | +12,237.926 (+3.10%) |
| Reset DFFs | 1,240 | 1,314 | +74 |
| Non-reset DFFs | 544 | 544 | 0 |
| Latches | 27 | 27 | 0 |
| Mux2 | 1,683 | 1,878 | +195 |
| Mux4 | 145 | 119 | -26 |

The final mapped design contains 11,502 cells including exactly two SRAM
blackboxes.  Sequential-cell area is 162,378.317 um^2.  The debug increase is
small relative to the available two-SRAM floorplan margin; no waveform-sized
register store was introduced.

## 13. Floorplan budget

With two 256x8 macros and 20-um planning halos, the provisional standard-cell
region is 884,937.926 um^2.  Final synthesized utilization is 46.03%.

| Planning utilization | Maximum cells | Remaining headroom |
|---:|---:|---:|
| 60% | 530,962.756 | 123,588.829 um^2 |
| 65% | 575,209.652 | 167,835.726 um^2 |
| 70% | 619,456.548 | 212,082.622 um^2 |

The 65% figure is not wholly a feature budget.  A substantial fraction should
remain reserved for timing buffers, CTS, ICG cells/control, tap/endcap/decap,
routing congestion, and late ECOs.

## 14. Pre-layout timing baseline

At 61.44 MHz (16.276 ns), audited synthesis-level STA reports WNS -3.04 ns,
TNS -1,082.99 ns, a minimum edge-triggered period of 18.89 ns, and estimated
edge-triggered fmax 52.94 MHz.  The worst edge-triggered path starts at
`mixed_radix_butterfly.multiply_phase[0]`, crosses multiplier arithmetic and
selection logic, and arrives at a result register with -2.61 ns slack.

The overall -3.04-ns path is a low-phase latch-to-SRAM-control path.  Its
pre-layout latch/time-borrowing treatment remains unresolved and is not a
post-route hold/setup conclusion.  Debug nets do not appear in the reported
top critical paths, so idle-only debug arbitration did not displace the active
arithmetic critical path.  Compared with the pre-debug two-SRAM snapshot
(18.55 ns, 53.90 MHz, WNS -3.04 ns, TNS -773.60 ns), debug adds modest timing
load but does not alter the architectural bottleneck.  Timing is not closed.

## 15. Clock-gating opportunities (not implemented)

| Domain | RX capture | Compute | TX output | Idle | Existing enable candidate |
|---|---:|---:|---:|---:|---|
| Butterfly/scalar multiplier | off | on | off | off | operation valid / multiply phase |
| FFT controller | off | on for FFT/IFFT | off | off | modulo active |
| DFT12 controller | off | on for DFT | off | off | DFT state valid |
| RX capture | on | off | off | off | RX capture state |
| TX serializer/CP reader | off | off | on | off | TX output busy |
| Command/debug engine | command only | mostly off | mostly off | decode/debug | top state/debug mode |

These phase-exclusive enables are suitable inputs to a later GF180 ICG study;
no power saving is claimed without activity-based power analysis.

## 16. Remaining opcode and architecture margin

The contiguous 0x4E--0xFF range supports future checksum/BIST, status, cycle
counter, and characterization commands without changing pins.  Additional
transform modes are intentionally deferred.  The current integration preserves
the frozen 22-pin logical interface, one scalar multiplier, one shared
butterfly, 128-point FFT/IFFT, and 12-point DFT.

## 17. Final verdict

| Criterion | Verdict |
|---|---|
| Authoritative two-SRAM integration | PASS |
| 16-bit numerical behavior | PASS |
| Two SRAM macros only | PASS |
| Eight-cycle FFT | PASS |
| 50% grid-aligned scheduling contract | PASS |
| ECHO | PASS |
| MAGIC | PASS |
| SRAM READ | PASS |
| SRAM WRITE | PASS |
| Reset recovery | PASS |
| Provisional utilization comfortably below 65% | YES (46.03%) |
| Ready for timing-closure task | YES, at pre-layout RTL/synthesis scope |

The next engineering task is a focused 61.44-MHz timing-closure pass on this
integrated two-SRAM production design, preserving area reserve for the later
clock-gating and physical-implementation work.
