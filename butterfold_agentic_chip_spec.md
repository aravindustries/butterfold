# ButterFold Agent-Ready Chip Specification

## 0. Purpose

ButterFold is a minimum-area digital baseband transform core for a narrow 5G NR-inspired proof of concept. It folds the TX DFT, TX IFFT, and RX FFT onto one reusable mixed-radix transform engine.

The RTL generator must implement the frozen tapeout core only. Do not expand this into a full modem.

## 1. Hard Scope Boundary

### Implement

- 12-point DFT for DFT-s-OFDM TX transform precoding.
- 128-point IFFT for TX OFDM modulation.
- 128-point FFT for RX OFDM demodulation.
- TX subcarrier mapping from 12 DFT bins into a 128-bin grid.
- RX subcarrier extraction of 12 active bins from a 128-bin FFT result.
- TX CP insertion.
- RX CP removal.
- Shared byte-stream command, input, output, and status interface.
- Fixed-point packed complex sample datapath.
- Scheduler-controlled folded mixed-radix execution.
- Transform-only, complete TX, complete RX, CP-only, loopback, and diagnostic commands.

### Do Not Implement

- RF front end, PA, LNA, mixer, PLL, ADC, or DAC.
- Synchronization, channel estimation, equalization, coding, decoding, HARQ, MAC, or a full 5G NR protocol stack.
- Dynamic commercial modem scheduling.
- Multiple clock domains in the base tapeout core.
- Dedicated completion/status interrupt pin.
- Any supply/ground pin accounting in the digital interface spec.

## 2. Frozen Tapeout Parameters

| Parameter | Value | Requirement |
|---|---:|---|
| Active subcarriers / DFT size | `k = 12` | Minimum 1-RB NR-style allocation. |
| OFDM FFT/IFFT size | `m = 128` | Fixed tiny proof-of-concept transform size. |
| External I/Q width | 8-bit signed | Q1.7 byte for I and Q. |
| Internal complex sample | 16 bits | Packed as `{I[7:0], Q[7:0]}`. |
| CP lengths | 9 or 10 complex samples | Selected by command/config byte. |
| Clocking | One synchronous clock domain | Use clock enables and handshakes, not divided clocks. |
| External interface | 8-bit input stream + 8-bit output stream | Shared for commands, I/Q payloads, and status. |
| Digital pin target | 22 pins | See top-level pinout below. |
| Transform datapath | One folded mixed-radix engine | Must support radix-2 128 FFT/IFFT and 12-point DFT using 3×4-style decomposition or equivalent radix-2 plus 3-point support. |

## 3. Top-Level Digital Interface

The chip exposes one shared byte-stream interface. Commands, FDIQ payloads, TDIQ payloads, and status all travel over these pins.

| Signal | Width | Direction | Function |
|---|---:|---|---|
| `clk_i` | 1 | Input | Shared synchronous clock. |
| `rst_ni` | 1 | Input | Active-low reset. |
| `din[7:0]` | 8 | Input | Command bytes and interleaved input I/Q bytes. |
| `din_valid_i` | 1 | Input | Current `din[7:0]` byte is valid. |
| `din_ready_o` | 1 | Output | ButterFold can accept input byte. |
| `dout[7:0]` | 8 | Output | Status bytes and interleaved output I/Q bytes. |
| `dout_valid_o` | 1 | Output | Current `dout[7:0]` byte is valid. |
| `dout_ready_i` | 1 | Input | External receiver can accept output byte. |

Total digital pins:

```text
1 clock + 1 reset + 8 input data + 2 input handshake
+ 8 output data + 2 output handshake = 22 pins
```

No separate mode pins, CP pins, status pins, test pins, or interrupt pins are allowed in the base interface. Operation selection must be command-based.

## 4. Stream and Sample Format

External payload bytes are interleaved signed Q1.7 I/Q samples:

```text
cycle 0: I0
cycle 1: Q0
cycle 2: I1
cycle 3: Q1
...
```

Internal complex samples are packed as:

```text
complex_sample[15:0] = {I[7:0], Q[7:0]}
```

All internal streams use:

