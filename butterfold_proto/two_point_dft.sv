`timescale 1ns/1ps

module two_point_dft (
    // clk and reset
    input logic clk,
    input logic rst_n,

    // uop input
    input logic uop_in,
    input logic uop_valid,
    output logic uop_ready,

    // x0_i input
    input logic signed [15:0] x0_i,
    input logic x0_i_valid, 
    output logic x0_i_ready,

    // x0_q input
    input logic signed [15:0] x0_q,
    input logic x0_q_valid, 
    output logic x0_q_ready,

    // x1_i input
    input logic signed [15:0] x1_i,
    input logic x1_i_valid,
    output logic x1_i_ready,

    // x1_q input
    input logic signed [15:0] x1_q,
    input logic x1_q_valid,
    output logic x1_q_ready,

    // twiddle re input
    input logic signed [7:0] twiddle_re,
    input logic twiddle_re_valid,
    output logic twiddle_re_ready,

    // twiddle im input
    input logic signed [7:0] twiddle_im,
    input logic twiddle_im_valid,
    output logic twiddle_im_ready,

    // XO_i output
    output logic signed [15:0] X0_i,
    output logic X0_i_valid,
    input logic X0_i_ready,

    // X0_q output
    output logic signed [15:0] X0_q,
    output logic X0_q_valid,
    input logic X0_q_ready,

    // X1_i output
    output logic signed [15:0] X1_i,
    output logic X1_i_valid,
    input logic X1_i_ready,

    // X1_q output
    output logic signed [15:0] X1_q,
    output logic X1_q_valid,
    input logic X1_q_ready,
);


    logic current_uop;
    logic next_uop;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        current_uop <= 1'b0;
        next_uop <= 1'b0;
      end else begin
        current_uop <= next_uop;
      end

      if (uop_valid) next_uop <= uop_in;

    end

    always_comb begin
      case (current_uop)
        X0_i = x0_i + (twiddle_re*x1_i);
        X0_q = x0_q + (twiddle_im*x1_q);
        X1_i = x0_i - (twiddle_re*x1_i);
        X1_q = x0_q - (twiddle_im*x1_q);
      endcase
    end

endmodule
