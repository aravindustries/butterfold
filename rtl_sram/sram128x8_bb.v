// Blackbox stub for the GF180 single-port synchronous SRAM macro
// gf180mcu_fd_ip_sram__sram128x8m8wm1 (128 words x 8 bits, bit-write mask).
// Ports per the PDK behavioral model. Marked (* blackbox *) so yosys keeps the
// instances (their area/timing come from the macro .lib during stat/STA).
// CEN  : chip enable, active LOW
// GWEN : global write enable, active LOW (0 = write, 1 = read)
// WEN  : per-bit write enable, active LOW
// A    : address ; D : data in ; Q : data out (1-cycle read latency)
`default_nettype none
(* blackbox *)
module gf180mcu_fd_ip_sram__sram128x8m8wm1 (
    input  wire       CLK,
    input  wire       CEN,
    input  wire       GWEN,
    input  wire [7:0] WEN,
    input  wire [6:0] A,
    input  wire [7:0] D,
    output wire [7:0] Q
);
endmodule
`default_nettype wire
