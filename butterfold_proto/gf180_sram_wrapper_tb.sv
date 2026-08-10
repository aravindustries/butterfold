`timescale 1ns/1ps
`default_nettype none
module gf180_sram_wrapper_tb;
    logic clk=0, rst_n=0;
    logic req8, wr8; logic [7:0] a8; logic [7:0] wd8, rd8; logic rv8;
    logic req32, wr32; logic [6:0] a32; logic [31:0] wd32, rd32; logic rv32, ready32;
    integer errors=0;
    always #5 clk=~clk;

    gf180_sram_256x8_wrapper u8(
        .clk(clk),.rst_n(rst_n),.req_i(req8),.write_i(wr8),.addr_i(a8),
        .wdata_i(wd8),.wmask_i(8'hff),.rdata_o(rd8),.rvalid_o(rv8));
    gf180_sram_256x16_complex u32(
        .clk(clk),.rst_n(rst_n),.req_i(req32),.write_i(wr32),.addr_i(a32),
        .wdata_i(wd32),.ready_o(ready32),.rdata_o(rd32),.rvalid_o(rv32),
        .half_mode_i(1'b0),.half_req_i(1'b0),.half_write_i(1'b0),
        .half_addr_i(8'd0),.half_wdata_i(16'd0),.half_ready_o(),
        .half_rdata_o(),.half_rvalid_o());

    initial begin
        req8=0;wr8=0;a8=0;wd8=0;
        req32=0;wr32=0;a32=0;wd32=0;
        repeat(3) @(posedge clk); rst_n=1;

        @(negedge clk); req8=1;wr8=1;a8=8'd137;wd8=8'ha5;
        @(negedge clk); req8=0;
        @(negedge clk); req8=1;wr8=0;a8=8'd137;
        @(negedge clk); req8=0;
        wait(rv8); if(rd8!==8'ha5) begin $display("256x8 mismatch"); errors=errors+1; end

        wait(ready32); @(negedge clk); req32=1;wr32=1;a32=7'd91;wd32=32'h8123_7fab;
        @(negedge clk); req32=0;
        wait(ready32); @(negedge clk); req32=1;wr32=0;a32=7'd91;
        @(negedge clk); req32=0;
        wait(rv32); if(rd32!==32'h8123_7fab) begin $display("256x16-complex mismatch %h",rd32); errors=errors+1; end

        if(errors==0) $display("GF180 SRAM WRAPPER RESULT: PASS");
        else $display("GF180 SRAM WRAPPER RESULT: FAIL (%0d)",errors);
        $finish;
    end
endmodule
`default_nettype wire
