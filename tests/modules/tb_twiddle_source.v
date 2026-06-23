// tb_twiddle_source.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'twiddle_source' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_twiddle_source;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  tw_req;
  reg  [6:0] tw_addr;
  reg  tw_conjugate;
  wire [7:0] tw_re;
  wire [7:0] tw_im;
  wire tw_valid;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  twiddle_source dut (
    .clk(clk),
    .rst_n(rst_n),
    .tw_req(tw_req),
    .tw_addr(tw_addr),
    .tw_conjugate(tw_conjugate),
    .tw_re(tw_re),
    .tw_im(tw_im),
    .tw_valid(tw_valid)
  );

  always #5 clk = ~clk;



  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      tw_req = 0;
      tw_addr = 0;
      tw_conjugate = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_twiddle_source skeleton ran (add real checks)");
      else             $display("FAIL: tb_twiddle_source (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_twiddle_source TIMEOUT");
    $finish;
  end
endmodule
