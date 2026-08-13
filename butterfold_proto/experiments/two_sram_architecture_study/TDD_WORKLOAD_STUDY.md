# Two-SRAM TDD and Workload Suitability Study

**Analysis only. The experimental RTL remains isolated and the authoritative
three-SRAM implementation is unchanged.**

## 1. Executive conclusion

The two-SRAM architecture is an architecturally strong option for a sparse or
moderately allocated, externally scheduled endpoint, but the project contains
no frozen traffic/allocation profile that proves this is the intended workload.
Its continuous-time service capacity is 54.38--54.56% for RX and 52.79--52.97%
for TX. More importantly, on an integer OFDM-symbol grid pure RX or pure TX
cannot use adjacent symbols, and the maximum indefinitely repeatable
grid-aligned allocation is exactly 1/2. A direction-aware analysis finds one
useful exception: **TX followed immediately by RX is legal**, because TX
releases scratch 13 clocks before the next symbol boundary. RX followed by TX
needs two blank symbols to provide TX preparation lead time. The architectural
decision is therefore **WORKLOAD REQUIREMENT
MUST BE DEFINED FIRST**. If the product requirement explicitly permits at most
one allocated symbol in every two and obeys the transition matrix below, the
two-SRAM design should be adopted with that testable duty-cycle specification;
otherwise the third SRAM is required.

## 2. Measured timing baseline

At 61.44 MHz, one cycle is 0.016276 us. A short symbol is 4,384 cycles or
71.354 us; a long symbol is 4,416 cycles or 71.875 us. The 12-short/2-long
14-symbol mixture is exactly 61,440 cycles or 1 ms.

The prior simulation logs were independently recomputed from their event
timestamps and component intervals:

| Mode | Input | Post-input / preparation | FFT/IFFT | Output | Scratch occupied / next command | Nominal symbol | Fluid allocation fraction |
|---|---:|---:|---:|---:|---:|---:|---:|
| RX short | 4,385 cyc, 71.370 us | 3,677 cyc, 59.847 us | 3,601 cyc, 58.610 us | 73 cyc, 1.188 us (inside post-input) | 8,062 cyc, 131.217 us | 4,384 cyc, 71.354 us | 4,384/8,062 = 54.38% |
| RX long | 4,417 cyc, 71.891 us | 3,677 cyc, 59.847 us | 3,601 cyc, 58.610 us | 73 cyc, 1.188 us (inside post-input) | 8,094 cyc, 131.738 us | 4,416 cyc, 71.875 us | 4,416/8,094 = 54.56% |
| TX short | 49 cyc, 0.798 us | 8,256 cyc, 134.375 us | 3,601 cyc, 58.610 us | 4,371 cyc, 71.143 us | 8,305 cyc, 135.173 us | 4,384 cyc, 71.354 us | 4,384/8,305 = 52.79% |
| TX long | 49 cyc, 0.798 us | 8,288 cyc, 134.896 us | 3,601 cyc, 58.610 us | 4,403 cyc, 71.663 us | 8,337 cyc, 135.693 us | 4,416 cyc, 71.875 us | 4,416/8,337 = 52.97% |

For RX, paced input duration is `payload_bytes * 16 + 1`: 274*16+1 =
4,385 and 276*16+1 = 4,417 cycles. Adding the measured 3,677-cycle
post-input interval yields 8,062/8,094. For TX, the measured 49-cycle FDIQ
capture plus 3,885 cycles through DFT/map/IFFT startup and 4,371/4,403 cycles
of paced scratch readout yields 8,305/8,337.

The 14-symbol short/long mixture gives a fluid capacity of 54.40% RX and
52.81% TX. Long CP changes the answer by less than 0.2 percentage point.

## 3. Exact scheduling constraint

The external scheduler may issue a new job only after the previous job's
scratch ownership is released and `din_ready_o` permits command acceptance:

* RX short/long: at least 8,062/8,094 clocks between command acceptances.
* TX short/long: at least 8,305/8,337 clocks between command acceptances.
* TX waveform start occurs 3,934 clocks after its command; command scheduling
  must include this preparation lead time.

These intervals are 1.833--1.894 symbol periods. Since scheduled air-interface
boundaries are integer symbol positions, pure RX and pure TX need alternating
allocations. Direction changes require the following testable separation:

