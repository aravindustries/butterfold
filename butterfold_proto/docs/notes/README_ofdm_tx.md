# DFT-s-OFDM TX integration

This package extends the existing mixed-radix scheduler with two DFT-s-OFDM transmit commands while retaining every previously implemented standalone transform and both OFDM receive commands.

## Command map

| Command | Operation |
|---|---|
| `0x40` | FFT2 |
| `0x41` | FFT128 |
| `0x42` | IFFT128 |
| `0x43` | IFFT2 |
| `0x44` | FFT3 |
| `0x45` | DFT12 |
| `0x46` | OFDM_RX, 9-sample CP removal |
| `0x47` | OFDM_RX, 10-sample CP removal |
| `0x48` | DFT-s-OFDM TX, 9-sample CP insertion |
| `0x49` | DFT-s-OFDM TX, 10-sample CP insertion |

A TX request contains one command byte followed by exactly 12 complex frequency-domain samples. Each sample is interleaved signed Q1.7: `I`, then `Q`.

```text
0x48 or 0x49
D[0].I,  D[0].Q
...
D[11].I, D[11].Q
```

The normal-CP command produces 274 bytes. The extended-CP command produces 276 bytes. Output is continuous once `dout_valid_o` first asserts, and the downstream is assumed always ready.

## Datapath

```text
12 complex FDIQ samples
        |
        v
fdiq_input_adapter
        |
        v
existing fixed-point DFT12
        |
        v
subcarrier_mapper
  - clear 128-bin grid
  - map D[0:11] to natural bins 1:12
  - write bit-reversed physical addresses
        |
        v
existing normalized IFFT128
        |
        v
tdiq_output_cp_insert
  - output samples 119:127 or 118:127
  - output samples 0:127
  - saturate to signed 8-bit Q1.7
```

## Hardware reuse

No new transform arithmetic is added. The TX path reuses:

- The existing four-radix-3 plus twelve-radix-2 DFT12 schedule.
- The existing 448-operation IFFT128 schedule.
- The mixed-radix butterfly and its one shared complex multiplier.
- The existing Q1.7 FFT128 twiddle ROM.
- The 12-entry DFT scratch RAM.
- The 128-entry FFT/IFFT scratch RAM.
- The established final-stage `1/128` IFFT normalization.

The new hardware is control and data movement:

- `fdiq_input_adapter.sv`: collects 12 interleaved Q1.7 samples.
- `subcarrier_mapper.sv`: zero-fills the 128-bin grid and maps the 12 DFT outputs.
- `tdiq_output_cp_insert.sv`: repeats the symbol tail as CP and serializes the result.
- New global scheduler ownership flags for internal DFT12 and IFFT128 results.

## Initial subcarrier allocation

The first implementation maps the natural-order DFT12 outputs to natural IFFT bins 1 through 12:

```text
D[0]  -> bin 1
D[1]  -> bin 2
...
D[11] -> bin 12
```

Bin 0 remains zero. The mapper is parameterized by `SC_START_BIN`, so this allocation can be moved without modifying either transform engine.

The mapper writes each occupied natural bin to `bit_reverse7(bin)` because the existing iterative radix-2 DIT IFFT consumes bit-reversed input placement and produces natural-order time samples.

## Global schedule

The TX command owns the shared datapath until its complete output burst has been emitted:

1. Capture 12 FDIQ samples into `dft12_ram`.
2. Run DFT12 internally; suppress the standalone result interface.
3. Capture the 12 natural-order DFT results back into `dft12_ram`.
4. Clear all 128 IFFT RAM locations.
5. Map the 12 DFT results into bins 1 through 12 at bit-reversed physical addresses.
6. Run IFFT128 internally with inverse twiddles and final `>>> 7` normalization.
7. Store all 128 natural-order time samples in `fft_ram`.
8. Emit the CP followed by the complete symbol.
9. Return to command parsing.

The scheduler does not accept a new command during DFT-s-OFDM TX computation or output.

## Cyclic prefix insertion

Normal CP (`0x48`) reads:

```text
119, 120, ..., 127, 0, 1, ..., 127
```

Extended CP (`0x49`) reads:

```text
118, 119, ..., 127, 0, 1, ..., 127
```

The same RAM samples are read twice, so the prefix is an exact copy of the tail before output saturation. Since both occurrences pass through the same saturation function, their output bytes are also exactly equal.

## Fixed-point behavior

- External input: signed 8-bit Q1.7.
- Internal transform datapath: signed 16-bit with seven fractional bits.
- DFT12: unnormalized.
- IFFT128: normalized by `1/128` at the final stage.
- External output: signed 8-bit Q1.7 with silent saturation to `[-128, 127]`.
- No additional TX gain is applied.

## Golden model

`gen_ofdm_tx_vectors.py` mirrors the exact RTL sequence:

1. Fixed-width Good-Thomas DFT12.
2. Mapping to bins 1 through 12.
3. Q1.7 twiddle IFFT128 with the exact unity and `+j` proxy cases.
4. Final arithmetic shift by seven.
5. Silent eight-bit saturation.
6. Nine- or ten-sample CP insertion.

Generated files:

```text
vectors/ofdm_tx_normal_cp_inputs.hex
vectors/ofdm_tx_normal_cp_expected.hex
vectors/ofdm_tx_normal_cp_numpy_reference.csv
vectors/ofdm_tx_extended_cp_inputs.hex
vectors/ofdm_tx_extended_cp_expected.hex
vectors/ofdm_tx_extended_cp_numpy_reference.csv
```

## Regression coverage

`scheduler_ofdm_tx_tb.sv` runs five normal-CP and five extended-CP frames. It checks:

- Every output byte against the bit-accurate model.
- A continuous output-valid burst after the first byte.
- Exact CP-to-symbol-tail equality.
- No standalone `result_valid_o` leakage during the internal DFT12 or IFFT128 phases.
- Command-to-output and final-input-to-output latency.

The existing OFDM_RX and standalone transform testbenches can also be compiled against the updated scheduler.

## Run

```bash
python3 gen_ofdm_tx_vectors.py

iverilog -g2012 -Wall \
  -o sim_ofdm_tx.out \
  scheduler_ofdm_tx_tb.sv \
  scheduler_ofdm_tx.sv \
  mixed_radix_butterfly.sv \
  tdiq_input_cp_remove.sv \
  fdiq_output_adapter.sv \
  fdiq_input_adapter.sv \
  subcarrier_mapper.sv \
  tdiq_output_cp_insert.sv

vvp sim_ofdm_tx.out
```

Or:

```bash
make -f Makefile.ofdm_tx tx
```
