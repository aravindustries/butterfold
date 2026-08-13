# Externally Scheduled Symbol Area Experiment

AREA STUDY ONLY. The single-active-symbol RTL experiment was rejected and the
continuous-capable authoritative RTL was restored.

## Experimental change

The experiment retained the three SRAM macros and active-symbol datapaths, but
replaced symbol-level overlap control with one active job and fixed waveform
logical bank 0. It removed the two-entry job queue, two-entry output queue,
waveform-bank ownership array, TX/RX small-bank ownership bits, future-bank
selection, and direct result-queueing metadata. The two-byte TX read prefetch
was retained because it is required to sustain the active 16-clock byte pace.

## Results

| Metric | Continuous baseline | Single-active experiment |
|---|---:|---:|
| Standard-cell area | 484,854.4512 um^2 | 476,638.4448 um^2 |
| Area saving | - | 8,216.0064 um^2 (1.69%) |
| DFFQ | 789 | 753 |
| DFFRNQ | 1,375 | 1,370 |
| Mux2_1 | 1,553 | 1,820 |
| Mux4_1 | 169 | 125 |
| WNS at 61.44 MHz | -5.39 ns | -3.09 ns |
| TNS | -1,255.92 ns | -873.16 ns |
| Minimum period | 21.67 ns | 19.37 ns |

The experiment remained bit-exact. Measured command acceptance intervals were:

| Operation | Fast output | 16-clock paced output |
|---|---:|---:|
| RX short | 4,526 cycles | 4,526 cycles |
| RX long | 4,532 cycles | 4,532 cycles |
| TX short | 4,512 cycles | 8,607 cycles |
| TX long | 4,516 cycles | 8,641 cycles |

The old stress test still completed because the byte-stream handshake applied
backpressure, but its initiation intervals no longer met continuous-symbol
budgets. The paced TX inter-symbol boundary gap increased to 4,241 cycles.

## Decision

REJECT. The area remains above 470,000 um^2, saving only 8,216 um^2 of the
required 34,854 um^2. Paced TX allocation density falls to approximately 51%.
The authoritative continuous-capable scheduling architecture is therefore
retained.
