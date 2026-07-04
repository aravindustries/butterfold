// tb_top_rx.v — top-level RX functional testbench.
// Feeds the 274-byte TX output (top_gold) with command 0x04 (RX) and captures the
// 24-byte recovered-symbol output, dumped for the Python scorer (compare to
// rx_gold, and EVM vs the original top_in = loopback fidelity).
`timescale 1ns/1ps
`define CMD_RX 8'h04
`define N_IN   274
`define N_OUT  24

module tb_top_rx;
  reg         clk = 0, rst_ni = 0;
  reg  [7:0]  din = 0;  reg din_valid_i = 0;  wire din_ready_o;
  wire [7:0]  dout;     wire dout_valid_o;     reg dout_ready_i = 1;
  wire        done_irq_o;

  reg  [7:0]  in_mem  [0:`N_IN-1];
  reg  [7:0]  out_mem [0:`N_OUT-1];
  integer     i, got;

  butterfold_top dut (
    .clk_i(clk), .rst_ni(rst_ni),
    .din(din), .din_valid_i(din_valid_i), .din_ready_o(din_ready_o),
    .dout(dout), .dout_valid_o(dout_valid_o), .dout_ready_i(dout_ready_i),
    .done_irq_o(done_irq_o), .scan_en_i(1'b0), .scan_in_i(1'b0), .scan_out_o()
  );

  always #5 clk = ~clk;

  always @(posedge clk)
    if (dout_valid_o && dout_ready_i && got < `N_OUT) begin out_mem[got] <= dout; got <= got + 1; end

  task send_byte(input [7:0] b);
    begin
      @(posedge clk); din <= b; din_valid_i <= 1'b1;
      @(posedge clk); while (!din_ready_o) @(posedge clk);
      din_valid_i <= 1'b0;
    end
  endtask

  initial begin
    got = 0;
    $readmemh("tests/vectors/top_gold.hex", in_mem);    // TX output = RX input
    rst_ni = 0; repeat (6) @(posedge clk); rst_ni = 1;
    send_byte(`CMD_RX);
    for (i = 0; i < `N_IN; i = i + 1) send_byte(in_mem[i]);
    for (i = 0; i < 400000 && got < `N_OUT; i = i + 1) @(posedge clk);
    for (i = got; i < `N_OUT; i = i + 1) out_mem[i] = 8'h00;
    $writememh("generated/rtl/rx_out.hex", out_mem);
    $display("tb_top_rx: captured %0d/%0d bytes", got, `N_OUT);
    $finish;
  end
  initial begin #4000000; $display("tb_top_rx: TIMEOUT (%0d/%0d)", got, `N_OUT);
    for (i = got; i < `N_OUT; i = i + 1) out_mem[i] = 8'h00;
    $writememh("generated/rtl/rx_out.hex", out_mem); $finish; end
endmodule