| Prior allocation | Next allocation | Minimum symbol-start separation |
|---|---|---:|
| RX | RX | 2 symbols (one blank) |
| TX | TX | 2 symbols (one blank) |
| RX | TX | 3 symbols (two blanks) |
| TX | RX | 1 symbol (adjacent is legal) |

TX→RX is legal because TX readout takes 4,371/4,403 clocks versus a
4,384/4,416-clock symbol, releasing scratch 13 clocks early. RX→TX is not:
after RX releases scratch at 8,062/8,094 clocks, TX still needs 3,934 clocks
before its waveform can begin, pushing the next aligned TX allocation to the
third following symbol position.

This is stricter than quoting the fluid 53--55% service rate. The latter is
useful for non-grid asynchronous job streams, while the former controls actual
OFDM allocation patterns.

## 4. Sustainable allocation patterns

PASS requires both average capacity and compliance with the direction-specific
separation matrix, including the period wrap boundary. The table below first
considers a single repeated direction.

| Pattern | Density | Example repeating word | RX | TX | Reason |
|---|---:|---|---|---|---|
| 1/2 | 50.00% | `A-` | PASS | PASS | Two symbol periods exceed every measured interval |
| 2/3 | 66.67% | `AA-` | FAIL | FAIL | Contains adjacent assignments; average also too high |
| 3/5 | 60.00% | `A-A-A` | FAIL | FAIL | Period wrap creates adjacency; density too high |
| 4/7 | 57.14% | any 4 of 7 | FAIL | FAIL | Four nonadjacent positions cannot fit on a 7-cycle ring |
| 3/7 | 42.86% | `A-A-A--` | PASS | PASS | Minimum separation is two symbols |
| 4/9 | 44.44% | `A-A-A-A--` | PASS | PASS | Minimum separation is two symbols |
| 7/14 | 50.00% | `A-A-A-A-A-A-A-` | PASS | PASS | Slot-wide alternating maximum |

Patterns with the same average can differ: `AA--` fails despite being 50%,
while `A-A-` passes. Allocation spacing, not average alone, is the constraint.
A mixed 50% pattern can exploit the asymmetric transition: repeating
`RX--TX` (equivalently `TX RX--` at its wrap) passes because RX→TX has three
positions and TX→RX has one. Its average separation remains two symbols.

## 5. Burst behavior

The isolated experiment has one resident full-symbol store and no pending
waveform bank. It cannot pre-capture a second paced RX symbol or retain a prior
TX waveform while constructing the next IFFT.

| Requested consecutive burst | RX | TX |
|---:|---|---|
| 1 symbol | PASS | PASS |
| 2 symbols | FAIL at second allocation | FAIL at second allocation |
| 3, 4, 7, or 14 symbols | FAIL at second allocation | FAIL at second allocation |

Maximum same-direction paced consecutive burst length is therefore **one
symbol**. A two-symbol mixed burst `TX RX` is legal, but `RX TX` is not. One
unallocated symbol is sufficient between same-direction jobs; RX→TX requires
two. The small TX FDIQ/DFT storage could support a future look-ahead
controller, but the measured minimal experiment intentionally has no such job
queue, and adding one would not free scratch for the next IFFT.

## 6. TDD transitions

Direction switching neither adds a special penalty nor hides the current
job's scratch hold. The minimum safe transition is governed by the source job:

| Transition | Earliest next command | Grid rule |
|---|---:|---|
| RX-short -> TX | RX release at 8,062 cycles, then 3,934-cycle TX lead | two intervening unallocated symbols |
| RX-long -> TX | RX release at 8,094 cycles, then 3,934-cycle TX lead | two intervening unallocated symbols |
| TX-short -> RX | TX scratch release 4,371 cycles after TX waveform start | adjacent RX is legal; 13-cycle margin |
| TX-long -> RX | TX scratch release 4,403 cycles after TX waveform start | adjacent RX is legal; 13-cycle margin |

Representative patterns:

| Pattern | Result |
|---|---|
| `DL DL UL UL` | FAIL: the adjacent same-direction pairs violate scratch release |
| `DL - UL -` | FAIL: RX→TX separation is only two symbols |
| `DL DL - UL UL -` | FAIL at the second DL and second UL |
| `DL - - UL` repeated | PASS at 50%; RX→TX separation 3, TX→RX wrap separation 1 |
| `UL DL - -` repeated | PASS at 50%; same schedule rotated |
| DL-heavy with no adjacency | PASS up to 50% grid allocation |
| UL-heavy with no adjacency | PASS up to 50% grid allocation |
| isolated DL or UL | PASS; limitation is effectively irrelevant |

