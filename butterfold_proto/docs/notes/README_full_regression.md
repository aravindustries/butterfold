# Complete ButterFold Scheduler Regression

This package runs every currently implemented scheduler mode in one simulation against the corrected `scheduler_ofdm_tx.sv` implementation.

## Commands covered

| Command | Mode | Tests |
|---|---|---:|
| `0x40` | FFT2 | Mixed into the 8-case FFT2/IFFT2 queue test |
| `0x41` | FFT128 | 5 blocks |
| `0x42` | IFFT128 | 5 blocks |
| `0x43` | IFFT2 | Mixed into the 8-case FFT2/IFFT2 queue test |
| `0x44` | FFT3 | 8 transforms |
| `0x45` | DFT12 | 8 transforms |
| `0x46` | OFDM_RX, 9-sample CP | 4 frames |
| `0x47` | OFDM_RX, 10-sample symbol-zero CP | 4 frames |
| `0x48` | DFT-s-OFDM TX, 9-sample CP | 5 frames |
| `0x49` | DFT-s-OFDM TX, 10-sample symbol-zero CP | 5 frames |

The suite performs one reset and then runs all sections sequentially. This also checks cross-mode cleanup and command-parser re-entry rather than testing every mode in an isolated simulation.

## Checks performed

The standalone transform checks verify exact fixed-point components, result radix, destination addresses, final-result indication, duplicate/missing output bins, and latency.

The OFDM_RX checks verify CP removal, all 128 natural-order FFT bins, silent 8-bit saturation, a continuous 256-byte output burst, and suppression of the parallel standalone-result interface.

The DFT-s-OFDM TX checks verify DFT12 precoding, mapping into bins 1 through 12 with DC unused, IFFT128, 9/10-sample CP insertion, exact prefix-to-tail copying, continuous byte output, silent saturation, and suppression of intermediate DFT12/IFFT128 results.

Directed cases include impulses, DC/constant data, tones, alternating patterns, QPSK/ramp inputs, low-amplitude random data, full-range random data, and saturation cases. The FFT2/IFFT2 section queues back-to-back mixed commands to exercise result metadata ordering.

## Run

From this directory:

```bash
make -f Makefile.full_regression run
```

Equivalent commands:

```bash
python3 gen_full_regression_vectors.py

iverilog -g2012 -Wall -s scheduler_full_regression_tb \
  -o sim_full_regression.out \
  scheduler_full_regression_tb.sv \
  scheduler_ofdm_tx.sv \
  mixed_radix_butterfly.sv \
  tdiq_input_cp_remove.sv \
  fdiq_output_adapter.sv \
  fdiq_input_adapter.sv \
  subcarrier_mapper.sv \
  tdiq_output_cp_insert.sv

vvp sim_full_regression.out
```

The final line should be:

```text
OVERALL RESULT: PASS
```

A combined waveform is written to:

```text
scheduler_full_regression_tb.vcd
```

## Vector generation

`gen_full_regression_vectors.py` runs the three existing bit-accurate generators and validates every generated file's line count. It also independently verifies that each TX prefix is an exact copy of the appropriate symbol tail.
