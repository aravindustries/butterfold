`timescale 1ns/1ps
module butterfold_padframe_tb;
  reg pad_rst_n = 0;
  reg pad_clk = 0;
  reg [7:0] pad_din = 0;
  reg pad_din_valid_i = 0;
  wire pad_din_ready_o;
  wire [7:0] pad_dout;
  wire pad_dout_valid_o;
  integer errors = 0;
  reg [7:0] b;

  butterfold_padframe_top dut(
    .pad_rst_n, .pad_clk, .pad_din, .pad_din_valid_i,
    .pad_din_ready_o, .pad_dout, .pad_dout_valid_o);

  always #8.138 pad_clk = ~pad_clk;

  task send_byte(input [7:0] value);
    integer n;
    begin
      @(negedge pad_clk); pad_din = value; pad_din_valid_i = 1;
      n = 0;
      while (!(pad_din_valid_i && pad_din_ready_o)) begin
        @(posedge pad_clk); n=n+1; if(n>10000) $fatal(1, "send timeout");
      end
      @(negedge pad_clk); pad_din_valid_i = 0; pad_din = 0;
    end
  endtask

  task recv_byte(output [7:0] value);
    integer n;
    begin
      n=0;
      begin : wait_output
      while (1) begin
        @(posedge pad_clk); n=n+1; if(n>10000) $fatal(1, "recv timeout");
        if (pad_dout_valid_o) disable wait_output;
      end
      end
      #2 value = pad_dout;
    end
  endtask

  task expect_byte(input [7:0] value);
    begin recv_byte(b); if(b!==value) begin $display("expected %02x got %02x",value,b); errors=errors+1; end end
  endtask

  initial begin
    repeat(4) @(posedge pad_clk); pad_rst_n=1; repeat(4) @(posedge pad_clk);
    send_byte(8'h4a); send_byte(8'ha5); expect_byte(8'ha5);
    send_byte(8'h4b); expect_byte(8'h42); expect_byte(8'h46); expect_byte(8'h4c); expect_byte(8'h44);
    send_byte(8'h4d); send_byte(8'h3c); send_byte(8'ha5); send_byte(8'h5a); expect_byte(8'hac);
    send_byte(8'h4c); send_byte(8'h3c); expect_byte(8'ha5); expect_byte(8'h5a);
    // FFT2 of two zero complex samples: two 5-byte diagnostic records.
    send_byte(8'h40); repeat(4) send_byte(8'h00);
    expect_byte(8'h00); repeat(4) expect_byte(8'h00);
    expect_byte(8'h01); repeat(4) expect_byte(8'h00);
    // Verify asynchronous assertion propagates through the selected pad.
    #3 pad_rst_n=0; repeat(3) @(posedge pad_clk); pad_rst_n=1;
    repeat(4) @(posedge pad_clk);
    send_byte(8'h4a); send_byte(8'h3c); expect_byte(8'h3c);
    if(errors==0) $display("PASS padframe smoke: reset ECHO MAGIC SRAM FFT2 bitmap");
    else $fatal(1,"padframe smoke errors=%0d",errors);
    $finish;
  end
endmodule
