`timescale 1ns/1ps
`default_nettype none

// Four 128x8 foundry macros in parallel form one 128x32 complex-sample store.
// Packing: {Q[15:0], I[15:0]}.
module gf180_sram_128x32_complex (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req_i,
    input  logic        write_i,
    input  logic [6:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic        rvalid_o
);
    logic [7:0] q0, q1, q2, q3;
    logic rv0, rv1, rv2, rv3;

    gf180_sram_128x8_wrapper u_i_lo (
        .clk(clk), .rst_n(rst_n), .req_i(req_i), .write_i(write_i),
        .addr_i(addr_i), .wdata_i(wdata_i[7:0]), .wmask_i(8'hff),
        .rdata_o(q0), .rvalid_o(rv0)
    );
    gf180_sram_128x8_wrapper u_i_hi (
        .clk(clk), .rst_n(rst_n), .req_i(req_i), .write_i(write_i),
        .addr_i(addr_i), .wdata_i(wdata_i[15:8]), .wmask_i(8'hff),
        .rdata_o(q1), .rvalid_o(rv1)
    );
    gf180_sram_128x8_wrapper u_q_lo (
        .clk(clk), .rst_n(rst_n), .req_i(req_i), .write_i(write_i),
        .addr_i(addr_i), .wdata_i(wdata_i[23:16]), .wmask_i(8'hff),
        .rdata_o(q2), .rvalid_o(rv2)
    );
    gf180_sram_128x8_wrapper u_q_hi (
        .clk(clk), .rst_n(rst_n), .req_i(req_i), .write_i(write_i),
        .addr_i(addr_i), .wdata_i(wdata_i[31:24]), .wmask_i(8'hff),
        .rdata_o(q3), .rvalid_o(rv3)
    );

    always @* begin
        rdata_o = {q3, q2, q1, q0};
        rvalid_o = rv0 & rv1 & rv2 & rv3;
    end
endmodule

`default_nettype wire
