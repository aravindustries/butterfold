# ButterFold final-pin implementation

This revision removes every parallel standalone-result/debug signal from the
physical top level. `butterfold_top.sv` exposes only the frozen digital signal
interface:

```text
Inputs:  rst_n, clk, din[7:0], din_valid_i
Outputs: din_ready_o, dout[7:0], dout_valid_o
```

The VDD pad is added by the physical padframe flow rather than modeled as a
functional RTL signal. No additional logical pins are required.

## Commands

| Opcode | Mode |
|---|---|
| `0x40` | FFT2 |
| `0x41` | FFT128 |
| `0x42` | IFFT128 |
| `0x43` | IFFT2 |
| `0x44` | FFT3 |
| `0x45` | DFT12 |
| `0x46` | OFDM RX, short normal CP (9) |
| `0x47` | OFDM RX, long normal CP (10) |
| `0x48` | DFT-s-OFDM TX, short normal CP (9) |
| `0x49` | DFT-s-OFDM TX, long normal CP (10) |

## Standalone output serialization

The old parallel result interface carried full 16-bit complex values and a
7-bit address for each result. The final pin interface preserves that
information using a five-byte complex record:

```text
byte 0: output address, {1'b0, addr[6:0]}
byte 1: I[15:8]
byte 2: I[7:0]
byte 3: Q[15:8]
byte 4: Q[7:0]
```

Records are emitted in the transform core's result-transaction order. Because
each record carries its address, a host can reconstruct natural output order
without requiring a 128-sample diagnostic reorder RAM on-chip.

Result sizes are therefore:

| Mode | Complex records | Output bytes |
|---|---:|---:|
| FFT2 | 2 | 10 |
| IFFT2 | 2 | 10 |
| FFT3 | 3 | 15 |
| DFT12 | 12 | 60 |
| FFT128 | 128 | 640 |
| IFFT128 | 128 | 640 |

The serializer accepts one parallel result transaction, backpressures the
mixed-radix core internally, emits all 10 or 15 transaction bytes on
consecutive cycles, then accepts the next transaction. This adds essentially
control/mux/register logic rather than a large result buffer.

Standalone operations are diagnostic operations and are exclusive at the
external command boundary: the next command is not accepted until the final
standalone result byte has been emitted. This does not affect continuous OFDM
operation, which retains the existing ping-pong input/output buffering.

## Production OFDM output formats

The OFDM modes retain their existing compact 8-bit Q1.7 stream formats; they do
not use the diagnostic address-record format.

* OFDM RX (`0x46`/`0x47`): 12 extracted complex bins (bins 1..12), I then Q,
  exactly 24 output bytes.
* DFT-s-OFDM TX `0x48`: 9-sample CP + 128 useful samples = 274 bytes.
* DFT-s-OFDM TX `0x49`: 10-sample CP + 128 useful samples = 276 bytes.

There is no `dout_ready` pin. Every byte with `dout_valid_o=1` is assumed to be
accepted by the downstream device.

## Regression

Generate vectors and run the final-pin test with:

```bash
make -f Makefile.final_pin run
```

The testbench exercises all ten opcodes using only the final external stream
signals. For standalone block transforms it uses the serialized addresses to
reconstruct natural-order results and compares them against the existing
bit-accurate golden vectors.

Expected final message:

```text
FINAL-PIN OVERALL RESULT: PASS
```
