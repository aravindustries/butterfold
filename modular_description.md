Design a Verilog module called butterfold_top.

The module implements a minimum-area OFDM / DFT-s-OFDM transform core for a tiny 5G NR-inspired proof-of-concept modem.

The core supports two modes: TX mode and RX mode.

In TX mode, the module accepts k = 12 complex input QAM symbols through an 8-bit signed interleaved I/Q input stream. The input format is:

cycle 0: I0
cycle 1: Q0
cycle 2: I1
cycle 3: Q1
...
cycle 22: I11
cycle 23: Q11

After receiving the full input block, the module performs:

1. 12-point DFT
2. subcarrier mapping into a 128-point OFDM grid
3. 128-point IFFT
4. cyclic prefix insertion
5. serialized 8-bit interleaved I/Q output

In RX mode, the module accepts a 128-point OFDM time-domain block with cyclic prefix through the same 8-bit signed interleaved I/Q input stream. The module performs:

1. cyclic prefix removal
2. 128-point FFT
3. active subcarrier extraction
4. 12-point IDFT
5. serialized 8-bit interleaved I/Q output

The module should reuse a single folded mixed-radix transform engine for all DFT, IDFT, FFT, and IFFT operations. The 128-point FFT/IFFT path should use radix-2 scheduling. The 12-point DFT/IDFT path should use a 3×4 mixed-radix decomposition.

The design should use block-streaming control. The module should assert dout_valid whenever output data is valid.

Inputs:
- clk
- rst_n
- mode
- din[7:0]
- din_valid

Outputs:
- dout[7:0]
- dout_valid
- busy
- done

The design should be synthesizable Verilog and should avoid unsynthesizable constructs.

CRITICAL IMPLEMENTATION CONSTRAINTS FOR AGENT:
- Do NOT use SystemVerilog unpacked arrays (e.g., "logic data [0:11]"). Instead, use packed arrays or scalar loops.
- Do NOT use array slicing or range indexing (e.g., "data[0:11]"). Loop through elements one at a time with individual assignments.
- Do NOT use tasks or functions with array ports. Process data element-by-element in always blocks or combinational logic.
- Generate ONLY Verilog-2005 constructs for maximum compatibility with iverilog simulator.
- If you need to work with multi-element data (like DFT input/output), use individual scalar signals or tightly-coupled RAM reads/writes, not array passing.