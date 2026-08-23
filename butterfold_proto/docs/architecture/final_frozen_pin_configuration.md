## FINAL PIN CONFIGURATION:

# INPUT (12):
- rst_n
- clk
- din[7:0]
- din_valid_i
- dout_ready_i

# OUTPUT (10):
- din_ready_o
- dout[7:0]
- dout_valid_o

# POWER (2):
- VDD
- VSS

# TOTAL: 24

Output handshake: a byte is transferred only when `dout_valid_o && dout_ready_i`.
While valid is asserted and ready is low, `dout` must remain stable.

Power pins follow the existing `USE_POWER_PINS` convention on the production
hierarchy (`butterfold_top`, transform core, SRAM wrappers/macros).

## Obsolete 22-pin configuration (do not use)

INPUT (11): rst_n, clk, din[7:0], din_valid_i

OUTPUT (10): din_ready_o, dout[7:0], dout_valid_o

POWER (1): VDD

TOTAL: 22

That configuration treated VSS as implicit and assumed the downstream device
was always ready whenever `dout_valid_o` was asserted.
