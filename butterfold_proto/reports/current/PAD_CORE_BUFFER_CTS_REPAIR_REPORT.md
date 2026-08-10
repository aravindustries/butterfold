# Pad-to-core buffering and CTS-root repair

## 1. Baseline failure

The direct-pad candidate failed before CTS.  The reproduced limiting path was
`u_pad_din1/Y` on the `core_din_pad[1]` family: the `gf180mcu_fd_io__in_c`
1.0 ns maximum-transition constraint could not be met; the best resizer result
was 2.722 ns with 2.90 pF load.  This was not the historical `din[7]` hold
path.  The subsequent approximately -53.9 ns CTS report was invalid.

The 2.90 pF was the lumped pre-CTS load of the directly connected synthesized
core input cone: receiver pins plus estimated long internal routing.  It was
not an intrinsic pad capacitance and was not caused by the two SRAMs.  The
clock pad had the analogous, worse structural error: `in_c/Y` was the source
of a 2,005-register pre-CTS clock net.  The root cause is therefore a
combination of excessive direct fanout/routing and an incorrect CTS boundary.

## 2. Buffer-cell study

Values below come from the installed TT Liberty and LEF.

| Cell | Input cap (pF) | Max output cap (pF) | Area (um2) | Use |
|---|---:|---:|---:|---|
| `buf_1` | 0.003859 | 0.3618 | 16.934 | pad isolation |
| `buf_4` | 0.01370 | 1.457 | 39.514 | candidate taper |
| `buf_8` | 0.02763 | 2.901 | 73.382 | data/control distribution |
| `buf_16` | 0.05531 | 5.788 | 141.120 | reset root |
| `clkbuf_1` | 0.003273 | 0.3626 | 16.934 | clock-pad isolation |
| `clkbuf_4` | 0.01106 | 1.455 | 39.514 | CTS candidate |
| `clkbuf_8` | 0.02208 | 2.907 | 73.382 | CTS branches |
| `clkbuf_16` | 0.04440 | 5.798 | 141.120 | CTS root |

The small-to-large two-stage data chain was the smallest bounded candidate
that isolated the pad and drove the synthesized core cone robustly.  A large
buffer directly on `in_c/Y` was rejected because its own input capacitance
unnecessarily consumed pad margin.

## 3. Retained pad/core architecture

Data and valid use:

```
external pad -> in_c -> buf_1 -> buf_8 -> frozen core input
```

Clock uses:

```
external clock -> in_c -> clkbuf_1 -> CTS-inserted clkbuf_16 root
               -> 3 macro-tree buffers / 125 register-tree buffers
               -> 4 latency-balance buffers -> sinks
```

Reset uses `in_c -> buf_1 -> buf_16`; `repair_design` constructs the remaining
reset distribution while preserving the core's asynchronous-reset semantics.
The old special `din[7]` two-`buf_1` repair is **MODIFIED**: all nine
synchronous inputs now have uniform isolation/distribution, and extracted
hold repair inserted `dlyc_1` cells where the actual fast-corner paths needed
them (the worst final path is on `din[3]`).

## 4. Input-pad electrical audit

Every `in_c/Y` has fanout one and sees approximately one first-stage input
capacitance plus a short local route (reported capacitance rounds to 0.00 pF).
With the explicit pad-level input-slew contract of at most 0.25 ns, the SS
extracted worst rise/fall slews are approximately 0.28/0.14 ns.  No `in_c`
appears in the SS, TT, or FF max-slew violator report.

| Signal | First load | Fanout | Worst core-side transition (ns) | Limit (ns) | Status |
|---|---|---:|---:|---:|---|
| `clk` | `clkbuf_1` (0.003273 pF) | 1 | 0.28 | 1.00 | PASS |
| `rst_n` | `buf_1` (0.003859 pF) | 1 | 0.28 | 1.00 | PASS |
| `din[7:0]` (each) | `buf_1` (0.003859 pF) | 1 | 0.28 | 1.00 | PASS |
| `din_valid_i` | `buf_1` (0.003859 pF) | 1 | 0.28 | 1.00 | PASS |

The external slew condition is essential: at the earlier 0.50 ns input slew,
the SS Liberty arc itself produced roughly 1.52--1.72 ns even at negligible
load.  Buffering alone cannot repair slew generated inside the pad cell.

## 5. CTS failure diagnosis and repaired clock

The -53.9 ns result came from applying CTS/timing propagation at the external
pad net while the pad output was also treated as the high-fanout core clock.
The resulting model mixed the I/O timing arc, an unbuffered 2,005-sink net,
and the CTS root.  It was a broken clock-root model, not ButterFold latency.

The repaired model has one clock (`pad_clk_ext`) created at the external pad
port.  Its propagated path includes the `in_c` arc once, then `u_clk_iso`, then
the CTS-inserted root and tree.  At SS the representative clock-pad delay is
1.67 ns, isolation delay 1.28 ns, CTS root/branch/tree delay approximately
2.3 ns, and sink insertion approximately 5.25--5.30 ns.  Setup skew is
0.17 ns and hold skew is -0.11 ns.  The tree uses 132 CTS/balance buffers in
addition to the wrapper isolation stage.  All clock slews/capacitances are
legal.  **CLOCK ROOT MODEL: VALID.**