TX→RX can use the next boundary directly. RX→TX requires two blanks because
one provides scratch recovery and the other accommodates the next TX's
pre-air-time preparation. This is not a generic TDD guard requirement; it is a
two-SRAM ButterFold resource/lead-time constraint.

## 7. Workload classes

| Class | Suitability |
|---|---|
| A: isolated symbol followed by many idle symbols | Fully suitable; throughput limitation is irrelevant |
| B: occasional moderate bursts below 50% | Suitable with the separation matrix; same-direction adjacency and RX→TX adjacency are unsupported, while TX→RX adjacency is legal |
| C: sustained approximately 50% | Sustainable indefinitely with `A-` spacing |
| D: sustained above 55% | Unsustainable by both average service rate and symbol-grid spacing |
| E: near-continuous | Requires the three-SRAM architecture |

Between 50% and the fluid 52.8--54.6% rates, asynchronous non-grid jobs may be
serviceable, but a normal integer-symbol allocation cannot exploit that margin.
The neutral architectural threshold is therefore 50% for scheduled OFDM.

No current-project document specifies an expected mMTC/IoT allocation density,
burst-length distribution, or mandatory consecutive-symbol requirement. The
project only states that scheduling is external and operation is half-duplex.
No standards-compliance conclusion is made: whether a particular NR procedure
requires consecutive allocations remains unresolved and must be checked against
the chosen system profile, not inferred from this proof-of-concept RTL.

## 8. Schedule diagrams

Legend: `C` capture, `F` FFT/IFFT/DFT/map compute, `O` output/extraction,
`S` scratch owned, `-` unallocated. Vertical bars are symbol boundaries.

```text
Case 1, isolated RX:
air:      | RX body |    -    | optional next allocation
scratch:  | CCCCCCCC|FFFFFO   | free
command:  ^ RX                 ^ next legal

Case 2, isolated TX:
air:             | TX waveform |    -    | optional next allocation
scratch:  FFFFF  | OOOOOOOOOOOO| recovery| free
command:  ^ TX command (~3,934-cycle lead)          ^ next legal

Case 3, RX every other symbol:
air:      | RX | - | RX | - | RX | - |
scratch:  | C/F/O  | C/F/O  | C/F/O  |       PASS

Case 4, TX every other symbol:
air:      | TX | - | TX | - | TX | - |
scratch:  | F/O    | F/O    | F/O    |       PASS

Case 5, mixed RX/TX at 50%:
air:      | RX | - | - | TX | RX | - | - | TX |
scratch:  | C/F/O      | F/O |C/F/O       | F/O | PASS
note:       RX->TX has separation 3; TX->RX is adjacent

Case 6, attempted consecutive RX:
air:      | RX0 | RX1 | - |
scratch:  | C0/F0/O0----|
RX1:            ^ cannot capture; scratch still owns RX0

Case 7, attempted consecutive TX:
air:      | TX0 | TX1 | - |
scratch:  | F0/O0------|
TX1:            ^ cannot map/IFFT; TX0 waveform still reads scratch
```

## 9. What the third SRAM buys

The 512x8 waveform SRAM is a temporal decoupler, not arithmetic capacity. It
provides:

* RX look-ahead: symbol N+1 can be captured while N uses FFT scratch.
* TX overlap: N's waveform drains while N+1 performs DFT/map/IFFT preparation.
* Logical bank ownership separating waveform producer and consumer.
* One-command-per-symbol acceptance and arbitrary consecutive burst length.
* Continuous paced allocation up to 100% in either half-duplex direction.

The measured raw cost of this capability is 209,400 um^2 of SRAM plus 89,718
um^2 of associated cells, 299,119 um^2 total. Relative to the two-SRAM
grid-aligned 50% limit, this buys the remaining 50 percentage points of symbol
allocation and removes the no-adjacency rule: approximately 5,982 um^2 raw area
per recovered percentage point, though the real benefit is burst capability,
not a linear throughput commodity.

## 10. What eliminating the third SRAM buys

It saves 209,400 um^2 of hard macro, 89,718 um^2 of standard cells, and 299,119
um^2 combined raw area (30.25%). It removes waveform banks, ownership,
arbitration, copy/drain state, and the former waveform-SRAM-Q timing path. The
result is a single large-memory ownership model and substantially more routing,
CTS, debug, and clock-control headroom.

