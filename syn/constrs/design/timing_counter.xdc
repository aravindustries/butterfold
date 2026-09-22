# timing_counter.xdc -- timing constraints for the `counter` FPGA prototype.
#
# NOTE: an XDC is not free-form Tcl. Vivado rejects control flow in it
# ("CRITICAL WARNING: [Designutils 20-1307] Command 'if' is not supported in the
# xdc constraint file"), so there is no conditional clock selection here -- this
# file targets the `counter` top, whose clock port is `clk`.

# Same period as the ASIC target (project-root config.yaml, LibreLane/GF180MCU:
# CLOCK_PERIOD: 50). For the board_top design the clock arrives on zynq_fclk at
# 125 MHz (period 8.000) and boards/Zybo-pinout.xdc + design/debug.xdc already
# constrain it.
set CLK_PERIOD 50.000

# ---- 1. Clock ---------------------------------------------------------
create_clock -name clk -period $CLK_PERIOD -waveform {0.000 25.000} [get_ports clk]

# ---- 2. Clock uncertainty (setup + hold) ------------------------------
# User uncertainty, added on top of the tool's own jitter calculation
# (UG835: set_clock_uncertainty; setup slack includes it, hold slack too).
set_clock_uncertainty -setup 0.500 [get_clocks clk]
set_clock_uncertainty -hold  0.250 [get_clocks clk]

# ---- 3. Optional: I/O timing ------------------------------------------
# Uncomment to make synthesis timing-driven at the ports.
# set_input_delay  -clock clk 2.000 [get_ports rst]
# set_output_delay -clock clk 2.000 [get_ports q[*]]

# ---- 4. Max transition: NOT AVAILABLE IN VIVADO -----------------------
# `set_max_transition` is not a Vivado command. Placed in an XDC it is skipped:
#   CRITICAL WARNING: [Designutils 20-1307] Command 'set_max_transition'
#   is not supported in the xdc constraint file.
# There is also no synth_design option for it. The equivalent knob is the ASIC
# flow: MAX_TRANSITION_CONSTRAINT in the LibreLane config.yaml.
# set_max_transition 1.000 [get_clocks clk]
