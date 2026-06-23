// tb_tdiq_io_adapter_cp.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module 'tdiq_io_adapter_cp' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_tdiq_io_adapter_cp;
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
  reg  clk;
  reg  rst_n;
  reg  [7:0] tdiq_in_data;
  reg  tdiq_in_valid;
  wire tdiq_in_ready;
  wire [7:0] tdiq_out_data;
  wire tdiq_out_valid;
  reg  tdiq_out_ready;
  reg  cp_start;
  reg  cp_insert;
  reg  [3:0] cp_len;
  wire [15:0] rx_symbol_data;
  wire rx_symbol_valid;
  reg  rx_symbol_ready;
  wire rx_symbol_last;
  wire [6:0] tx_symbol_rd_addr;
  wire tx_symbol_rd_req;
  reg  [15:0] tx_symbol_rd_data;
  reg  tx_symbol_rd_valid;
  wire busy;
  wire done;
  wire cp_error;
  wire sample_count_error;
  wire iq_alignment_error;

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  tdiq_io_adapter_cp dut (
    .clk(clk),
    .rst_n(rst_n),
    .tdiq_in_data(tdiq_in_data),
    .tdiq_in_valid(tdiq_in_valid),
    .tdiq_in_ready(tdiq_in_ready),
    .tdiq_out_data(tdiq_out_data),
    .tdiq_out_valid(tdiq_out_valid),
    .tdiq_out_ready(tdiq_out_ready),
    .cp_start(cp_start),
    .cp_insert(cp_insert),
    .cp_len(cp_len),
    .rx_symbol_data(rx_symbol_data),
    .rx_symbol_valid(rx_symbol_valid),
    .rx_symbol_ready(rx_symbol_ready),
    .rx_symbol_last(rx_symbol_last),
    .tx_symbol_rd_addr(tx_symbol_rd_addr),
    .tx_symbol_rd_req(tx_symbol_rd_req),
    .tx_symbol_rd_data(tx_symbol_rd_data),
    .tx_symbol_rd_valid(tx_symbol_rd_valid),
    .busy(busy),
    .done(done),
    .cp_error(cp_error),
    .sample_count_error(sample_count_error),
    .iq_alignment_error(iq_alignment_error)
  );

  always #5 clk = ~clk;

  // valid/ready handshake on 'tdiq_in': hold valid until ready
  task drive_tdiq_in;
    begin
      tdiq_in_valid = 1'b1;
      @(posedge clk); while (!tdiq_in_ready) @(posedge clk);
      tdiq_in_valid = 1'b0;
    end
  endtask

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
      clk = 0;
      rst_n = 0;
      tdiq_in_data = 0;
      tdiq_in_valid = 0;
      tdiq_out_ready = 0;
      cp_start = 0;
      cp_insert = 0;
      cp_len = 0;
      rx_symbol_ready = 0;
      tx_symbol_rd_data = 0;
      tx_symbol_rd_valid = 0;
      rst_n = 1'b0; repeat(4) @(posedge clk); rst_n = 1'b1;

      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge clk);
      if (errors == 0) $display("PASS: tb_tdiq_io_adapter_cp skeleton ran (add real checks)");
      else             $display("FAIL: tb_tdiq_io_adapter_cp (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_tdiq_io_adapter_cp TIMEOUT");
    $finish;
  end
endmodule
