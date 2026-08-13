// tb_subcarrier_map_extract.v — FUNCTIONAL testbench (TX map path).
// Feeds 12 complex samples and checks the module emits the 128-bin grid on
// out_data: input i lands at bin (first_subcarrier + i), all other bins are 0,
// out_last on bin 127. first_subcarrier = 58 (centered). Run from repo root.
`timescale 1ns/1ps
`define K     12
`define M     128
`define START 58

module tb_subcarrier_map_extract;
  reg         clk = 0, rst_n = 0, start = 0, map_not_extract = 1;
  reg  [6:0]  first_subcarrier = `START;
  wire        busy, done, config_error;
  reg  [15:0] in_data = 0;  reg in_valid = 0;  wire in_ready;  reg in_last = 0;
  wire [15:0] out_data;     wire out_valid;     reg out_ready = 1;  wire out_last;
  wire [6:0]  mem_addr;     wire mem_write;     wire [15:0] mem_wdata;
  reg  [15:0] mem_rdata = 0; reg mem_rvalid = 0;

  subcarrier_map_extract dut (
    .clk(clk), .rst_n(rst_n), .start(start), .map_not_extract(map_not_extract),
    .first_subcarrier(first_subcarrier), .busy(busy), .done(done), .config_error(config_error),
    .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready), .in_last(in_last),
    .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready), .out_last(out_last),
    .mem_addr(mem_addr), .mem_write(mem_write), .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata), .mem_rvalid(mem_rvalid)
  );

  always #5 clk = ~clk;

  reg [15:0] inv [0:`K-1];
  reg [15:0] got [0:`M-1];
  integer    ng = 0, i, errors = 0;

  always @(negedge clk) begin
    if (out_valid && out_ready && ng < `M) begin
      got[ng] = out_data;
      ng = ng + 1;
    end
  end

  initial begin
    for (i = 0; i < `K; i = i + 1) inv[i] = 16'h1001 + i*17;   // distinct nonzero values
    out_ready = 1;
    rst_n = 0; repeat (4) @(negedge clk); rst_n = 1;
    map_not_extract = 1; first_subcarrier = `START;
    @(negedge clk); start = 1; @(negedge clk); start = 0;

    for (i = 0; i < `K; i = i + 1) begin
      @(negedge clk);
      in_data = inv[i]; in_valid = 1; in_last = (i == `K-1);
      @(posedge clk);
      while (in_ready !== 1'b1) @(posedge clk);
    end
    @(negedge clk); in_valid = 0; in_last = 0;

    i = 0; while (ng < `M && i < 8000) begin @(negedge clk); i = i + 1; end

    for (i = 0; i < `M; i = i + 1) begin : chk
      reg [15:0] want;
      want = (i >= `START && i < `START + `K) ? inv[i - `START] : 16'h0000;
      if (got[i] !== want) begin
        errors = errors + 1;
        if (errors <= 6) $display("FAIL bin %0d: got %04h want %04h", i, got[i], want);
      end
    end
    if (ng < `M) begin errors = errors + 1; $display("FAIL: only %0d/128 bins", ng); end

    if (errors == 0) $display("PASS: tb_subcarrier_map_extract (128-bin grid, centered)");
    else             $display("FAIL: tb_subcarrier_map_extract (%0d errors)", errors);
    $finish;
  end

  initial begin
    #2000000; $display("FAIL: tb_subcarrier_map_extract TIMEOUT (%0d/128)", ng); $finish;
  end
endmodule