```text
data
valid
ready
last
```

A transfer occurs only when `valid && ready` is true. Agents must preserve correct I/Q byte alignment under stalls and backpressure.

## 5. Command Set

A command/configuration byte is sent on `din[7:0]` before a payload. The operation is encoded using `cmd_op[2:0]`. One config bit selects normal vs long CP where relevant.

| `cmd_op[2:0]` | Operation | Payload / Behavior |
|---|---|---|
| `000` | 12-point DFT only | Input 12 complex samples, output 12 complex samples. |
| `001` | 128-point FFT only | Input 128 complex samples, output 128 complex samples. |
| `010` | 128-point IFFT only | Input 128 complex samples, output 128 complex samples. |
| `011` | Complete TX symbol | 12 QAM samples → DFT-12 → map → IFFT-128 → CP insert. |
| `100` | Complete RX symbol | CP remove → FFT-128 → extract 12 bins. |
| `101` | CP-only test | Test CP insertion/removal path. |
| `110` | Digital loopback test | Exercise byte stream, packing, memory, and output path. |
| `111` | Diagnostic/readback | Status, cycle count, memory/twiddle checks as implemented. |

Completion, errors, overflow, saturation, and cycle-count information must be returned as status bytes over `dout[7:0]`.

## 6. Required Transactions

### Complete TX Symbol

Input:

- 12 complex QAM samples.
- 24 interleaved I/Q bytes.

Processing sequence:

```text
FDIQ bytes
→ pack into 12 complex samples
→ 12-point DFT
→ map 12 DFT outputs into selected 12 contiguous bins of 128-bin grid
→ zero unused grid bins
→ 128-point IFFT
→ CP insertion
→ serialize TDIQ bytes
```

Output:

- If `N_CP = 9`: `128 + 9 = 137` complex samples = 274 bytes.
- If `N_CP = 10`: `128 + 10 = 138` complex samples = 276 bytes.

### Complete RX Symbol

Input:

- If `N_CP = 9`: 274 interleaved I/Q bytes.
- If `N_CP = 10`: 276 interleaved I/Q bytes.

Processing sequence:

```text
TDIQ bytes
→ pack into complex samples
→ discard first N_CP complex samples
→ write next 128 useful samples into transform memory
→ 128-point FFT
→ extract selected 12 active bins
→ serialize FDIQ bytes
```

Output:

- 12 complex recovered frequency-domain samples.
- 24 interleaved I/Q bytes.

## 7. Required Dataflow

TX path:

```text
QAM symbols
→ k-point DFT, k = 12
→ subcarrier mapping into m = 128 grid
→ m-point IFFT, m = 128
→ CP insertion
→ time-domain waveform
```

RX path:

```text
time-domain waveform
→ CP removal
→ m-point FFT, m = 128
→ subcarrier extraction of k = 12 bins
→ QAM-like frequency-domain samples
```

This is a half-duplex TDD proof-of-concept. RX and TX are not required to execute simultaneously. The same transform engine, multiplier, twiddle source, scratch memory, and scheduler infrastructure are reused across TX and RX.

## 8. Required RTL Partition

The implementation must use six functional blocks under one top-level integration wrapper.

```text
ButterFold top level
├── FDIQ I/O Adapter
├── Unified Mixed-Radix Core + Scratch RAM
├── Twiddle Source
├── Scheduler + Address Control
├── Subcarrier Map / Extract
└── TDIQ I/O Adapter with CP
```

The Scheduler is the only block that owns complete-operation sequencing. The Mixed-Radix Core executes scheduler-issued micro-operations and must not independently interpret full FFT/IFFT/DFT commands.

## 9. Module Specifications

### 9.1 FDIQ I/O Adapter

Function:

- Converts external 8-bit interleaved frequency-domain I/Q bytes into packed complex samples.
- Converts packed complex samples back into external interleaved bytes.
- Accepts 12 QAM samples for TX.
- Emits 12 extracted subcarrier samples for RX.
- Tracks I/Q phase and 12-sample block boundaries.
- Detects I/Q alignment errors.

Required I/O:

