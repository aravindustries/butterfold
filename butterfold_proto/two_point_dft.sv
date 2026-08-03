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

    // Outputs 
    output logic signed [15:0] X0_i,
    output logic signed [15:0] X0_q,
    output logic signed [15:0] X1_i,
    output logic signed [15:0] X1_q,
    output logic out_valid,
    input logic out_ready);

    // INPUTS
    logic uop_full;
    logic uop_reg;

    logic x0_i_full;
    logic signed [15:0] x0_i_reg;

    logic x0_q_full;
    logic signed [15:0] x0_q_reg;

    logic x1_i_full;
    logic signed [15:0] x1_i_reg;

    logic x1_q_full;
    logic signed [15:0] x1_q_reg;

    logic twiddle_re_full;
    logic signed [15:0] twiddle_re_reg;

    logic twiddle_im_full;
    logic signed [15:0] twiddle_im_reg;

    
    //OUTPUTS
    logic signed [15:0] X0_i_reg;
    logic signed [15:0] X0_q_reg;
    logic signed [15:0] X1_i_reg;
    logic signed [15:0] X1_q_reg;

    //INPUTS
    assign uop_ready = ~uop_full | compute_fire;
    assign x0_i_ready = ~x0_i_full | compute_fire;
    assign x0_q_ready = ~x0_q_full | compute_fire;
    assign x1_i_ready = ~x1_i_full | compute_fire;
    assign x1_q_ready = ~x1_q_full | compute_fire;
    assign twiddle_re_ready = ~twiddle_re_full | compute_fire;
    assign twiddle_im_ready = ~twiddle_im_full | compute_fire;

    //OUTPUTS
    assign X0_i_valid = X0_i_full; 
    assign X0_q_valid = X0_q_full; 
    assign X1_i_valid = X1_i_full; 
    assign X1_q_valid = X1_q_full; 

    assign X0_i = X0_i_reg;
    assign X0_q = X0_q_reg;
    assign X1_i = X1_i_reg;
    assign X1_q = X1_q_reg;

    wire operands_ready;
    assign operands_ready = x0_i_full & x0_q_full & x1_i_full & x1_q_full & twiddle_re_full & twiddle_im_full;

    wire output_ready;
    assign output_ready = ~(X0_i_full | X0_q_full | X1_i_full | X1_q_full) & X0_i_ready & X0_q_ready & X1_i_ready & X1_q_ready;

    wire compute_fire;
    assign compute_fire = operands_ready & output_ready;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        x0_i_full <= 1'b0;
        x0_q_full <= 1'b0;
        x1_i_full <= 1'b0;
        x1_q_full <= 1'b0;
        twiddle_re_full <= '0;
        twiddle_im_full <= '0;
        uop_full <= 1'b0;

        x0_i_reg <= '0;
        x0_q_reg <= '0;
        x1_i_reg <= '0;
        x1_q_reg <= '0;
        twiddle_re_full <= '0;
        twiddle_im_full <= '0;
        uop_full <= 1'b0;

        X0_i_full <= 1'b0; 
        X0_q_full <= 1'b0;
        X1_i_full <= 1'b0;
        X1_q_full <= 1'b0;
        X0_i_reg <= '0; 
        X0_q_reg <= '0;
        X1_i_reg <= '0;
        X1_q_reg <= '0;
      end else begin
        if (compute_fire) begin
          X0_i_reg <= x0_i_reg + (twiddle_re_reg*x1_i_reg);
          X0_q_reg <= x0_q_reg + (twiddle_im_reg*x1_q_reg);
          X1_i_reg <= x0_i_reg - (twiddle_re_reg*x1_i_reg);
          X1_q_reg <= x0_q_reg - (twiddle_im_reg*x1_q_reg);
          X0_i_full <= 1'b1; 
          X0_q_full <= 1'b1;
          X1_i_full <= 1'b1;
          X1_q_full <= 1'b1;
        end else if (
      end
    end

endmodule
