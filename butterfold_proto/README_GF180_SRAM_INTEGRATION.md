# ButterFold GF180 SRAM integration

This revision replaces the physically significant behavioral memories with a cycle-accurate interface matching the GlobalFoundries GF180MCU synchronous single-port SRAM macros.

## Final pin interface

Unchanged:

```text
Inputs:  rst_n, clk, din[7:0], din_valid_i
Outputs: din_ready_o, dout[7:0], dout_valid_o
Power:   VDD at the physical padframe level
```

No SRAM or debug signal reaches the chip boundary.

## Physical memory map

### FFT/IFFT scratch store

Logical memory: 128 x 32 bits, one signed 16-bit I plus one signed 16-bit Q per address.

Physical implementation:

```text
4 x gf180mcu_fd_ip_sram__sram128x8m8wm1
```

The four byte macros are operated in parallel and packed as:

```text
macro 0 = I[7:0]
macro 1 = I[15:8]
macro 2 = Q[7:0]
macro 3 = Q[15:8]
```

The FFT scheduler now obeys a real single-port access sequence. Every radix-2 operation reads the two operands through synchronous SRAM, issues the existing butterfly, latches the result, then performs two sequential SRAM writes.

### Shared waveform ping-pong store

Physical implementation:

```text
2 x gf180mcu_fd_ip_sram__sram512x8m8wm1
```

The banks are shared because ButterFold is half duplex:

```text
RX mode: external TDIQ -> bank A/B -> transform core
TX mode: transform core -> bank A/B -> external TDIQ
```

A bank is never used for RX and TX simultaneously. This avoids four separate large input/output buffers.

### Register-resident storage

These intentionally remain local registers:

- DFT12 in-place working set: 12 x 32 bits.
- TX DFT12 natural-order output buffer: 12 x 32 bits.
- TX input ping-pong: 2 x 24 bytes.
- RX one-RB output ping-pong: 2 x 24 bytes.
- FFT2/IFFT2/FFT3 transaction FIFO.
- Result metadata FIFO.
- Mixed-radix butterfly elastic registers.
- Scheduler counters, addresses, ownership metadata.

The structures are too small and/or require too many simultaneous accesses for a single-port hard SRAM to be area-efficient.

## Twiddle ROM

The 64 forward W128 Q1.7 twiddles are now in `fft128_twiddle_rom.sv` as hard-coded combinational constants. The previous `$readmemh` twiddle arrays are gone from the physical RTL.

This avoids two extra SRAM macros and avoids adding synchronous SRAM latency to every twiddle lookup.

## SRAM wrappers

`gf180_sram_128x8_wrapper.sv` and `gf180_sram_512x8_wrapper.sv` provide a common interface:

```text
req
write
addr
wdata
rdata
rvalid
```

Contract:

- one read OR write request per bank per clock;
- write commits on the request rising edge;
- read response is visible with `rvalid` one clock later;
- there is no asynchronous combinational RAM read.

### Fast behavioral mode

The default wrapper contains a simple behavioral array that enforces the same synchronous, single-port cycle contract. Use this for normal regression.

```bash
make -f Makefile.gf180_sram behavioral
```

### Official foundry-model mode

Compile with the official GF180 SRAM Verilog models and define `GF180_USE_FOUNDRY_SRAM`:

```bash
make -f Makefile.gf180_sram foundry \
  SRAM128_MODEL=/path/to/gf180mcu_fd_ip_sram__sram128x8m8wm1.v \
  SRAM512_MODEL=/path/to/gf180mcu_fd_ip_sram__sram512x8m8wm1.v
```

The wrappers connect the macro ports `CLK`, `CEN`, `GWEN`, `WEN`, `A`, `D`, `Q`, `VDD`, and `VSS`. During reset, `CEN` is forced high so the macro satisfies its requirement to enter standby before its first active operation.

For a typical open-pdks install, locate the views under `$PDK_ROOT/gf180mcu*/libs.ref/gf180mcu_fd_ip_sram/`. Exact installation paths vary, so the Makefile accepts explicit model paths.

## Files changed

- `butterfold_top.sv`: two shared 512x8 waveform SRAM banks; small TX input/RX output buffers remain registers.
- `transform_scheduler_core.sv`: 128x32 scratch store converted to single-port synchronous SRAM scheduling.
- `fft128_twiddle_rom.sv`: constant ROM replacing `$readmemh` twiddle storage.
- `fdiq_output_adapter_sram.sv`: synchronous SRAM-aware frequency-domain serializer.
- `tdiq_output_cp_insert_sram.sv`: synchronous SRAM-aware CP/time-domain serializer.
- `gf180_sram_128x8_wrapper.sv`: 128x8 foundry/behavioral wrapper.
- `gf180_sram_512x8_wrapper.sv`: 512x8 foundry/behavioral wrapper.
- `gf180_sram_128x32_complex.sv`: four-byte-macro complex memory composition.

## Verification

Run the wrapper smoke test first:

```bash
make -f Makefile.gf180_sram wrapper
```

Then all final-pin modes:

```bash
make -f Makefile.gf180_sram behavioral
```

Expected final line:

```text
FINAL-PIN OVERALL RESULT: PASS
```

Then repeat against the official foundry models using the `foundry` target.

## Timing implications

This revision intentionally changes latency. The numerical golden vectors do not change, but the cycle counts will.

The important new costs are:

- synchronous operand fetches for every FFT/IFFT butterfly;
- two single-port SRAM writes per radix-2 result;
- synchronous reads when serializing final RX/TX transform data;
- SRAM reads when an RX ping-pong bank is fed into the core.

Do not use the old 2,324-cycle TX number for final throughput analysis. Once this regression passes locally, measure the new RX/TX cycle counts with this implementation and then evaluate whether the single-port architecture meets the 15-kHz-SCS symbol deadline. If it does not, the first fallback is a two-bank FFT scratch architecture rather than duplicating the transform core.

## Physical-flow note

The behavioral wrapper arrays are simulation conveniences only. The physical/synthesis configuration must define `GF180_USE_FOUNDRY_SRAM` (or otherwise black-box/replace the wrappers with the GF macro views) so the hard SRAMs are preserved and the behavioral arrays are not synthesized into flip-flops.