| Interface | Signals |
|---|---|
| External input | `fdiq_in_data[7:0]`, `fdiq_in_valid`, `fdiq_in_ready` |
| External output | `fdiq_out_data[7:0]`, `fdiq_out_valid`, `fdiq_out_ready` |
| Internal TX stream | `fd_in_data[15:0]`, `fd_in_valid`, `fd_in_ready`, `fd_in_last` |
| Internal RX stream | `fd_out_data[15:0]`, `fd_out_valid`, `fd_out_ready`, `fd_out_last` |
| Control/status | `start`, `direction`, `busy`, `done`, `iq_alignment_error` |

### 9.2 Unified Mixed-Radix Core + Scratch RAM

Function:

- Implements arithmetic for DFT-12, FFT-128, and IFFT-128.
- Contains radix-2 butterfly, 3-point kernel or equivalent 12-point mixed-radix support, shared complex multiplier, widened internal datapath, scaling, rounding, saturation, and transform scratch RAM.
- Executes one scheduler-issued micro-operation at a time.
- Owns the physical transform scratch memory.
- Reports arithmetic overflow and saturation.

Required I/O:

| Interface | Signals |
|---|---|
| Micro-operation | `uop_valid`, `uop_ready`, `uop_radix[1:0]`, `uop_inverse`, `uop_scale_shift[2:0]`, `uop_last` |
| Source addresses | `src_addr_0[6:0]`, `src_addr_1[6:0]`, `src_addr_2[6:0]` |
| Destination addresses | `dst_addr_0[6:0]`, `dst_addr_1[6:0]`, `dst_addr_2[6:0]` |
| Twiddle input | `twiddle_re[7:0]`, `twiddle_im[7:0]`, `twiddle_valid` |
| External memory load | `load_addr[6:0]`, `load_data[15:0]`, `load_valid`, `load_ready` |
| External memory read | `read_addr[6:0]`, `read_req`, `read_data[15:0]`, `read_valid` |
| Status | `uop_done`, `overflow`, `saturation_occurred` |

Complete-transform `busy` and `done` signals belong to the Scheduler, not this core.

### 9.3 Twiddle Source

Function:

- Stores or generates quantized transform twiddles.
- Outputs real and imaginary Q1.7 twiddle components in the same cycle.
- Supports conjugation for inverse transforms.
- Has fixed documented lookup latency.

Required I/O:

| Interface | Signals |
|---|---|
| Request | `tw_req`, `tw_addr[6:0]`, `tw_conjugate` |
| Response | `tw_re[7:0]`, `tw_im[7:0]`, `tw_valid` |

Fixed constants for the 3-point kernel may remain local to the Mixed-Radix Core.

### 9.4 Scheduler + Address Control

Function:

- Decodes commands and controls all complete operations.
- Sequences DFT-12, FFT-128, and IFFT-128.
- Generates source/destination addresses, twiddle addresses, radix type, inverse flag, scaling shifts, and `uop_last`.
- Controls map/extract, CP insertion/removal, and buffer-bank ownership.
- Tracks `busy`, `done`, `error`, and cycle count.

Required I/O:

| Interface | Signals |
|---|---|
| Command | `cmd_valid`, `cmd_ready`, `cmd_op[2:0]`, `long_cp` |
| Transform control | `uop_valid`, `uop_ready`, `uop_radix[1:0]`, `uop_inverse`, `uop_scale_shift[2:0]`, `uop_last` |
| Transform addresses | `src_addr_0/1/2[6:0]`, `dst_addr_0/1/2[6:0]` |
| Twiddle control | `tw_req`, `tw_addr[6:0]`, `tw_conjugate`, `tw_valid` |
| Map/extract control | `map_start`, `map_direction`, `first_subcarrier[6:0]`, `map_done` |
| CP control | `cp_start`, `cp_insert`, `cp_len[3:0]`, `cp_done` |
| Buffer control | `input_bank_select`, `output_bank_select` |
| Global status | `busy`, `done`, `error`, `cycle_count[15:0]` |

### 9.5 Subcarrier Map / Extract

Function:

