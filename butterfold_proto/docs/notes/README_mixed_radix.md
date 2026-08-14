# Mixed-Radix FFT2/IFFT2/FFT3/FFT128/IFFT128 Prototype

## Commands

- `8'h40`: FFT2, followed by `x0_i x0_q x1_i x1_q`
- `8'h41`: FFT128, followed by 128 interleaved complex samples
- `8'h42`: IFFT128, followed by 128 interleaved complex samples
- `8'h43`: IFFT2, followed by `x0_i x0_q x1_i x1_q`
- `8'h44`: FFT3, followed by `x0_i x0_q x1_i x1_q x2_i x2_q`

All stream components are signed 8-bit Q1.7 codes. Internal and output components are signed 16-bit values retaining seven fractional bits.

## Files

- `mixed_radix_butterfly.sv`: latency-insensitive radix-2/radix-3 arithmetic core
- `scheduler_mixed_radix.sv`: parser, small-transform FIFO, result metadata, FFT128/IFFT128 folded scheduler
- `scheduler_mixed_radix_tb.sv`: self-checking regression for all five modes
- `gen_mixed_radix_vectors.py`: bit-accurate fixed-point golden model and vector generator
- `vectors/`: generated test and twiddle files

## Radix-3 identity

The core computes a three-point forward DFT as:

```
s    = x1 + x2
d    = x1 - x2
base = x0 - s/2
t    = (-j*sqrt(3)/2) * d

X0 = x0 + s
X1 = base + t
X2 = base - t
```

The existing complex multiplier is reused for both radix modes:

- radix-2: `W*x1`
- radix-3: `(-j*sqrt(3)/2)*(x1-x2)`

The Q1.7 radix-3 coefficient is `(0, -111)`, corresponding to approximately `-j*0.8671875`.

## Generate vectors

```bash
python3 gen_mixed_radix_vectors.py
```

## Compile and run with Icarus

```bash
iverilog -g2012 -Wall \
  -o sim_mixed.out \
  scheduler_mixed_radix_tb.sv \
  scheduler_mixed_radix.sv \
  mixed_radix_butterfly.sv

vvp sim_mixed.out
```

## Waveforms

```bash
gtkwave scheduler_mixed_radix_tb.vcd
```
