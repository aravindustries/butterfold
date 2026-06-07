# Module Description Template
#
# HOW TO USE
# ----------
# 1. Copy this file:        cp modular_description.template.md modular_description.md
# 2. Fill in every section. Delete lines that start with '#' when done.
# 3. Run:                   python agents/orchestrator.py
#
# RULES FOR GOOD RESULTS
# ----------------------
# - Be specific about bit widths, sizes, and modes.
# - List every port with its direction and width.
# - Describe behaviour in plain English — avoid ambiguous words like "handle" or "process".
# - If a step has a fixed algorithm (e.g. radix-2 FFT), name it explicitly.
# - The more precise the spec, the fewer debug iterations the agents need.
# ============================================================================


## Module name

# Replace with your Verilog module name (snake_case, no spaces).
# Example: fir_filter, uart_tx, butterfold_top
MODULE_NAME


## One-line description

# One sentence: what does this module do and why does it exist?
# Example: "A 16-tap fixed-point FIR filter for 8-bit signed audio samples."
ONE_LINE_DESCRIPTION


## Operating modes

# List the distinct modes your module supports (e.g. TX / RX, encode / decode).
# If there is only one mode, write "Single mode — no mode select signal needed."
#
# Format:
#   MODE_NAME : brief description of what the module does in this mode
#
# Example:
#   TX : accepts k complex QAM symbols and outputs an OFDM time-domain block
#   RX : accepts an OFDM time-domain block and recovers k QAM symbols

- MODE_NAME_1 : DESCRIPTION
- MODE_NAME_2 : DESCRIPTION


## Ports

# List every port. Use this exact format so the planner agent can extract signals:
#
#   direction  name[width]   description
#
# direction : input | output
# width     : [N:0] for N+1 bits, or omit brackets for 1-bit signals
#
# Required ports (keep these, adjust widths as needed):
#   input  clk              system clock
#   input  rst_n            active-low synchronous reset
#   output busy             asserted while module is processing
#   output done             pulses high for one cycle when output block is ready

input   clk                  system clock
input   rst_n                active-low synchronous reset
input   mode                 # delete if single-mode
input   din[7:0]             # replace width and name as needed
input   din_valid            asserted when din carries valid data
output  dout[7:0]            # replace width and name as needed
output  dout_valid           asserted when dout carries valid data
output  busy                 high while module is processing a block
output  done                 pulses high for one cycle when output block is complete

# Add more ports here if needed.


## Data format

# Describe the exact format of din and dout.
# Be explicit about: bit width, signed/unsigned, I/Q interleaving, endianness, framing.
#
# Example:
#   din  : 8-bit signed (two's complement). Interleaved I/Q, one byte per cycle:
#          cycle 0 = I0, cycle 1 = Q0, cycle 2 = I1, cycle 3 = Q1, ...
#   dout : same format as din.

din  : DESCRIBE_INPUT_FORMAT
dout : DESCRIBE_OUTPUT_FORMAT


## Processing steps

# List the exact processing steps in order for each mode.
# Number them. Name algorithms explicitly (e.g. "radix-2 DIT FFT", "Gray coding").
#
# Example (TX mode):
#   1. Accumulate k = 12 complex input symbols from the din stream.
#   2. Perform a 12-point DFT using a 3×4 mixed-radix decomposition.
#   3. Map the 12 output bins into positions 0–11 of a 128-point frequency grid (zero-pad remaining bins).
#   4. Perform a 128-point IFFT using radix-2 decimation-in-time.
#   5. Prepend a cyclic prefix of length CP_LEN samples.
#   6. Serialize the output as 8-bit signed interleaved I/Q on dout.

### MODE_NAME_1
1. STEP_1
2. STEP_2
3. STEP_3

### MODE_NAME_2
1. STEP_1
2. STEP_2
3. STEP_3


## Key parameters

# List all design-time constants with their values and units.
# Format:  PARAM_NAME = VALUE   # explanation
#
# Example:
#   k   = 12      # number of DFT input symbols (one NR resource block)
#   m   = 128     # FFT/IFFT size
#   CP  = 9       # cyclic prefix length in samples
#   WD  = 8       # data path word width in bits
#   TW  = 10      # twiddle factor ROM word width in bits

PARAM_1 = VALUE   # explanation
PARAM_2 = VALUE   # explanation


## Architecture constraints

# Describe any structural constraints the RTL must respect.
# Examples of things to mention:
#   - Hardware reuse (e.g. "one shared butterfly unit for all transforms")
#   - Memory type (e.g. "in-place RAM, no external memory")
#   - Clocking (e.g. "single clock domain", "core clock = 4× IO clock")
#   - Pipelining (e.g. "fully combinational", "2-stage pipeline", "block-streaming")
#   - Area vs throughput trade-off intent

CONSTRAINT_1
CONSTRAINT_2


## Timing / control model

# Describe when the module expects data and when it produces output.
# Be explicit about latency, block size, and handshaking.
#
# Example:
#   - The module operates in block-streaming mode.
#   - Input: 2×k bytes (k I samples then k Q samples, or interleaved — specify above).
#   - busy is asserted from the first din_valid until done pulses.
#   - Output begins after the full input block has been received.
#   - done pulses high for exactly one cycle when the last output byte is on dout.

TIMING_DESCRIPTION


## What to exclude

# List anything the agent must NOT implement (saves time and avoids bloat).
# Example:
#   - No channel estimation or equalisation
#   - No FEC encoder/decoder
#   - No clock-domain crossing logic
#   - No AXI or APB bus interface (plain ready/valid only)

- EXCLUSION_1
- EXCLUSION_2


## Verification hints

# Optional. Give the agent specific test cases or corner cases to cover.
# Example:
#   - Impulse input: single non-zero sample, all others zero — check output shape
#   - All-zero input: output must be all zeros
#   - Max positive input (0x7F on every sample): check for overflow/saturation
#   - Back-to-back blocks with no gap: busy must stay high continuously

- TEST_CASE_1
- TEST_CASE_2