- TX mode: writes 12 DFT outputs into a selected contiguous 12-bin allocation inside a 128-bin frequency grid.
- TX mode: zeros unused bins before IFFT.
- RX mode: reads the selected 12 bins from the FFT output grid and emits them as a 12-sample complex stream.
- Detects invalid subcarrier configuration.

Required I/O:

| Interface | Signals |
|---|---|
| Control | `start`, `map_not_extract`, `first_subcarrier[6:0]`, `busy`, `done`, `config_error` |
| Input stream | `in_data[15:0]`, `in_valid`, `in_ready`, `in_last` |
| Output stream | `out_data[15:0]`, `out_valid`, `out_ready`, `out_last` |
| Scratch-memory access | `mem_addr[6:0]`, `mem_write`, `mem_wdata[15:0]`, `mem_rdata[15:0]`, `mem_rvalid` |

### 9.6 TDIQ I/O Adapter with CP

Function:

- Converts external time-domain interleaved I/Q bytes to and from packed complex samples.
- RX mode: discards the first `N_CP` complex samples and writes the next 128 useful samples into transform memory.
- TX mode: reads the final `N_CP` IFFT samples followed by all 128 IFFT samples and serializes the CP-added symbol.
- Supports `N_CP = 9` and `N_CP = 10`.
- Tracks I/Q phase, CP length, and symbol sample count.
- Detects CP, sample-count, and I/Q alignment errors.

Required I/O:

| Interface | Signals |
|---|---|
| External input | `tdiq_in_data[7:0]`, `tdiq_in_valid`, `tdiq_in_ready` |
| External output | `tdiq_out_data[7:0]`, `tdiq_out_valid`, `tdiq_out_ready` |
| CP control | `cp_start`, `cp_insert`, `cp_len[3:0]` |
| RX useful-symbol stream | `rx_symbol_data[15:0]`, `rx_symbol_valid`, `rx_symbol_ready`, `rx_symbol_last` |
| TX memory read | `tx_symbol_rd_addr[6:0]`, `tx_symbol_rd_req`, `tx_symbol_rd_data[15:0]`, `tx_symbol_rd_valid` |
| Status | `busy`, `done`, `cp_error`, `sample_count_error`, `iq_alignment_error` |

## 10. Memory Ownership and Buffering

- The Unified Mixed-Radix Core owns the physical transform scratch memory.
- The Scheduler owns address generation and bank selection.
- FDIQ, TDIQ, and Map/Extract may access selected memory banks only through controlled load/read/write ports.
- For continuous multi-symbol operation, support two 128-complex-sample banks:

```text
Bank A: transform processing
Bank B: input loading or output streaming
```

- TX CP insertion must not use a duplicate CP RAM. It must re-read the final `N_CP` samples and then the full 128-sample symbol from the selected transform-memory bank.

## 11. Transform Requirements

### 128-point FFT/IFFT

- Use radix-2 reuse for `m = 128`.
- A 128-point radix-2 FFT requires 448 butterfly operations.
- IFFT must reuse the same datapath using inverse/conjugation/scaling control.
- Output ordering, scaling, rounding, saturation, and permutation must match the bit-accurate Python model exactly.

### 12-point DFT

- Must support `k = 12` exactly.
- Because 12 is not a power of two, the core must not be radix-2 only.
- Use compact mixed-radix support, such as 3×4 decomposition, radix-2 plus 3-point kernel, Good-Thomas 3×4, or another implementation that exactly matches the bit-accurate model.
- The tapeout core does not need larger `k = 12 × N_RB` values.

## 12. Clocking and Throughput

- Use one shared clock domain for the base chip.
- Do not introduce asynchronous CDC in the tapeout core.
- Use clock enables and `valid/ready` handshakes.
- The initial target shared core clock is approximately 25–50 MHz, but final required frequency must be derived from measured full-symbol cycle count after RTL scheduling and synthesis.
- External streams may stall. The design must maintain correctness under randomized backpressure.

## 13. Fixed-Point and Numerical Rules

The RTL must match a bit-accurate Python golden model. The model must define and the RTL must follow:

