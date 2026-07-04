// tb_complex_mul.v — FUNCTIONAL testbench (ladder rung 2).
// Checks the combinational Q1.7 complex multiplier against the golden vectors
// (tests/vectors/cmul_in.hex = 4 bytes/vector, cmul_out.hex = 2 bytes/vector,
// emitted by golden/vectors.py). Bit-exact. Run from the repo root.
`timescale 1ns/1ps
`define NVEC 64

module tb_complex_mul;
  reg  signed [7:0] a_re, a_im, b_re, b_im;
  wire signed [7:0] p_re, p_im;

  reg  [7:0] ins  [0:4*`NVEC-1];
  reg  [7:0] outs [0:2*`NVEC-1];
  integer    i, errors = 0;

  complex_mul dut (
    .a_re(a_re), .a_im(a_im), .b_re(b_re), .b_im(b_im),
    .p_re(p_re), .p_im(p_im)
  );

  initial begin
    $readmemh("tests/vectors/cmul_in.hex",  ins);
    $readmemh("tests/vectors/cmul_out.hex", outs);
    for (i = 0; i < `NVEC; i = i + 1) begin
      a_re = ins[4*i+0]; a_im = ins[4*i+1];
      b_re = ins[4*i+2]; b_im = ins[4*i+3];
      #1;                                   // let the combinational logic settle
      if (p_re !== outs[2*i+0] || p_im !== outs[2*i+1]) begin
        errors = errors + 1;
        if (errors <= 6)
          $display("FAIL vec %0d: a=(%0d,%0d) b=(%0d,%0d) got (%0d,%0d) want (%0d,%0d)",
                   i, a_re, a_im, b_re, b_im, p_re, p_im,
                   $signed(outs[2*i+0]), $signed(outs[2*i+1]));
      end
      #1;
    end
    if (errors == 0) $display("PASS: tb_complex_mul (%0d vectors)", `NVEC);
    else             $display("FAIL: tb_complex_mul (%0d errors)", errors);
    $finish;
  end
endmodule
