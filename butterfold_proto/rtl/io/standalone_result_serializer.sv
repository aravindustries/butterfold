`timescale 1ns/1ps
`default_nettype none

//==============================================================================
// Standalone result serializer
//
// Converts the transform core's parallel diagnostic result transaction into the
// final 8-bit dout stream.  External dout_ready_i backpressure holds the
// current byte until handshake.  The producer result slot stays claimed for
// the whole record.
//
// Serialization format: one 5-byte record per complex output, in transaction
// order X0, X1, then X2 when result_radix_i == 3:
//
//   byte 0 : {1'b0, result_addr[6:0]}
//   byte 1 : I[15:8]
//   byte 2 : I[7:0]
//   byte 3 : Q[15:8]
//   byte 4 : Q[7:0]
//
// Therefore:
//   radix-2 result transaction -> 10 bytes
//   radix-3 result transaction -> 15 bytes
//
// The address byte preserves the information formerly carried by the parallel
// result_addr*_o pins, so DFT12/FFT128/IFFT128 outputs can be reconstructed in
// natural-address order by the external diagnostic host without an on-chip
// 128-sample reorder buffer.
//==============================================================================
module standalone_result_serializer (
    input  logic clk,
    input  logic rst_n,

    input  logic enable_i,

    input  logic signed [15:0] X0_i_i,
    input  logic signed [15:0] X0_q_i,
    input  logic signed [15:0] X1_i_i,
    input  logic signed [15:0] X1_q_i,
    input  logic signed [15:0] X2_i_i,
    input  logic signed [15:0] X2_q_i,

    input  logic [6:0] result_addr0_i,
    input  logic [6:0] result_addr1_i,
    input  logic [6:0] result_addr2_i,
    input  logic [1:0] result_radix_i,
    input  logic       result_last_i,
    input  logic       result_valid_i,
    output logic       result_ready_o,

    output logic [7:0] dout_o,
    output logic       dout_valid_o,
    input  logic       dout_ready_i,
    output logic       busy_o,
    output logic       transaction_done_o,
    output logic       job_done_o
);

    logic [3:0] byte_index;
    wire [3:0] final_byte_index =
        (result_radix_i == 2'd3) ? 4'd14 : 4'd9;

    wire dout_fire = dout_valid_o && dout_ready_i;

    // The producer already owns a stable elastic result slot. Keep it
    // backpressured throughout serialization and release it with the final
    // accepted byte instead of copying the complete transaction here.
    assign result_ready_o = enable_i && busy_o &&
        (byte_index == final_byte_index) && dout_fire;
    assign dout_valid_o   = busy_o;

    always @* begin
        case (byte_index)
            4'd0:  dout_o = {1'b0, result_addr0_i};
            4'd1:  dout_o = X0_i_i[15:8];
            4'd2:  dout_o = X0_i_i[7:0];
            4'd3:  dout_o = X0_q_i[15:8];
            4'd4:  dout_o = X0_q_i[7:0];

            4'd5:  dout_o = {1'b0, result_addr1_i};
            4'd6:  dout_o = X1_i_i[15:8];
            4'd7:  dout_o = X1_i_i[7:0];
            4'd8:  dout_o = X1_q_i[15:8];
            4'd9:  dout_o = X1_q_i[7:0];

            4'd10: dout_o = {1'b0, result_addr2_i};
            4'd11: dout_o = X2_i_i[15:8];
            4'd12: dout_o = X2_i_i[7:0];
            4'd13: dout_o = X2_q_i[15:8];
            4'd14: dout_o = X2_q_i[7:0];

            default: dout_o = 8'h00;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_index <= 4'd0;
            busy_o <= 1'b0;
            transaction_done_o <= 1'b0;
            job_done_o <= 1'b0;
        end else begin
            transaction_done_o <= 1'b0;
            job_done_o <= 1'b0;

            if (!busy_o && enable_i && result_valid_i) begin
                byte_index <= 4'd0;
                busy_o <= 1'b1;
            end else if (busy_o && dout_fire) begin
                if (byte_index == final_byte_index) begin
                    busy_o <= 1'b0;
                    byte_index <= 4'd0;
                    transaction_done_o <= 1'b1;
                    if (result_last_i)
                        job_done_o <= 1'b1;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
