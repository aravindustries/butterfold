# Module Description Template
#
# HOW TO USE
# ----------
# 1. Copy this file:        cp modular_description.template.md modular_description.md
# 2. Fill in every section. Use the ButterFold example on the right as a guide.
# 3. Run:                   python agents/orchestrator.py
#
# RULE: Be as specific as you would be talking to a hardware engineer.
# Say the algorithm name, the bit width, the exact cycle count.
# Vague specs → more debug iterations.
# ============================================================================

## Module name
# snake_case, matches the Verilog module keyword.
# ButterFold example: butterfold_top
MODULE_NAME


## One-line description
# One sentence: what + why.
# ButterFold example:
#   "Minimum-area DFT-s-OFDM transform core for a 5G NR proof-of-concept modem,
#    supporting TX (QAM→OFDM) and RX (OFDM→QAM) with a shared folded transform engine."
ONE_LINE_DESCRIPTION


## Operating modes
# List every mode. If single-mode, write "Single mode — no mode select needed."
#
# ButterFold example:
#   TX : accepts k=12 complex QAM symbols, outputs 128+CP time-domain OFDM samples
#   RX : accepts 128+CP OFDM time-domain samples, recovers 12 complex QAM symbols

- MODE_1 : DESCRIPTION
- MODE_2 : DESCRIPTION


## Ports
# Format:  direction  name[width]   description
# Required: clk, rst_n, busy, done. Add everything else your design needs.
#
# ButterFold example:
#   input   clk              system clock
#   input   rst_n            synchronous active-low reset
#   input   mode             0=TX, 1=RX
#   input   din[7:0]         8-bit signed input sample (interleaved I/Q)
#   input   din_valid        asserted when din is valid
#   output  dout[7:0]        8-bit signed output sample (interleaved I/Q)
#   output  dout_valid       asserted when dout is valid
#   output  busy             high while module is processing a block
#   output  done             single-cycle pulse when output block is complete

input   clk
input   rst_n
input   din[7:0]
input   din_valid
output  dout[7:0]
output  dout_valid
output  busy
output  done


## Data format
# Describe din and dout at the byte level, cycle by cycle.
# DO NOT say "stream" or "data" — say exactly what byte appears on which cycle.
#
# ButterFold example:
#   din  : 8-bit signed two's-complement, interleaved I/Q.
#          Cycle 0=I0, cycle 1=Q0, cycle 2=I1, ..., cycle 23=Q11 (total 24 bytes for k=12).
#   dout : same format. TX produces 2*(128+CP) = 274 bytes. RX produces 2*12 = 24 bytes.

din  : DESCRIBE_INPUT_FORMAT
dout : DESCRIBE_OUTPUT_FORMAT


## Processing steps
# Number them. Name the algorithm, not just the action.
# BAD:  "1. Process the input"
# GOOD: "1. 12-point DFT via 3×4 mixed-radix Cooley-Tukey decomposition"
#
# ButterFold TX example:
#   1. Accumulate 24 input bytes into 12 complex int8 symbols (I0,Q0 ... I11,Q11).
#   2. 12-point DFT via 3×4 mixed-radix Cooley-Tukey (stage1: four 3-pt DFTs; stage2: three 4-pt DFTs + twiddle).
#   3. Map 12 DFT bins into positions 0–11 of a 128-point frequency grid (zero-fill bins 12–127).
#   4. 128-point IFFT, radix-2 decimation-in-time, 7 butterfly stages.
#   5. Prepend CP=9 samples (copy last 9 output samples of IFFT to front).
#   6. Serialize 137 complex samples as 274 bytes on dout (interleaved I/Q, 8-bit signed).
#
# ButterFold RX example:
#   1. Accept 274 input bytes; discard first 18 (CP removal: 9 complex samples).
#   2. 128-point FFT, radix-2 DIT, 7 stages (reuse same butterfly as TX IFFT).
#   3. Extract bins 0–11 (active subcarrier extraction).
#   4. 12-point IDFT via 3×4 mixed-radix (conjugate twiddles, divide by 12).
#   5. Serialize 12 complex symbols as 24 bytes on dout.

### MODE_1
1. STEP
2. STEP

### MODE_2
1. STEP
2. STEP


## Key parameters
# All design-time constants. Agents bake these into RTL literals.
# ButterFold example:
#   k   = 12    # complex input/output symbols (one 5G NR resource block)
#   m   = 128   # FFT/IFFT transform size
#   CP  = 9     # cyclic prefix length in samples (normal CP at 30 kHz SCS, TS 38.211 Table 4.3.2-1)
#   WD  = 8     # data word width (bits, signed two's complement)
#   TW  = 10    # twiddle factor ROM word width (bits)

PARAM_1 = VALUE   # reason


## Architecture constraints
# Structural rules the RTL MUST follow. Agents treat these as hard constraints.
# ButterFold example:
#   - Share one folded butterfly unit for all DFT/IDFT/FFT/IFFT operations (area target)
#   - Block-streaming control (assert dout_valid byte-by-byte, not burst)
#   - Twiddle factors stored in synthesizable ROM (no $readmemh, no external file)
#   - Fixed-point arithmetic only — no Verilog real or float keywords anywhere
#   - Single clock domain, synchronous active-low reset
#   - All sequential logic on posedge clk only

- CONSTRAINT
- CONSTRAINT


## Timing and control model
# When does the module expect data? When does it produce output?
# ButterFold example:
#   - Block-streaming: module accepts one complete input block then produces one output block.
#   - busy asserts on the first din_valid and stays high until done pulses.
#   - done pulses high for exactly one cycle when the last output byte appears on dout.
#   - No input is accepted while busy is high (back-pressure: sender must wait).
#   - Latency is not specified — area is the priority, not throughput.

TIMING_DESCRIPTION


## What to exclude
# Tell agents what NOT to implement. This prevents over-engineering.
# ButterFold example:
#   - No channel estimation or equalisation
#   - No FEC encoder/decoder
#   - No AXI, APB, or Wishbone bus wrapper (plain valid/ready handshake only)
#   - No clock gating or power gating
#   - No CORDIC — use pre-computed twiddle ROM

- EXCLUSION
- EXCLUSION


## Reference standard (if applicable)
# If the design follows a standard, name the clause so agents can cross-reference
# the 3GPP_ButterFold_Spec_Extract.md file if it exists.
# ButterFold example:
#   3GPP TS 38.211 clause 6.3.1.1  — DFT-s-OFDM for PUSCH
#   3GPP TS 38.211 clause 5.3      — OFDM baseband signal generation
#   3GPP TS 38.211 Table 4.3.2-1  — Normal CP lengths for 30 kHz SCS

STANDARD_REFERENCE


## Verification hints (optional)
# Give agents corner cases. These become testbench test vectors.
# ButterFold example:
#   - Impulse input (I0=127, all others 0): DFT output must be flat spectrum (all bins equal magnitude)
#   - All-zero input: output must be all zeros (linearity check)
#   - Max-positive input (0x7F every sample): check for overflow or saturation clamp
#   - TX→RX loopback: feed TX output back to RX input; recovered symbols must match original within EVM < 2%

- TEST_CASE
- TEST_CASE