## 11. Area and future headroom

| Metric | Three SRAM | Two SRAM |
|---|---:|---:|
| SRAM area | 503,825.15 | 294,424.87 um^2 |
| Standard cells | 484,854.45 | 395,136.00 um^2 |
| Combined raw area | 988,679.60 | 689,560.87 um^2 |
| 20-um-halo utilization | 76.08% | 44.65% |
| Cell headroom to 60% | none at current three-SRAM planning point | 135,827 um^2 |
| Cell headroom to 65% | unavailable without exceeding current region | 180,074 um^2 |
| Cell headroom to 70% | unavailable without exceeding current region | 224,321 um^2 |

At the preferred 65% point, the architectural opportunity cost is therefore a
third SRAM versus about 180k um^2 of future standard-cell budget. That budget
can support, subject to separate synthesis, ICG infrastructure, scratch read/
write diagnostics, echo and chip-ID responses, extra transform/debug modes,
and substantially healthier routing/CTS margin.

## 12. Timing comparison

| Metric | Three SRAM | Two SRAM |
|---|---:|---:|
| Pre-layout minimum period | 21.67 ns | 18.55 ns |
| Estimated fmax | 46.15 MHz | 53.90 MHz |
| WNS at 61.44 MHz | -5.39 ns | -3.04 ns |
| TNS | -1,255.92 ns | -773.60 ns |

Neither design closes 61.44 MHz yet. The two-SRAM design is the better starting
point because the worst 512-SRAM-Q/control path disappears, WNS improves by
2.35 ns, and lower utilization gives physical optimization more freedom.

## 13. Clock-gating implications

No gates are inserted and no power saving is claimed.

| Phase | Butterfly | FFT controller | DFT controller | Input adapter | Output adapter | Scratch |
|---|---|---|---|---|---|---|
| RX capture | idle | idle | idle | active | idle | writes |
| RX FFT/extract | active | active | idle | idle | active only for extraction | read/write, then read |
| TX FDIQ/DFT/map | active during DFT | idle until IFFT | active | active during capture | idle | idle, then map writes |
| TX IFFT | active | active | idle | idle | idle | read/write |
| TX waveform output | idle | idle | idle | idle | active | reads |
| Inter-job idle | idle | idle | idle | idle | idle | idle |

These mutually exclusive phases offer clean future enables for butterfly,
FFT, DFT, and adapters, subject to a dedicated clock-gating implementation and
verification task.

## 14. Requirement recommendation

**WORKLOAD REQUIREMENT MUST BE DEFINED FIRST.**

The area, timing, and implementation evidence favors two SRAMs. However, the
repository does not define whether adjacent symbols or sustained allocation
above 50% is required. Calling the target merely “low-throughput mMTC/IoT” is
not a testable workload requirement.

The exact decision gate is:

* If total grid-aligned allocation is at most 50% and the transition matrix is
  acceptable, adopt two SRAMs with an explicit spec.
* If same-direction adjacency, RX→TX separation below three symbols, or
  sustained allocation above 50% is required, keep three SRAMs.

## 15. Proposed frozen throughput specification

If the project owner accepts two SRAMs, the proposed testable statement is:

> ButterFold supports externally scheduled, half-duplex, 15-kHz-SCS OFDM at a
> 61.44-MHz core clock and the full 1.92-Msample/s active waveform rate. The
> architecture guarantees a maximum sustained grid-aligned allocation density
> of 50% for RX, TX, or a mixed sequence. RX→RX and TX→TX starts require two
> symbol positions; RX→TX starts require three; TX→RX may be adjacent.
> Minimum command intervals are 8,062/8,094 clocks for
> short/long RX and 8,305/8,337 clocks for short/long TX. Commands presented
> earlier must remain asserted until accepted through `din_ready_o`.

The fluid, non-grid service capacities remain 54.38/54.56% RX and
52.79/52.97% TX, but they do not supersede the grid transition matrix.

## 16. Recommended next engineering task

Freeze a concrete external workload profile containing maximum allocation
density, maximum consecutive allocated-symbol burst, and required RX/TX
transition patterns, then test that profile against the two-SRAM acceptance
intervals. Do not promote either architecture until that single workload
decision is recorded.