## 6. Physical implementation

| Stage | Result |
|---|---|
| placement | PASS |
| CTS | PASS |
| global route | PASS with reported congestion handled by iterative guides |
| detailed route | PASS |
| routing DRC | 0 violations |

The extracted database contains exactly two
`gf180mcu_fd_ip_sram__sram256x8m8wm1` instances and no 512x8 SRAM.

## 7. Extracted multi-corner timing

The candidate contract is 3.50 ns input setup, 0.10 ns input hold, 0.25 ns
maximum input slew, and a 22.28 ns output-max envelope (the SDC equivalent is
`set_output_delay -max -6.0`).  Package parasitics are not included.

| Corner | RC | Setup WNS/TNS (ns) | Hold WNS/TNS (ns) | Internal setup | SRAM setup/hold |
|---|---|---|---|---:|---:|
| SS 4.50 V 125 C | max | +0.00 / 0.00 | +0.72 / 0.00 | +0.10 | +1.01 / positive |
| TT 5.00 V 25 C | nominal | +7.44 / 0.00 | +0.27 / 0.00 | positive | positive |
| FF 5.50 V -40 C | min | +10.68 / 0.00 | +0.09 / 0.00 | positive | +setup / +0.14 |

The SS zero-margin endpoint is `din_ready_o`; it meets the candidate output
envelope exactly.  The worst internal SS setup path has +0.10 ns.  The
critical input hold path is `pad_din[3] -> u_core/_20905_` at +0.09 ns in FF.
DFT12, scalar-multiplier, and SRAM paths remain nonviolating; the physical
database does not preserve stable RTL signal names sufficient to quote the
old DFT/multiplier subfamily slacks independently.

## 8. External contract status

The raw extracted input requirements are approximately 2.03 ns setup and
0.01 ns hold.  Candidate specifications are 3.50 ns setup and 0.10 ns hold,
providing 1.47 ns and 0.09 ns margins respectively.  Maximum input slew is
0.25 ns.  These input requirements are physically supported.

At 5 pF, output min/max clock-to-pad values are approximately 4.30/22.13 ns.
However, even `bi_t` at `PDRV=11` reports 4.61 ns PAD slew against its 1.0 ns
Liberty limit at 5 pF.  The characterized SS PDRV=11 slew remains 2.32 ns even
at 0.5 pF.  Therefore the complete external interface is **PROVISIONAL**;
the input and clock repair is signed off, but the output-pad electrical model
is not.  The 5 pF output contract must not be frozen yet.

## 9. Area

The routed database reports 781,117 um2 for standard cells plus two SRAMs.
Decomposition from physical masters gives approximately 486,692 um2 standard
cells and 294,425 um2 SRAM.  Clock buffers occupy about 13,254 um2 and
inserted `dlyc_1` hold cells about 903 um2.  The explicit nine input chains
occupy about 813 um2, clock isolation 16.9 um2, and reset isolation/root
158.1 um2.  Standard-cell utilization of the approximately 884,938 um2 legal
cell region is about 55.0%, consistent with the earlier 54.76% routed result.

## 10. Verification

| Test | Result |
|---|---|
| wrapper reset/ECHO/MAGIC/SRAM write-read/FFT2/bit map | PASS |
| FFT2/IFFT2/FFT3/DFT12/FFT128/IFFT128 | PASS, bit-exact |
| OFDM RX short/long | PASS, bit-exact |
| OFDM TX short/long | PASS, bit-exact |
| ECHO/MAGIC/SRAM READ/WRITE/full sweep | PASS |
| behavioral SRAM | PASS |
| official GF180 SRAM | PASS |
| reset recovery | PASS |

## 11. Final verdict

```
All in_c transitions legal:             YES (requires <=0.25 ns pad input slew)
Clock-root architecture valid:          YES
CTS timing credible:                    YES
Detailed route:                         PASS
DRC:                                    PASS (0)
61.44-MHz setup:                        PASS under candidate I/O contract
61.44-MHz hold:                         PASS under 0.10 ns input-hold contract
Pad-level interface specification:      PROVISIONAL
READY FOR CLOCK GATING:                 NO
```

Production core RTL was not modified.  Precision remains 16 bit; the design
retains two 256x8 SRAMs, one scalar multiplier, one shared butterfly, FFT
II=8, FFT128/IFFT128=3,601 cycles, the 22-pin logical interface, and the
unchanged debug protocol.

## 12. Recommended next task

Perform one focused **GF180 output-pad electrical selection/load-closure
study** to replace or correctly constrain `bi_t` so every output PAD meets its
actual slew/load limits; then reroute and re-run the same extracted corner
matrix.  Do not begin clock gating until that boundary is closed.
