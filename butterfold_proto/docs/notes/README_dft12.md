# Mixed-Radix Scheduler with DFT12

## Commands

| Command | Operation |
|---|---|
| `0x40` | FFT2 |
| `0x41` | FFT128 |
| `0x42` | IFFT128 |
| `0x43` | IFFT2 |
| `0x44` | FFT3 |
| `0x45` | DFT12 |

## DFT12 byte stream

Send `0x45`, followed by 12 natural-order complex samples:

```text
x[0].i, x[0].q, x[1].i, x[1].q, ... x[11].i, x[11].q
```

Each component is signed 8-bit Q1.7. Internally, samples are sign-extended to
16-bit signed values with seven fractional bits.

## DFT12 architecture

The implementation uses the Good-Thomas prime-factor algorithm for
`12 = 3 x 4`. Since 3 and 4 are coprime, the decomposition requires no
inter-stage `W12` twiddle multiplications.

The schedule is:

1. Four radix-3 DFTs using input CRT mapping
   `n = 4*n1 + 9*n2 mod 12`.
2. Three radix-4 DFTs. Each FFT4 is realized with four existing radix-2
   butterflies.
3. Natural-order output address mapping
   `k = 4*k1 + 3*k2 mod 12`.

Total mixed-radix core operations:

```text
4 radix-3 operations + 12 radix-2 operations = 16 operations
```

No new complex multiplier and no 12-point twiddle ROM are added. The only
coefficients used are already supported by the core:

- radix-3 coefficient `-j*sqrt(3)/2`, quantized as `(0, -111)` in Q1.7;
- exact unity through the existing `W=-1`, `x1=-x1` proxy;
- exact FFT4 coefficient `-j`, represented as `(0, -128)` in Q1.7.

## DFT12 output

The final FFT4 stage produces six parallel radix-2 result transactions. Each
transaction carries two bins and their natural-order addresses.

```text
transaction 0: bins 0, 6
transaction 1: bins 3, 9
transaction 2: bins 4, 10
transaction 3: bins 7, 1
transaction 4: bins 8, 2
transaction 5: bins 11, 5  (result_last_o = 1)
```

Downstream RTL must write `X0` and `X1` using `result_addr0_o` and
`result_addr1_o`. `result_radix_o` is 2 for these final transactions.

## Generate vectors

```bash
python3 gen_dft12_vectors.py
```

This regenerates all previous mode vectors plus:

```text
vectors/dft12_inputs.hex
vectors/dft12_expected.hex
vectors/dft12_numpy_reference.csv
```

The exact golden model reproduces the fixed-point RTL schedule, including the
Q1.7 radix-3 coefficient and arithmetic shifts. The NumPy CSV is for numerical
quality comparison only.

## Compile and run

```bash
iverilog -g2012 -Wall \
    -o sim_dft12.out \
    scheduler_dft12_tb.sv \
    scheduler_dft12.sv \
    mixed_radix_butterfly.sv

vvp sim_dft12.out
```

Waveforms:

```bash
gtkwave scheduler_dft12_tb.vcd
```
