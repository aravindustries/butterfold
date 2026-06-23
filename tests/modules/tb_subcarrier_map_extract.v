// tb_subcarrier_map_extract.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'subcarrier_map_extract' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_subcarrier_map_extract;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  start;
  reg  map_not_extract;
  reg  [6:0] first_subcarrier;
  wire busy;
  wire done;
  wire config_error;
  reg  [15:0] in_data;
  reg  in_valid;
  wire in_ready;
  reg  in_last;
  wire [15:0] out_data;
  wire out_valid;
  reg  out_ready;
  wire out_last;
  wire [6:0] mem_addr;
  wire mem_write;
  wire [15:0] mem_wdata;
  reg  [15:0] mem_rdata;
  reg  mem_rvalid;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  subcarrier_map_extract dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .map_not_extract(map_not_extract),
    .first_subcarrier(first_subcarrier),
    .busy(busy),
    .done(done),
    .config_error(config_error),
    .in_data(in_data),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_last(in_last),
    .out_data(out_data),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_last(out_last),
    .mem_addr(mem_addr),
    .mem_write(mem_write),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_rvalid(mem_rvalid)
  );

  always #5 clk = ~clk;

  // valid/ready handshake on 'in': hold valid until ready
  task drive_in;
    begin
      in_valid = 1'b1;
      @(posedge clk); while (!in_ready) @(posedge clk);
      in_valid = 1'b0;
    end
  endtask

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      start = 0;
      map_not_extract = 0;
      first_subcarrier = 0;
      in_data = 0;
      in_valid = 0;
      in_last = 0;
      out_ready = 0;
      mem_rdata = 0;
      mem_rvalid = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_subcarrier_map_extract skeleton ran (add real checks)");
      else             $display("FAIL: tb_subcarrier_map_extract (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_subcarrier_map_extract TIMEOUT");
    $finish;
  end
endmodule
