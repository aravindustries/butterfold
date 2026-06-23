# ButterFold — Design Specification (planner input)

Design **ButterFold**, a minimum-area OFDM / DFT-s-OFDM transform core for a tiny 5G NR-inspired
proof-of-concept modem. The detailed, authoritative port-level contract for every block is in
`butterfold_module_io.md` — treat that file as the source of truth for signal names and widths; this
file is the high-level design intent the planner decomposes from.

## Frozen tapeout parameters
- k = 12 complex QAM symbols per block (1 resource block, transform-precoded)
- m = 128-point OFDM grid; centered subcarrier mapping (active bins start at 58)
- 8-bit signed I/Q, Q1.7; internal complex sample packed as {I[7:0], Q[7:0]} (16 bits)
- Cyclic prefix: **9 samples (normal)**, selectable **10 samples (long, first symbol)** via `long_cp`
- Single shared synchronous clock domain, active-low reset

## Target architecture — 6 modules + top

ButterFold is partitioned into six cooperating modules driven by streaming valid/ready handshakes.
See `butterfold_module_io.md` for the full interface of each.

1. **FDIQ I/O Adapter** — frequency-domain I/Q byte ↔ 16-bit complex packing; accepts 12 QAM symbols
   for TX, emits 12 extracted subcarriers for RX; tracks I/Q alignment and block boundaries.
2. **Unified Mixed-Radix Core** — the arithmetic for the 12-pt DFT, 128-pt FFT and 128-pt IFFT: a
   radix-2 butterfly, a radix-3 / 3-point kernel, the shared complex multiplier, widened
   accumulation, scaling, rounding and saturation. Executes scheduler micro-ops; reads/writes
   transform **scratch memory**. Does not schedule whole transforms itself.
3. **Twiddle Source** — stores/generates quantized twiddle factors; supplies one packed complex
   twiddle per request; supports conjugation for inverse transforms; fixed lookup latency.
4. **Scheduler + Address Control** — sequences DFT-12 / FFT-128 / IFFT-128, generates transform
   stage, memory and twiddle addresses, controls subcarrier map/extract, controls CP insertion and
   removal (`cp_len`, `long_cp`), selects ping-pong banks, reports completion/errors.
5. **Subcarrier Map / Extract** — TX: place 12 DFT outputs into selected bins of the 128-bin grid and
   zero-fill the rest; RX: read the selected 12 bins from the 128-bin FFT result.
6. **TDIQ I/O Adapter with CP** — time-domain I/Q byte ↔ complex packing; inserts CP after the TX
   IFFT, removes CP before the RX FFT; supports 9- and 10-sample CP; ping-pong symbol buffers.

A top-level chip wrapper exposes `clk_i`, `rst_ni`, an 8-bit `din`/`dout` command+I/Q interface with
valid/ready handshakes, `done_irq_o`, and optional scan ports (see `butterfold_module_io.md`).

## Transform behaviour
- **TX chain:** 12-pt DFT → centered subcarrier map → 128-pt IFFT → CP insertion → interleaved I/Q out.
- **RX chain:** CP removal → 128-pt FFT → active-subcarrier extraction → 12-pt IDFT → interleaved I/Q out.
- The 128-pt FFT/IFFT path uses radix-2 scheduling; the 12-pt DFT/IDFT path uses a 3×4 mixed-radix
  decomposition. All transforms reuse the single Unified Mixed-Radix Core (TDD half-duplex reuse).

## Current implementation status (important for the code step)
The proven, GDS-signed-off implementation today is a **flat TX core**: `butterfold_top.v` (control
wrapper: FSM + input deserializer + CP/centered-map addressing + output serializer) instantiating the
**locked, bit-exact** `butterfold_kernel.v` (twiddle ROMs + shared complex multiplier + round/clip),
generated and golden-validated by `gen_reference.py` (seed-42 EVM 1.59%). The 6-module architecture
above is the target the design is migrating toward; the adapters, scratch-memory scheduler, RX path
and variable CP are the modules still to be built on top of that locked kernel.

## Synthesizability constraints for the agent
- Verilog-2005 only, for iverilog (`-g2012`) and Yosys/GF180 compatibility.
- No SystemVerilog unpacked arrays (`reg x [0:N]` is allowed only with `(* mem2reg *)` for register
  files); no array slicing / range indexing; no tasks/functions with array ports.
- Synchronous active-low reset (`rst_n` / `rst_ni`); all flip-flops on `posedge clk`.
- Fixed-point arithmetic only — no `real`/`float`; no `initial` blocks in RTL (testbenches only).
- The bit-exact `butterfold_kernel` (twiddle ROMs / multiplier / rounding) is generated and LOCKED —
  do not hand-author or modify it; instantiate it.
