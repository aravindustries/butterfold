`timescale 1ps/1ns


module scheduler(
  input logic clk,
  input logic rst_n,
  input logic[7:0] din,
  input logic din_valid_i,
  input logic dout_ready_i,

  output logic [7:0] dout,
  output logic dout_valid_o,
  output logic din_ready_i);

logic uop_in;
logic uop_valid;
logic uop_ready;

logic signed [15:0] x0_i;
logic               x0_i_valid;
logic               x0_i_ready;
                              
logic signed [15:0] x0_q;
logic               x0_q_valid;
logic               x0_q_ready;
                              
logic signed [15:0] x1_i;
logic               x1_i_valid;
logic               x1_i_ready;
                              
logic signed [15:0] x1_q;
logic               x1_q_valid;
logic               x1_q_ready;
                               
logic signed [7:0] twiddle_re;
logic              twiddle_re_v;
logic              twiddle_re_r;
                               
logic signed [7:0] twiddle_im;
logic              twiddle_im_v;
logic              twiddle_im_r;
                               
logic signed [15:0] X0_i;      
logic signed [15:0] X0_q;      
logic signed [15:0] X1_i;      
logic signed [15:0] X1_q;      
logic               out_valid;
logic               out_ready;

logic [1:0] butterfly_count;

typedef enum logic [1:0] {
  IDLE = 2'b00;
  FFT2 = 2'b01;
} state_t;

state_t current_state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    next_state <= IDLE;
    butterfly_count <= 0;
  end else begin
    current_state <= next_state;
  end

  if (current_state_state == FFT2) begin
    if (butterfly_count == 2'b11) begin
      butterfly_count = butterfly_count + 1;
    end
  end
end

always_comb begin
  case (current_state)
    IDLE: begin
      uop_in = 1'b0;
      uop_valid = 1'b0;
      x0_i_valid = 1'b0;
      x0_q_valid = 1'b0;
      x1_i_valid = 1'b0;
      x1_q_valid = 1'b0;
      twiddle_re_valid = 1'b0;
      twiddle_im_valid = 1'b0;

      out_ready = 1'b0;

      // Assume the first data in is a command
      if (din == 8'b0100_0000) begin // cmd=1 -> FFT2
        next_state = FFT2;
      end else begin
        next_state = IDLE;
      end
    end
    FFT2: begin
      uop_in = 1'b1; //uop_in = 1 -> FFT2
      uop_valid = 1'b1;

      out_ready = 1'b1;

    end
    default: begin
      uop_in = 1'b0;
      uop_valid = 1'b0;
      x0_i_valid = 1'b0;
      x0_q_valid = 1'b0;
      x1_i_valid = 1'b0;
      x1_q_valid = 1'b0;
      twiddle_re_valid = 1'b0;
      twiddle_im_valid = 1'b0;

      out_ready = 1'b0;

      next_state = IDLE;
    end
  endcase
end

two_point_dft(
  .clk(clk),
  .rst_n(rst_n),
  .uop_in(uop_in),
  .uop_valid(uop_valid),
  .uop_ready(uop_ready),

  .x0_i(x0_i),
  .x0_i_valid(x0_i_valid),
  .x0_i_ready(x0_i_ready),
  .x0_q(x0_q),
  .x0_q_valid(x0_q_valid),
  .x0_q_ready(x0_q_ready),

  .x1_i(x1_i),
  .x1_i_valid(x1_i_valid),
  .x1_i_ready(x1_i_ready),
  .x1_q(x1_q),
  .x1_q_valid(x1_q_valid),
  .x1_q_ready(x1_q_ready),

  .twiddle_re(twiddle_re),
  .twiddle_re_valid(twiddle_re_valid),
  .twiddle_re_ready(twiddle_re_ready),

  .twiddle_im(twiddle_im),
  .twiddle_im_valid(twiddle_im_valid),
  .twiddle_im_ready(twiddle_im_ready),

  .X0_i(X0_i),
  .X0_q(X0_q),
  .X1_i(X1_i),
  .X1_q(X1_q),

  .out_valid(out_valid),
  .out_valid(out_ready));

endmodule
