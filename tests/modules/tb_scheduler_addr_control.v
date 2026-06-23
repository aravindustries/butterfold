// tb_scheduler_addr_control.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'scheduler_addr_control' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_scheduler_addr_control;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  cmd_valid;
  wire cmd_ready;
  reg  [2:0] cmd_op;
  reg  long_cp;
  wire uop_valid;
  reg  uop_ready;
  wire [1:0] uop_radix;
  wire uop_inverse;
  wire [2:0] uop_scale_shift;
  wire uop_last;
  wire [6:0] src_addr_0;
  wire [6:0] src_addr_1;
  wire [6:0] src_addr_2;
  wire [6:0] dst_addr_0;
  wire [6:0] dst_addr_1;
  wire [6:0] dst_addr_2;
  wire tw_req;
  wire [6:0] tw_addr;
  wire tw_conjugate;
  reg  tw_valid;
  wire map_start;
  wire map_direction;
  wire [6:0] first_subcarrier;
  reg  map_done;
  wire cp_start;
  wire cp_insert;
  wire [3:0] cp_len;
  reg  cp_done;
  wire input_bank_select;
  wire output_bank_select;
  wire busy;
  wire done;
  wire error;
  wire [15:0] cycle_count;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  scheduler_addr_control dut (
    .clk(clk),
    .rst_n(rst_n),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_op(cmd_op),
    .long_cp(long_cp),
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
    .tw_req(tw_req),
    .tw_addr(tw_addr),
    .tw_conjugate(tw_conjugate),
    .tw_valid(tw_valid),
    .map_start(map_start),
    .map_direction(map_direction),
    .first_subcarrier(first_subcarrier),
    .map_done(map_done),
    .cp_start(cp_start),
    .cp_insert(cp_insert),
    .cp_len(cp_len),
    .cp_done(cp_done),
    .input_bank_select(input_bank_select),
    .output_bank_select(output_bank_select),
    .busy(busy),
    .done(done),
    .error(error),
    .cycle_count(cycle_count)
  );

  always #5 clk = ~clk;

  // valid/ready handshake on 'cmd': hold valid until ready
  task drive_cmd;
    begin
      cmd_valid = 1'b1;
      @(posedge clk); while (!cmd_ready) @(posedge clk);
      cmd_valid = 1'b0;
    end
  endtask

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      cmd_valid = 0;
      cmd_op = 0;
      long_cp = 0;
      uop_ready = 0;
      tw_valid = 0;
      map_done = 0;
      cp_done = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_scheduler_addr_control skeleton ran (add real checks)");
      else             $display("FAIL: tb_scheduler_addr_control (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_scheduler_addr_control TIMEOUT");
    $finish;
  end
endmodule
