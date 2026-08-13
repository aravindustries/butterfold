// tb_unified_mixed_radix_core.v — FUNCTIONAL testbench (IFFT-128 engine).
// Loads the 128-sample bit-reversed grid, drives the 448 radix-2 butterfly
// micro-ops (addresses + twiddles from the golden schedule), reads the 128
// results, and checks them bit-exactly against golden/core_exec (core_out.hex).
// Run from repo root.
`timescale 1ns/1ps
`define N    128
`define NUOP 448

module tb_unified_mixed_radix_core;
  reg         clk = 0, rst_n = 0;
  reg         uop_valid = 0;  wire uop_ready;
  reg  [1:0]  uop_radix = 2;  reg uop_inverse = 1;  reg [2:0] uop_scale_shift = 1;  reg uop_last = 0;
  reg  [6:0]  src_addr_0 = 0, src_addr_1 = 0, src_addr_2 = 0;
  reg  [6:0]  dst_addr_0 = 0, dst_addr_1 = 0, dst_addr_2 = 0;
  reg  [7:0]  twiddle_re = 0, twiddle_im = 0;  reg twiddle_valid = 0;
  reg  [6:0]  load_addr = 0;  reg [15:0] load_data = 0;  reg load_valid = 0;  wire load_ready;
  reg  [6:0]  read_addr = 0;  reg read_req = 0;  wire [15:0] read_data;  wire read_valid;
  wire        uop_done, overflow, saturation_occurred;

  unified_mixed_radix_core dut (
    .clk(clk), .rst_n(rst_n),
    .uop_valid(uop_valid), .uop_ready(uop_ready), .uop_radix(uop_radix),
    .uop_inverse(uop_inverse), .uop_scale_shift(uop_scale_shift), .uop_last(uop_last),
    .src_addr_0(src_addr_0), .src_addr_1(src_addr_1), .src_addr_2(src_addr_2),
    .dst_addr_0(dst_addr_0), .dst_addr_1(dst_addr_1), .dst_addr_2(dst_addr_2),
    .twiddle_re(twiddle_re), .twiddle_im(twiddle_im), .twiddle_valid(twiddle_valid),
    .load_addr(load_addr), .load_data(load_data), .load_valid(load_valid), .load_ready(load_ready),
    .read_addr(read_addr), .read_req(read_req), .read_data(read_data), .read_valid(read_valid),
    .uop_done(uop_done), .overflow(overflow), .saturation_occurred(saturation_occurred)
  );

  always #5 clk = ~clk;

  reg [15:0] gload [0:`N-1];
  reg [15:0] gout  [0:`N-1];
  reg [15:0] utop  [0:`NUOP-1];
  reg [15:0] ubot  [0:`NUOP-1];
  reg [7:0]  uwre  [0:`NUOP-1];
  reg [7:0]  uwim  [0:`NUOP-1];
  reg [15:0] cap   [0:`N-1];              // captured RTL read-back (for proof dump)
  integer    i, errors = 0;

  initial if ($test$plusargs("DUMP")) begin
    $dumpfile("generated/core_rf.vcd"); $dumpvars(0, tb_unified_mixed_radix_core);
  end

  initial begin
    $readmemh("tests/vectors/core_load.hex",    gload);
    $readmemh("tests/vectors/core_out.hex",     gout);
    $readmemh("tests/vectors/core_uop_top.hex", utop);
    $readmemh("tests/vectors/core_uop_bot.hex", ubot);
    $readmemh("tests/vectors/core_uop_wre.hex", uwre);
    $readmemh("tests/vectors/core_uop_wim.hex", uwim);

    rst_n = 0; repeat (4) @(negedge clk); rst_n = 1;

    // 1) load 128 samples
    for (i = 0; i < `N; i = i + 1) begin
      @(negedge clk); load_addr = i; load_data = gload[i]; load_valid = 1;
      @(posedge clk); while (load_ready !== 1'b1) @(posedge clk);
    end
    @(negedge clk); load_valid = 0;

    // 2) run 448 butterfly micro-ops (in-place: dst == src), one per cycle.
    // Hold uop_valid high and present a new op each cycle; uop_ready is high, so
    // the core consumes exactly one op per posedge.
    for (i = 0; i < `NUOP; i = i + 1) begin
      @(negedge clk);
      src_addr_0 = utop[i][6:0]; dst_addr_0 = utop[i][6:0];
      src_addr_1 = ubot[i][6:0]; dst_addr_1 = ubot[i][6:0];
      twiddle_re = uwre[i]; twiddle_im = uwim[i]; twiddle_valid = 1;
      uop_radix = 2; uop_inverse = 1; uop_scale_shift = 1;
      uop_last = (i == `NUOP-1); uop_valid = 1;
    end
    @(negedge clk); uop_valid = 0; twiddle_valid = 0;
    repeat (4) @(negedge clk);            // let the last write settle

    // 3) read back 128 results and compare
    for (i = 0; i < `N; i = i + 1) begin
      @(negedge clk); read_addr = i; read_req = 1;
      @(negedge clk); while (read_valid !== 1'b1) @(negedge clk);
      cap[i] = read_data;
      if (read_data !== gout[i]) begin
        errors = errors + 1;
        if (errors <= 8) $display("FAIL out[%0d]: got %04h want %04h", i, read_data, gout[i]);
      end
      read_req = 0;
    end

    $writememh("tests/vectors/core_rf_out.hex", cap);   // RTL output, for golden diff
    $display("PROOF out[0..7] rtl vs golden:");
    for (i = 0; i < 8; i = i + 1)
      $display("  out[%0d]  rtl=%04h  golden=%04h  %s", i, cap[i], gout[i],
               (cap[i] === gout[i]) ? "match" : "MISMATCH");
    if (errors == 0) $display("PASS: tb_unified_mixed_radix_core (IFFT-128, 448 uops, 128/128 match)");
    else             $display("FAIL: tb_unified_mixed_radix_core (%0d errors)", errors);
    $finish;
  end

  initial begin
    #20000000; $display("FAIL: tb_unified_mixed_radix_core TIMEOUT"); $finish;
  end
endmodule
