// tb_unified_mixed_radix_core.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'unified_mixed_radix_core' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_unified_mixed_radix_core;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  uop_valid;
  wire uop_ready;
  reg  [1:0] uop_radix;
  reg  uop_inverse;
  reg  [2:0] uop_scale_shift;
  reg  uop_last;
  reg  [6:0] src_addr_0;
  reg  [6:0] src_addr_1;
  reg  [6:0] src_addr_2;
  reg  [6:0] dst_addr_0;
  reg  [6:0] dst_addr_1;
  reg  [6:0] dst_addr_2;
  reg  [7:0] twiddle_re;
  reg  [7:0] twiddle_im;
  reg  twiddle_valid;
  reg  [6:0] load_addr;
  reg  [15:0] load_data;
  reg  load_valid;
  wire load_ready;
  reg  [6:0] read_addr;
  reg  read_req;
  wire [15:0] read_data;
  wire read_valid;
  wire uop_done;
  wire overflow;
  wire saturation_occurred;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  unified_mixed_radix_core dut (
    .clk(clk),
    .rst_n(rst_n),
    .uop_valid(uop_valid),
    .uop_ready(uop_ready),
    .uop_radix(uop_radix),
    .uop_inverse(uop_inverse),
    .uop_scale_shift(uop_scale_shift),
    .uop_last(uop_last),
    .src_addr_0(src_addr_0),
    .src_addr_1(src_addr_1),
    .src_addr_2(src_addr_2),
    .dst_addr_0(dst_addr_0),
    .dst_addr_1(dst_addr_1),
    .dst_addr_2(dst_addr_2),
    .twiddle_re(twiddle_re),
    .twiddle_im(twiddle_im),
    .twiddle_valid(twiddle_valid),
    .load_addr(load_addr),
    .load_data(load_data),
    .load_valid(load_valid),
    .load_ready(load_ready),
    .read_addr(read_addr),
    .read_req(read_req),
    .read_data(read_data),
    .read_valid(read_valid),
    .uop_done(uop_done),
    .overflow(overflow),
    .saturation_occurred(saturation_occurred)
  );

  always #5 clk = ~clk;

  // valid/ready handshake on 'uop': hold valid until ready
  task drive_uop;
    begin
      uop_valid = 1'b1;
      @(posedge clk); while (!uop_ready) @(posedge clk);
      uop_valid = 1'b0;
    end
  endtask
  // valid/ready handshake on 'load': hold valid until ready
  task drive_load;
    begin
      load_valid = 1'b1;
      @(posedge clk); while (!load_ready) @(posedge clk);
      load_valid = 1'b0;
    end
  endtask

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      uop_valid = 0;
      uop_radix = 0;
      uop_inverse = 0;
      uop_scale_shift = 0;
      uop_last = 0;
      src_addr_0 = 0;
      src_addr_1 = 0;
      src_addr_2 = 0;
      dst_addr_0 = 0;
      dst_addr_1 = 0;
      dst_addr_2 = 0;
      twiddle_re = 0;
      twiddle_im = 0;
      twiddle_valid = 0;
      load_addr = 0;
      load_data = 0;
      load_valid = 0;
      read_addr = 0;
      read_req = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_unified_mixed_radix_core skeleton ran (add real checks)");
      else             $display("FAIL: tb_unified_mixed_radix_core (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_unified_mixed_radix_core TIMEOUT");
    $finish;
  end
endmodule
