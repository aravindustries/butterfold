// sram128x8_behav.v — FUNCTIONAL simulation model of the GF180 single-port SRAM
// macro gf180mcu_fd_ip_sram__sram128x8m8wm1 (128 words x 8 bits, bit-write mask).
//
// This is a clean behavioral model for FUNCTIONAL verification only (used by the
// core golden-check testbench). It deliberately omits the PDK signoff model's
// `specify` timing checks and CEN-reset sequencing, which are meant for SDF /
// back-annotated simulation and would (a) flag setup/hold violations at a fast
// functional test clock and (b) require a CEN 1->0 edge the core never drives.
//
// Semantics (match the macro's datasheet + the core's usage):
//   CEN  chip enable, active LOW  (0 = enabled)
//   GWEN global write enable, active LOW (0 = write, 1 = read)
//   WEN  per-bit write enable, active LOW (bit=0 -> that bit is written)
//   A    address ; D data in ; Q data out, registered with 1-cycle read latency.
// On a write cycle Q holds (no read). Synthesis/LEF still use sram128x8_bb.v.
`default_nettype none
`timescale 1ns/1ps
module gf180mcu_fd_ip_sram__sram128x8m8wm1 (
    input  wire       CLK,
    input  wire       CEN,
    input  wire       GWEN,
    input  wire [7:0] WEN,
    input  wire [6:0] A,
    input  wire [7:0] D,
    output reg  [7:0] Q
);
    reg [7:0] mem [0:127];
    integer k;
    initial begin
        for (k = 0; k < 128; k = k + 1) mem[k] = 8'd0;
        Q = 8'd0;
    end

    always @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN)                          // write: per-bit mask (WEN active low)
                mem[A] <= (mem[A] & WEN) | (D & ~WEN);
            else                                // read: 1-cycle latency
                Q <= mem[A];
        end
    end
endmodule
`default_nettype wire
