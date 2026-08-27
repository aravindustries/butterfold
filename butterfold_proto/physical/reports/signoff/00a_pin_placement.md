# 00a — North/West pin placement

Branch: `pin-placement-redesign`. RTL/golden/clock/SRAM/die unchanged. No padframe.

Final physical database (hold-ECO + fill ODB) **PIN_SIDES_PASS**.

| terminal | side | x_um | y_um | layer |
|---|---|---|---|---|
| rst_n | WEST | 0.000 | 63.000 | Metal3 |
| clk | WEST | 0.000 | 161.560 | Metal3 |
| din[7] | WEST | 0.000 | 260.120 | Metal3 |
| din[6] | WEST | 0.000 | 358.680 | Metal3 |
| din[5] | WEST | 0.000 | 457.240 | Metal3 |
| din[4] | WEST | 0.000 | 555.800 | Metal3 |
| din[3] | WEST | 0.000 | 654.360 | Metal3 |
| din[2] | WEST | 0.000 | 752.920 | Metal3 |
| din[1] | WEST | 0.000 | 851.480 | Metal3 |
| din[0] | WEST | 0.000 | 950.040 | Metal3 |
| din_valid_i | WEST | 0.000 | 1048.600 | Metal3 |
| din_ready_o | NORTH | 40.600 | 1119.540 | Metal2 |
| dout[7] | NORTH | 107.800 | 1119.540 | Metal2 |
| dout[6] | NORTH | 175.000 | 1119.540 | Metal2 |
| dout[5] | NORTH | 242.200 | 1119.540 | Metal2 |
| dout[4] | NORTH | 309.400 | 1119.540 | Metal2 |
| dout[3] | NORTH | 376.600 | 1119.540 | Metal2 |
| dout[2] | NORTH | 443.800 | 1119.540 | Metal2 |
| dout[1] | NORTH | 511.000 | 1119.540 | Metal2 |
| dout[0] | NORTH | 578.200 | 1119.540 | Metal2 |
| dout_valid_o | NORTH | 645.400 | 1119.540 | Metal2 |
| VDD | NORTH | 944.440 | 1119.540 | Metal4 |
| VSS | NORTH | 947.800 | 1119.540 | Metal4 |

Counts: NORTH 12, WEST 11, EAST 0, SOUTH 0, TOTAL 23.

Configuration: `physical/librelane/pin_order.cfg` via `IO_PIN_ORDER_CFG`.
VDD/VSS north-edge access: `physical/scripts/place_power_pins_north.tcl` on existing POWER ports after PDN (LibreLane `io_place.py` skips POWER/GROUND).

Native dump: [evidence/pins/final_odb_pins.rpt](evidence/pins/final_odb_pins.rpt)

Promoted GDS SHA-256
`6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12`.
VDD/VSS remain the existing RTL `USE_POWER_PINS` ports (not new pads).
