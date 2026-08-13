// tb_fdiq_io_adapter.v — FUNCTIONAL testbench (TX packing path).
// Drives 24 external I/Q bytes and checks the adapter emits 12 packed 16-bit
// complex samples {I[7:0],Q[7:0]} on the internal fd_in stream, with fd_in_last
// on the 12th. Uses tests/vectors/top_in.hex as stimulus. Run from repo root.
`timescale 1ns/1ps

module tb_fdiq_io_adapter;
  reg         clk = 0, rst_n = 0, start = 0, direction = 0;
  reg  [7:0]  fdiq_in_data = 0;  reg  fdiq_in_valid = 0;  wire fdiq_in_ready;
  wire [7:0]  fdiq_out_data;      wire fdiq_out_valid;     reg  fdiq_out_ready = 1;
  wire [15:0] fd_in_data;         wire fd_in_valid;        reg  fd_in_ready = 1;  wire fd_in_last;
  reg  [15:0] fd_out_data = 0;    reg  fd_out_valid = 0;   wire fd_out_ready;     reg  fd_out_last = 0;
  wire        busy, done, iq_alignment_error;

  fdiq_io_adapter dut (
    .clk(clk), .rst_n(rst_n),
    .fdiq_in_data(fdiq_in_data), .fdiq_in_valid(fdiq_in_valid), .fdiq_in_ready(fdiq_in_ready),
    .fdiq_out_data(fdiq_out_data), .fdiq_out_valid(fdiq_out_valid), .fdiq_out_ready(fdiq_out_ready),
    .fd_in_data(fd_in_data), .fd_in_valid(fd_in_valid), .fd_in_ready(fd_in_ready), .fd_in_last(fd_in_last),
    .fd_out_data(fd_out_data), .fd_out_valid(fd_out_valid), .fd_out_ready(fd_out_ready), .fd_out_last(fd_out_last),
    .start(start), .direction(direction), .busy(busy), .done(done),
    .iq_alignment_error(iq_alignment_error)
  );

  always #5 clk = ~clk;

  reg [7:0]  inb [0:23];
  reg [15:0] got [0:11];
  integer    ng = 0, i, errors = 0;

  // Sink the internal fd_in stream (ready held high); capture on the transfer.
  always @(negedge clk) begin
    if (fd_in_valid && fd_in_ready && ng < 12) begin
      got[ng] = fd_in_data;
      ng = ng + 1;
    end
  end

  integer bi;
  initial begin
    $readmemh("tests/vectors/top_in.hex", inb);
    fd_in_ready = 1;
    rst_n = 0; repeat (4) @(negedge clk); rst_n = 1;
    direction = 1;                        // TX: pack external bytes -> complex
    @(negedge clk); start = 1; @(negedge clk); start = 0;

    // Feed 24 bytes: drive on negedge, transfer completes at the posedge where
    // ready is high (proper valid/ready handshake, robust to the DUT going idle).
    for (bi = 0; bi < 24; bi = bi + 1) begin
      @(negedge clk);
      fdiq_in_data = inb[bi]; fdiq_in_valid = 1;
      @(posedge clk);
      while (fdiq_in_ready !== 1'b1) @(posedge clk);
    end
    @(negedge clk); fdiq_in_valid = 0;

    i = 0; while (ng < 12 && i < 4000) begin @(negedge clk); i = i + 1; end

    for (i = 0; i < 12; i = i + 1)
      if (got[i] !== {inb[2*i], inb[2*i+1]}) begin
        errors = errors + 1;
        if (errors <= 6)
          $display("FAIL sample %0d: got %04h want %04h", i, got[i], {inb[2*i], inb[2*i+1]});
      end
    if (ng < 12) begin errors = errors + 1; $display("FAIL: only %0d/12 samples emitted", ng); end

    if (errors == 0) $display("PASS: tb_fdiq_io_adapter (12 packed samples)");
    else             $display("FAIL: tb_fdiq_io_adapter (%0d errors)", errors);
    $finish;
  end

  initial begin
    #500000; $display("FAIL: tb_fdiq_io_adapter TIMEOUT (%0d/12 samples)", ng); $finish;
  end
endmodule
