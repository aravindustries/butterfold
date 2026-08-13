# ButterFold real-time OFDM revision

This revision implements the first three system-integration steps after the all-mode transform regression passed:

1. Correct 15 kHz NR terminology: 9 samples = **short normal CP**, 10 samples = **long normal CP**. The opcodes are unchanged.
2. Add fixed one-RB extraction to production OFDM_RX: natural FFT bins **1 through 12** are emitted as 12 interleaved Q1.7 complex values (24 bytes).
3. Add ping-pong symbol buffering around the proven folded transform scheduler so external symbol capture/output can overlap transform computation.

## Command map

| Opcode | Mode |
|---|---|
| `0x40` | FFT2 |
| `0x41` | FFT128 |
| `0x42` | IFFT128 |
| `0x43` | IFFT2 |
| `0x44` | FFT3 |
| `0x45` | DFT12 |
| `0x46` | OFDM_RX, short normal CP = 9 samples |
| `0x47` | OFDM_RX, long normal CP = 10 samples |
| `0x48` | DFT-s-OFDM TX, short normal CP = 9 samples |
| `0x49` | DFT-s-OFDM TX, long normal CP = 10 samples |

At 15 kHz SCS the long normal CP is the 10-sample case. A future slot-level scheduler should select it for the appropriate long-CP symbol positions (symbols 0 and 7 in the scaled 128-point model).

## Architecture

The previously passing scheduler is preserved as `transform_scheduler_core.sv`. It still owns:

- mixed-radix butterfly scheduling,
- DFT12,
- FFT128/IFFT128,
- subcarrier mapping for TX,
- CP removal/insertion,
- fixed-point arithmetic.

`scheduler_realtime.sv` is now the global wrapper and retains the module name `scheduler`, so existing top-level instantiations do not change.

### Why the ping-pong buffers are at the 8-bit boundary

Instead of duplicating the 16-bit internal FFT scratch RAM, this revision adds two input frame banks and two output frame banks at the external 8-bit Q1.7 boundary.

Each bank is sized for the largest waveform frame:

- 10 CP + 128 useful complex samples
- 138 complex samples
- 276 interleaved bytes

Storage cost:

- input ping-pong: `2 x 276 x 8 = 4416 bits`
- output ping-pong: `2 x 276 x 8 = 4416 bits`
- total buffering: `8832 bits` plus small metadata

This is substantially cheaper than duplicating 128-entry, 32-bit-wide internal compute memories while still decoupling waveform timing from folded computation.

## RX pipeline

External side:

```text
TDIQ symbol n capture -> input bank A
TDIQ symbol n+1 capture -> input bank B
```

Core side:

```text
bank A -> existing CP removal -> existing FFT128 -> core emits 128 bins
                                                -> extractor keeps bins 1..12
                                                -> output frame bank
```

The next external symbol can fill the alternate input bank while the core is processing the first symbol. `din_ready_o` backpressures only when both input banks are occupied.

### One-RB output

OFDM_RX no longer emits all 128 FFT bins on `dout`. It emits:

```text
X[1].I, X[1].Q,
X[2].I, X[2].Q,
...
X[12].I, X[12].Q
```

Exactly 24 bytes are produced per RX symbol. This matches the fixed TX allocation (`SC_START_BIN = 1`, 12 contiguous bins). Standalone FFT128 remains available for full-transform diagnostics through the existing parallel result interface.

`subcarrier_extractor.sv` is a separate stream module so the fixed allocation can later become programmable without touching the FFT engine.

## TX pipeline

The external 12-complex-value FDIQ request is first buffered. The proven core then performs:

```text
DFT12 -> bins 1..12 map -> IFFT128 -> CP insertion
```

The complete 274-byte or 276-byte TDIQ frame is captured into one output bank. While that bank is being emitted, the transform core can process the next buffered TX request and fill the alternate output bank.

### Optional waveform pacing

`scheduler_realtime.sv` adds:

```systemverilog
parameter integer TX_BYTE_INTERVAL = 1;
```

`1` preserves the legacy regression behavior (one byte every clock).

For a 61.44 MHz chip clock and a 1.92 Msamples/s complex waveform:

```text
byte rate = 2 * 1.92 MHz = 3.84 MB/s
61.44 MHz / 3.84 MHz = 16 clocks/byte
```

so instantiate:

```systemverilog
.TX_BYTE_INTERVAL(16)
```

The output ping-pong banks then allow the next TX symbol to be generated while the current symbol drains at the actual waveform rate.

## Files

- `scheduler_realtime.sv` - global buffering/arbitration wrapper (`module scheduler`)
- `transform_scheduler_core.sv` - previously passing folded scheduler with corrected CP naming
- `subcarrier_extractor.sv` - fixed bins 1..12 RX extraction
- `mixed_radix_butterfly.sv` - unchanged arithmetic core
- existing input/output adapters and TX subcarrier mapper
- `gen_realtime_vectors.py` - all vectors plus one-RB RX expected files
- `scheduler_realtime_full_tb.sv` - updated all-mode regression
- `scheduler_pingpong_tb.sv` - overlap/pacing regression
- `Makefile.realtime`

## Regression

Generate vectors:

```bash
python3 gen_realtime_vectors.py
```

Run every existing mode with the new RX behavior:

```bash
make -f Makefile.realtime full
```

Run the dedicated ping-pong test:

```bash
make -f Makefile.realtime pingpong
```

Or both:

```bash
make -f Makefile.realtime all
```

The ping-pong regression verifies:

- a second RX symbol is fully captured before the first RX result begins,
- RX output is exactly bins 1..12,
- two TX requests can be buffered before the first waveform begins,
- the second TX frame is generated into the alternate bank while the first drains,
- with `TX_BYTE_INTERVAL=16`, valid TX bytes remain exactly 16 clocks apart across the symbol boundary,
- short and long normal CP waveforms remain bit-accurate.

## Important scope boundary

This adds buffering and overlap, but it is not yet the final slot/TDD controller. The next layer should provide symbol index/direction scheduling and automatically choose short versus long normal CP. The ping-pong wrapper provides the storage and backpressure behavior that controller will need.