- Q1.7 input/output quantization.
- Q1.7 twiddle quantization.
- Internal widened arithmetic widths.
- Per-stage or per-uop scaling shifts.
- Rounding mode.
- Saturation behavior.
- Overflow flag behavior.
- FFT/IFFT/DFT output ordering.
- Address permutations.
- CP output order.
- Map/extract bin ordering.

Do not rely on floating-point NumPy as the RTL acceptance reference. Floating-point is for math validation only; RTL pass/fail uses the bit-accurate model.

## 14. Verification Requirements

### Module-Level Tests

| Module | Required checks |
|---|---|
| FDIQ Adapter | Byte packing/unpacking, I/Q alignment, stalls, and 12-sample boundaries. |
| Mixed-Radix Core | DFT-12, FFT-128, IFFT-128, scaling, overflow, saturation, and output ordering. |
| Twiddle Source | Every lookup address against generated Q1.7 table. |
| Scheduler | Address, radix, stage, twiddle, bank-selection, and uop trace against Python schedule generator. |
| Map/Extract | Exact placement and recovery of 12 bins in 128-bin grid. |
| TDIQ/CP Adapter | CP insertion/removal for `N_CP = 9` and `N_CP = 10`, including random stalls. |

### Full-Chip Test Order

1. Arithmetic primitives.
2. Transform-only commands.
3. Complete TX chain.
4. Complete RX chain.
5. Digital TX-to-RX loopback.
6. Continuous multi-symbol operation with ping-pong buffers.
7. Synthesis and gate-level regression.
8. Post-layout timing and selected SDF tests.

### Directed Test Vectors

Include at least:

- all zeros;
- impulse;
- single tones;
- random QAM;
- maximum/minimum values;
- clipping and saturation cases;
- both CP lengths;
- reset interruption;
- randomized `valid/ready` backpressure.

## 15. Post-Silicon / Diagnostic Requirements

The command protocol must support deterministic bring-up using saved Python vectors. Include modes or readbacks sufficient for:

- transform-only tests;
- CP-only tests;
- map/extract tests;
- loopback tests;
- twiddle readback or equivalent twiddle verification;
- memory test or diagnostic readback;
- status byte readout for completion, errors, overflow, saturation, and cycle count.

These diagnostics must not require extra functional pins.

## 16. Agent Guardrails

Agents generating RTL, tests, or documentation must obey these rules:

1. Keep the tapeout design fixed at `k = 12`, `m = 128`, 8-bit external I/Q, CP length 9/10, and 22 digital pins.
2. Do not add full modem features.
3. Do not add RF or mixed-signal blocks.
4. Do not add dedicated mode, status, CP, test, or interrupt pins.
5. Do not split the base design into multiple asynchronous clock domains.
6. Do not let the Mixed-Radix Core own global sequencing; the Scheduler owns global operation sequencing.
7. Do not use a radix-2-only core unless a separate exact 12-point DFT implementation is included.
8. Do not verify RTL against only a floating-point model.
9. Do not change sample ordering without updating the bit-accurate model and tests.
10. Do not implement larger NR configurations in tapeout RTL; reserve those for simulation/design-space exploration.

## 17. Minimal Acceptance Criteria

The generated chip RTL is acceptable only if it satisfies all of the following:

- Exposes exactly the 22-pin digital interface listed above.
- Supports all eight command encodings.
- Correctly performs DFT-12, FFT-128, and IFFT-128 transform-only commands.
- Correctly performs complete TX transaction for both CP lengths.
- Correctly performs complete RX transaction for both CP lengths.
- Correctly handles backpressure without losing byte or I/Q alignment.
- Uses one folded transform engine for DFT, FFT, and IFFT arithmetic reuse.
- Returns completion and status over `dout[7:0]`, not through a separate interrupt pin.
- Matches the bit-accurate Python model exactly for directed and randomized tests.
- Synthesizes under one synchronous clock domain.

## 18. One-Sentence Summary

ButterFold is a fixed `k = 12`, `m = 128`, 8-bit-I/Q, 22-pin, half-duplex TDD digital transform core that reuses one mixed-radix engine across DFT-s-OFDM TX and OFDM RX/TX transform operations.
