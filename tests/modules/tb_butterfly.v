// tb_butterfly.v — FUNCTIONAL testbench (ladder rung 3).
// Checks the combinational radix-2 butterfly (Q5.11 samples, Q1.7 twiddle) against
// the golden vectors (tests/vectors/bfly_in.hex = 6 words/vec, bfly_out.hex = 4
// words/vec, emitted by golden/vectors.py). Bit-exact. Run from the repo root.
`timescale 1ns/1ps
`define NVEC 64

module tb_butterfly;
  reg  signed [15:0] top_re, top_im, bot_re, bot_im;
  reg  signed [7:0]  w_re, w_im;
  wire signed [15:0] otop_re, otop_im, obot_re, obot_im;

  reg  [15:0] ins  [0:6*`NVEC-1];
  reg  [15:0] outs [0:4*`NVEC-1];
  integer     i, errors = 0;

  butterfly dut (
    .top_re(top_re), .top_im(top_im), .bot_re(bot_re), .bot_im(bot_im),
    .w_re(w_re), .w_im(w_im),
    .otop_re(otop_re), .otop_im(otop_im), .obot_re(obot_re), .obot_im(obot_im)
  );

  initial begin
    $readmemh("tests/vectors/bfly_in.hex",  ins);
    $readmemh("tests/vectors/bfly_out.hex", outs);
    for (i = 0; i < `NVEC; i = i + 1) begin
      top_re = ins[6*i+0]; top_im = ins[6*i+1];
      bot_re = ins[6*i+2]; bot_im = ins[6*i+3];
      w_re   = ins[6*i+4][7:0]; w_im = ins[6*i+5][7:0];
      #1;
      if (otop_re !== outs[4*i+0] || otop_im !== outs[4*i+1] ||
          obot_re !== outs[4*i+2] || obot_im !== outs[4*i+3]) begin
        errors = errors + 1;
        if (errors <= 6)
          $display("FAIL vec %0d: got top(%0d,%0d) bot(%0d,%0d) want top(%0d,%0d) bot(%0d,%0d)",
                   i, otop_re, otop_im, obot_re, obot_im,
                   $signed(outs[4*i+0]), $signed(outs[4*i+1]),
                   $signed(outs[4*i+2]), $signed(outs[4*i+3]));
      end
      #1;
    end
    if (errors == 0) $display("PASS: tb_butterfly (%0d vectors)", `NVEC);
    else             $display("FAIL: tb_butterfly (%0d errors)", errors);
    $finish;
  end
endmodule
