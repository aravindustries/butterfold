// tb_scheduler_addr_control.v — FUNCTIONAL testbench (IFFT-128 uop sequence).
// Issues an IFFT-128 command and checks the scheduler emits the exact 448-butterfly
// micro-op sequence (src_addr_0=top, src_addr_1=bot, tw_addr=tw_idx) from the
// golden schedule. Run from repo root.
`timescale 1ns/1ps
`define NUOP 448

module tb_scheduler_addr_control;
  reg         clk = 0, rst_n = 0, cmd_valid = 0;  wire cmd_ready;  reg [2:0] cmd_op = 0;  reg long_cp = 0;
  wire        uop_valid;  reg uop_ready = 1;  wire [1:0] uop_radix;  wire uop_inverse;
  wire [2:0]  uop_scale_shift;  wire uop_last;
  wire [6:0]  src_addr_0, src_addr_1, src_addr_2, dst_addr_0, dst_addr_1, dst_addr_2;
  wire        tw_req;  wire [6:0] tw_addr;  wire tw_conjugate;  reg tw_valid = 1;
  wire        map_start, map_direction;  wire [6:0] first_subcarrier;  reg map_done = 1;
  wire        cp_start, cp_insert;  wire [3:0] cp_len;  reg cp_done = 1;
  wire        input_bank_select, output_bank_select, busy, done, error;  wire [15:0] cycle_count;

  scheduler_addr_control dut (
    .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
    .cmd_op(cmd_op), .long_cp(long_cp),
    .uop_valid(uop_valid), .uop_ready(uop_ready), .uop_radix(uop_radix),
    .uop_inverse(uop_inverse), .uop_scale_shift(uop_scale_shift), .uop_last(uop_last),
    .src_addr_0(src_addr_0), .src_addr_1(src_addr_1), .src_addr_2(src_addr_2),
    .dst_addr_0(dst_addr_0), .dst_addr_1(dst_addr_1), .dst_addr_2(dst_addr_2),
    .tw_req(tw_req), .tw_addr(tw_addr), .tw_conjugate(tw_conjugate), .tw_valid(tw_valid),
    .map_start(map_start), .map_direction(map_direction), .first_subcarrier(first_subcarrier),
    .map_done(map_done), .cp_start(cp_start), .cp_insert(cp_insert), .cp_len(cp_len), .cp_done(cp_done),
    .input_bank_select(input_bank_select), .output_bank_select(output_bank_select),
    .busy(busy), .done(done), .error(error), .cycle_count(cycle_count)
  );

  always #5 clk = ~clk;

  reg [15:0] etop [0:`NUOP-1];
  reg [15:0] ebot [0:`NUOP-1];
  reg [15:0] etw  [0:`NUOP-1];
  integer    ng = 0, i, errors = 0;

  always @(negedge clk) begin
    if (uop_valid && uop_ready && ng < `NUOP) begin
      if (src_addr_0 !== etop[ng][6:0] || src_addr_1 !== ebot[ng][6:0] || tw_addr !== etw[ng][6:0]) begin
        errors = errors + 1;
        if (errors <= 8)
          $display("FAIL uop %0d: got top=%0d bot=%0d tw=%0d  want %0d %0d %0d",
                   ng, src_addr_0, src_addr_1, tw_addr, etop[ng], ebot[ng], etw[ng]);
      end
      ng = ng + 1;
    end
  end

  initial begin
    $readmemh("tests/vectors/sched_top.hex",   etop);
    $readmemh("tests/vectors/sched_bot.hex",   ebot);
    $readmemh("tests/vectors/sched_twidx.hex", etw);
    uop_ready = 1; tw_valid = 1; map_done = 1; cp_done = 1;
    rst_n = 0; repeat (4) @(negedge clk); rst_n = 1;
    cmd_op = 3'b010;                          // IFFT-128
    @(negedge clk); cmd_valid = 1;
    @(posedge clk); while (cmd_ready !== 1'b1) @(posedge clk);
    @(negedge clk); cmd_valid = 0;

    i = 0; while (ng < `NUOP && i < 20000) begin @(negedge clk); i = i + 1; end
    if (ng < `NUOP) begin errors = errors + 1; $display("FAIL: only %0d/448 uops emitted", ng); end

    if (errors == 0) $display("PASS: tb_scheduler_addr_control (448 IFFT uops)");
    else             $display("FAIL: tb_scheduler_addr_control (%0d errors)", errors);
    $finish;
  end

  initial begin
    #20000000; $display("FAIL: tb_scheduler_addr_control TIMEOUT (%0d/448)", ng); $finish;
  end
endmodule
