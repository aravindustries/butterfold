# Four-mode folded transform scheduler

Commands:

- `0x40`: FFT2
- `0x41`: FFT128
- `0x42`: IFFT128
- `0x43`: IFFT2

Two-point request format:

```text
command, x0_i, x0_q, x1_i, x1_q
```

FFT128/IFFT128 request format:

```text
command, sample[0].i, sample[0].q, ..., sample[127].i, sample[127].q
```

All input components are signed 8-bit Q1.7. Results are parallel signed 16-bit values with seven fractional bits.

IFFT2 uses the same unity-twiddle butterfly as FFT2, followed by an arithmetic right shift by one. A result-metadata FIFO tracks the inverse bit for each issued two-point operation, so FFT2 and IFFT2 commands can be interleaved and pipelined safely.

IFFT128 conjugates the forward twiddle ROM and applies an arithmetic right shift by seven to final-stage results.

## Generate vectors

```bash
python3 gen_all_mode_vectors.py
```

## Compile and run

Keep the existing `two_point_dft.sv` in the same directory, then run:

```bash
iverilog -g2012 -Wall \
  -o sim_all_modes.out \
  scheduler_all_modes_tb.sv \
  scheduler_all_modes.sv \
  two_point_dft.sv

vvp sim_all_modes.out
```

Or rename `Makefile.all_modes` to `Makefile` and run `make`.
