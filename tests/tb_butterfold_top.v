// Committed deterministic testbench for butterfold_top.
// Stage 4 of the verify agent prefers this over an LLM-generated one.
//
// Checks the block-streaming contract and linearity:
//   - reset behaviour
//   - TX mode: stream 24 zero input bytes (12 zero symbols)
//   - busy asserts, done pulses, dout_valid fires
//   - all-zero input must produce all-zero output (DFT/IFFT linearity)
// Prints "PASS" on success (the simulator greps stdout for PASS).

`timescale 1ns/1ps
module tb_butterfold_top;
  reg        clk = 0;
  reg        rst_n = 0;
  reg        mode = 0;
  reg  [7:0] din = 0;
  reg        din_valid = 0;
  wire [7:0] dout;
  wire       dout_valid, busy, done;

  integer i;
  integer out_count   = 0;
  integer nonzero_out = 0;
  integer saw_busy    = 0;
  reg     timeout_hit = 0;

  butterfold_top dut (
    .clk(clk), .rst_n(rst_n), .mode(mode),
    .din(din), .din_valid(din_valid),
    .dout(dout), .dout_valid(dout_valid),
    .busy(busy), .done(done)
  );

  always #5 clk = ~clk;

  // Capture outputs and observe handshake signals
  always @(posedge clk) begin
    if (busy) saw_busy = 1;
    if (dout_valid) begin
      out_count = out_count + 1;
      if (dout !== 8'd0) nonzero_out = nonzero_out + 1;
    end
  end

  // Watchdog
  initial begin
    #200000;
    timeout_hit = 1;
    $display("FAIL: watchdog timeout");
    $finish;
  end

  initial begin
    $dumpfile("generated/logs/sim.vcd");
    $dumpvars(0, tb_butterfold_top);

    // Reset
    rst_n = 0; mode = 0; din = 0; din_valid = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // TX mode: stream 24 zero bytes (12 zero complex symbols)
    din_valid = 1;
    for (i = 0; i < 24; i = i + 1) begin
      din = 8'd0;
      @(posedge clk);
    end
    din_valid = 0;

    // Wait for completion
    wait (done || timeout_hit);
    repeat (5) @(posedge clk);

    // Verdict
    if (timeout_hit) begin
      $display("FAIL: timed out before done");
    end else if (!saw_busy) begin
      $display("FAIL: busy never asserted");
    end else if (out_count < 274) begin
      $display("FAIL: only %0d output bytes (expected >= 274)", out_count);
    end else if (nonzero_out != 0) begin
      $display("FAIL: zero input produced %0d non-zero output bytes", nonzero_out);
    end else begin
      $display("PASS: reset, busy, done, dout_valid OK; zero-in -> zero-out; %0d bytes", out_count);
    end
    $finish;
  end
endmodule
