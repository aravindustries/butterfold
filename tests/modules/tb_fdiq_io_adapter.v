// tb_fdiq_io_adapter.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'fdiq_io_adapter' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_fdiq_io_adapter;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  [7:0] fdiq_in_data;
  reg  fdiq_in_valid;
  wire fdiq_in_ready;
  wire [7:0] fdiq_out_data;
  wire fdiq_out_valid;
  reg  fdiq_out_ready;
  wire [15:0] fd_in_data;
  wire fd_in_valid;
  reg  fd_in_ready;
  wire fd_in_last;
  reg  [15:0] fd_out_data;
  reg  fd_out_valid;
  wire fd_out_ready;
  reg  fd_out_last;
  reg  start;
  reg  direction;
  wire busy;
  wire done;
  wire iq_alignment_error;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  fdiq_io_adapter dut (
    .clk(clk),
    .rst_n(rst_n),
    .fdiq_in_data(fdiq_in_data),
    .fdiq_in_valid(fdiq_in_valid),
    .fdiq_in_ready(fdiq_in_ready),
    .fdiq_out_data(fdiq_out_data),
    .fdiq_out_valid(fdiq_out_valid),
    .fdiq_out_ready(fdiq_out_ready),
    .fd_in_data(fd_in_data),
    .fd_in_valid(fd_in_valid),
    .fd_in_ready(fd_in_ready),
    .fd_in_last(fd_in_last),
    .fd_out_data(fd_out_data),
    .fd_out_valid(fd_out_valid),
    .fd_out_ready(fd_out_ready),
    .fd_out_last(fd_out_last),
    .start(start),
    .direction(direction),
    .busy(busy),
    .done(done),
    .iq_alignment_error(iq_alignment_error)
  );

  always #5 clk = ~clk;

  // valid/ready handshake on 'fdiq_in': hold valid until ready
  task drive_fdiq_in;
    begin
      fdiq_in_valid = 1'b1;
      @(posedge clk); while (!fdiq_in_ready) @(posedge clk);
      fdiq_in_valid = 1'b0;
    end
  endtask
  // valid/ready handshake on 'fd_out': hold valid until ready
  task drive_fd_out;
    begin
      fd_out_valid = 1'b1;
      @(posedge clk); while (!fd_out_ready) @(posedge clk);
      fd_out_valid = 1'b0;
    end
  endtask

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      fdiq_in_data = 0;
      fdiq_in_valid = 0;
      fdiq_out_ready = 0;
      fd_in_ready = 0;
      fd_out_data = 0;
      fd_out_valid = 0;
      fd_out_last = 0;
      start = 0;
      direction = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_fdiq_io_adapter skeleton ran (add real checks)");
      else             $display("FAIL: tb_fdiq_io_adapter (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_fdiq_io_adapter TIMEOUT");
    $finish;
  end
endmodule
