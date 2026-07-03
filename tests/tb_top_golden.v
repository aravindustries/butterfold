// tb_top_golden.v — top-level functional testbench (Phase 2).
// Drives butterfold_top per the spec command protocol with the golden TX input
// vector, captures the dout byte stream, and dumps it to a hex file for the
// Python EVM scorer (golden/evm_check.py) to compare against the golden output.
//
// Input : tests/vectors/top_in.hex   (24 payload bytes)
// Output: generated/rtl/top_out.hex  (captured dout bytes; may be short if the
//                                      RTL is not yet functional — the scorer
//                                      then reports the shortfall honestly)
`timescale 1ns/1ps
`define CMD_TX 8'h03
`define N_IN   24
`define N_OUT  274

module tb_top_golden;
  reg         clk = 0, rst_ni = 0;
  reg  [7:0]  din = 0;
  reg         din_valid_i = 0;
  wire        din_ready_o;
  wire [7:0]  dout;
  wire        dout_valid_o;
  reg         dout_ready_i = 1;
  wire        done_irq_o;

  reg  [7:0]  in_mem  [0:`N_IN-1];
  reg  [7:0]  out_mem [0:`N_OUT-1];
  integer     i, sent, got;

  butterfold_top dut (
    .clk_i(clk), .rst_ni(rst_ni),
    .din(din), .din_valid_i(din_valid_i), .din_ready_o(din_ready_o),
    .dout(dout), .dout_valid_o(dout_valid_o), .dout_ready_i(dout_ready_i),
    .done_irq_o(done_irq_o),
    .scan_en_i(1'b0), .scan_in_i(1'b0), .scan_out_o()
  );

  always #5 clk = ~clk;

  // capture dout whenever a valid byte is accepted
  always @(posedge clk) begin
    if (dout_valid_o && dout_ready_i && got < `N_OUT) begin
      out_mem[got] <= dout;
      got <= got + 1;
    end
  end

  task send_byte(input [7:0] b);
    begin
      @(posedge clk); din <= b; din_valid_i <= 1'b1;
      @(posedge clk); while (!din_ready_o) @(posedge clk);
      din_valid_i <= 1'b0;
    end
  endtask

  initial begin
    got = 0; sent = 0;
    $readmemh("tests/vectors/top_in.hex", in_mem);
    rst_ni = 0; repeat (6) @(posedge clk); rst_ni = 1;

    send_byte(`CMD_TX);                 // command
    for (i = 0; i < `N_IN; i = i + 1)   // payload
      send_byte(in_mem[i]);

    // wait for the design to stream out N_OUT bytes (or give up on timeout)
    for (i = 0; i < 200000 && got < `N_OUT; i = i + 1) @(posedge clk);

    // pad any uncaptured tail with 0 so the file always has N_OUT lines
    for (i = got; i < `N_OUT; i = i + 1) out_mem[i] = 8'h00;
    $writememh("generated/rtl/top_out.hex", out_mem);
    $display("tb_top_golden: captured %0d/%0d output bytes", got, `N_OUT);
    $finish;
  end

  initial begin
    #2000000;
    $display("tb_top_golden: TIMEOUT (captured %0d/%0d)", got, `N_OUT);
    for (i = got; i < `N_OUT; i = i + 1) out_mem[i] = 8'h00;
    $writememh("generated/rtl/top_out.hex", out_mem);
    $finish;
  end
endmodule
