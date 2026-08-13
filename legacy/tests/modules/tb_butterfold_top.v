// tb_butterfold_top.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'butterfold_top' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_butterfold_top;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  clk_i;
  reg  rst_ni;
  reg  [7:0] din;
  reg  din_valid_i;
  wire din_ready_o;
  wire [7:0] dout;
  wire dout_valid_o;
  reg  dout_ready_i;
  wire done_irq_o;
  reg  scan_en_i;
  reg  scan_in_i;
  wire scan_out_o;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  butterfold_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .din(din),
    .din_valid_i(din_valid_i),
    .din_ready_o(din_ready_o),
    .dout(dout),
    .dout_valid_o(dout_valid_o),
    .dout_ready_i(dout_ready_i),
    .done_irq_o(done_irq_o),
    .scan_en_i(scan_en_i),
    .scan_in_i(scan_in_i),
    .scan_out_o(scan_out_o)
  );

  always #5 clk_i = ~clk_i;



  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      clk_i = 0;
      rst_ni = 0;
      din = 0;
      din_valid_i = 0;
      dout_ready_i = 0;
      scan_en_i = 0;
      scan_in_i = 0;
      rst_ni = 1'b0; repeat(4) @(posedge clk_i); rst_ni = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk_i);
      if (errors == 0) $display("PASS: tb_butterfold_top skeleton ran (add real checks)");
      else             $display("FAIL: tb_butterfold_top (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_butterfold_top TIMEOUT");
    $finish;
  end
endmodule
