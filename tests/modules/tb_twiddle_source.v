// tb_twiddle_source.v — FUNCTIONAL testbench (authoring ladder, twiddle rung).
// Checks the RTL against the golden twiddle LUT (tests/vectors/twiddle_{re,im}.hex,
// emitted by golden/vectors.py). Bit-exact on the int8 output, plus conjugation.
// Run from the repo root so the relative $readmemh paths resolve.
`timescale 1ns/1ps

module tb_twiddle_source;
  reg         clk = 0, rst_n = 0, tw_req = 0, tw_conjugate = 0;
  // Init to an out-of-range address so the FIRST real lookup (addr 0) is a
  // genuine transition — otherwise iverilog's `always @*` never fires at t=0
  // for an unchanged input and the combinational LUT reads X (sim-only quirk).
  reg  [6:0]  tw_addr = 7'h7f;
  wire [7:0]  tw_re, tw_im;
  wire        tw_valid;

  reg  [7:0]  exp_re [0:11];
  reg  [7:0]  exp_im [0:11];
  integer     errors = 0, a, wc;

  twiddle_source dut (
    .clk(clk), .rst_n(rst_n), .tw_req(tw_req), .tw_addr(tw_addr),
    .tw_conjugate(tw_conjugate), .tw_re(tw_re), .tw_im(tw_im), .tw_valid(tw_valid)
  );

  always #5 clk = ~clk;

  // Drive and sample on the NEGEDGE so we never race the DUT's posedge
  // non-blocking register updates (which would cause false failures).
  task check(input [6:0] addr, input conj);
    reg [7:0] want_re, want_im;
    begin
      @(negedge clk); tw_addr = addr; tw_conjugate = conj; tw_req = 1'b1;
      @(negedge clk); tw_req = 1'b0;         // tw_req was high across one posedge
      wc = 0;
      while (!tw_valid && wc < 32) begin @(negedge clk); wc = wc + 1; end
      want_re = exp_re[addr];
      want_im = conj ? (~exp_im[addr] + 8'd1) : exp_im[addr];   // conjugate = negate imag
      if (!tw_valid) begin
        errors = errors + 1;
        $display("FAIL addr %0d: tw_valid never asserted", addr);
      end else if (tw_re !== want_re || tw_im !== want_im) begin
        errors = errors + 1;
        $display("FAIL addr %0d conj%0d: got (%0d,%0d) want (%0d,%0d)",
                 addr, conj, $signed(tw_re), $signed(tw_im),
                 $signed(want_re), $signed(want_im));
      end
    end
  endtask

  initial begin
    $readmemh("tests/vectors/twiddle_re.hex", exp_re);
    $readmemh("tests/vectors/twiddle_im.hex", exp_im);
    rst_n = 0; repeat (4) @(posedge clk); rst_n = 1;

    for (a = 0; a < 12; a = a + 1) check(a[6:0], 1'b0);   // all 12 twiddles
    check(7'd1, 1'b1);                                     // conjugate spot-checks
    check(7'd3, 1'b1);

    if (errors == 0) $display("PASS: tb_twiddle_source (12 twiddles + conjugate)");
    else             $display("FAIL: tb_twiddle_source (%0d errors)", errors);
    $finish;
  end

  initial begin
    #100000; $display("FAIL: tb_twiddle_source TIMEOUT"); $finish;
  end
endmodule
