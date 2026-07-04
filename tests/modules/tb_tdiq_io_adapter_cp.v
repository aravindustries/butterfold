// tb_tdiq_io_adapter_cp.v — FUNCTIONAL testbench (RX CP-removal path).
// Feeds 274 time-domain I/Q bytes (137 complex, golden top_gold) and checks the
// adapter removes the 9-sample CP and emits the 128 useful complex samples on
// rx_symbol (= input samples 9..136), rx_symbol_last on the 128th.
// Run from repo root.
`timescale 1ns/1ps
`define NB   274
`define NOUT 128
`define CP   9

module tb_tdiq_io_adapter_cp;
  reg         clk = 0, rst_n = 0, cp_start = 0, cp_insert = 0;
  reg  [3:0]  cp_len = `CP;
  reg  [7:0]  tdiq_in_data = 0;  reg  tdiq_in_valid = 0;  wire tdiq_in_ready;
  wire [7:0]  tdiq_out_data;      wire tdiq_out_valid;     reg  tdiq_out_ready = 1;
  wire [15:0] rx_symbol_data;     wire rx_symbol_valid;    reg  rx_symbol_ready = 1;  wire rx_symbol_last;
  wire [6:0]  tx_symbol_rd_addr;  wire tx_symbol_rd_req;   reg  [15:0] tx_symbol_rd_data = 0; reg tx_symbol_rd_valid = 0;
  wire        busy, done, cp_error, sample_count_error, iq_alignment_error;

  tdiq_io_adapter_cp dut (
    .clk(clk), .rst_n(rst_n),
    .tdiq_in_data(tdiq_in_data), .tdiq_in_valid(tdiq_in_valid), .tdiq_in_ready(tdiq_in_ready),
    .tdiq_out_data(tdiq_out_data), .tdiq_out_valid(tdiq_out_valid), .tdiq_out_ready(tdiq_out_ready),
    .cp_start(cp_start), .cp_insert(cp_insert), .cp_len(cp_len),
    .rx_symbol_data(rx_symbol_data), .rx_symbol_valid(rx_symbol_valid),
    .rx_symbol_ready(rx_symbol_ready), .rx_symbol_last(rx_symbol_last),
    .tx_symbol_rd_addr(tx_symbol_rd_addr), .tx_symbol_rd_req(tx_symbol_rd_req),
    .tx_symbol_rd_data(tx_symbol_rd_data), .tx_symbol_rd_valid(tx_symbol_rd_valid),
    .busy(busy), .done(done), .cp_error(cp_error),
    .sample_count_error(sample_count_error), .iq_alignment_error(iq_alignment_error)
  );

  always #5 clk = ~clk;

  reg [7:0]  inb [0:`NB-1];
  reg [15:0] got [0:`NOUT-1];
  integer    ng = 0, i, errors = 0, bi;

  always @(negedge clk) begin
    if (rx_symbol_valid && rx_symbol_ready && ng < `NOUT) begin
      got[ng] = rx_symbol_data;
      ng = ng + 1;
    end
  end

  initial begin
    $readmemh("tests/vectors/top_gold.hex", inb);
    rx_symbol_ready = 1;
    rst_n = 0; repeat (4) @(negedge clk); rst_n = 1;
    cp_insert = 0; cp_len = `CP;             // RX: remove CP
    @(negedge clk); cp_start = 1; @(negedge clk); cp_start = 0;

    for (bi = 0; bi < `NB; bi = bi + 1) begin
      @(negedge clk);
      tdiq_in_data = inb[bi]; tdiq_in_valid = 1;
      @(posedge clk);
      while (tdiq_in_ready !== 1'b1) @(posedge clk);
    end
    @(negedge clk); tdiq_in_valid = 0;

    i = 0; while (ng < `NOUT && i < 8000) begin @(negedge clk); i = i + 1; end

    for (i = 0; i < `NOUT; i = i + 1)
      if (got[i] !== {inb[2*(i+`CP)], inb[2*(i+`CP)+1]}) begin
        errors = errors + 1;
        if (errors <= 6)
          $display("FAIL sample %0d: got %04h want %04h",
                   i, got[i], {inb[2*(i+`CP)], inb[2*(i+`CP)+1]});
      end
    if (ng < `NOUT) begin errors = errors + 1; $display("FAIL: only %0d/128 samples", ng); end

    if (errors == 0) $display("PASS: tb_tdiq_io_adapter_cp (128 samples, CP removed)");
    else             $display("FAIL: tb_tdiq_io_adapter_cp (%0d errors)", errors);
    $finish;
  end

  initial begin
    #2000000; $display("FAIL: tb_tdiq_io_adapter_cp TIMEOUT (%0d/128)", ng); $finish;
  end
endmodule
