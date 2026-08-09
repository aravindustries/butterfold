`timescale 1ns/1ps
`default_nettype none

// Cycle-accurate wrapper for the GF180MCU 512x8 synchronous single-port SRAM.
module gf180_sram_512x8_wrapper (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       req_i,
    input  logic       write_i,
    input  logic [8:0] addr_i,
    input  logic [7:0] wdata_i,
    input  logic [7:0] wmask_i,
    output logic [7:0] rdata_o,
    output logic       rvalid_o
);

`ifdef GF180_USE_FOUNDRY_SRAM
    wire [7:0] macro_q;
    supply1 sim_vdd;
    supply0 sim_vss;
    logic       macro_req;
    logic       macro_write;
    logic [8:0] macro_addr;
    logic [7:0] macro_wdata;
    logic [7:0] macro_wmask;

    // Follow the request during the low phase, then hold all foundry-macro
    // pins stable across the active rising edge and delayed functional event.
    always_latch begin
        if (!rst_n) begin
            macro_req   <= 1'b0;
            macro_write <= 1'b0;
            macro_addr  <= 9'd0;
            macro_wdata <= 8'd0;
            macro_wmask <= 8'd0;
        end else if (!clk) begin
            macro_req   <= req_i;
            macro_write <= write_i;
            macro_addr  <= addr_i;
            macro_wdata <= wdata_i;
            macro_wmask <= wmask_i;
        end
    end

    wire       macro_cen  = (!rst_n || !macro_req) ? 1'b1 : 1'b0;
    wire       macro_gwen = macro_write ? 1'b0 : 1'b1;
    wire [7:0] macro_wen  = macro_write ? ~macro_wmask : 8'hff;

    gf180mcu_fd_ip_sram__sram512x8m8wm1 u_sram (
        .CLK  (clk),
        .CEN  (macro_cen),
        .GWEN (macro_gwen),
        .WEN  (macro_wen),
        .A    (macro_addr),
        .D    (macro_wdata),
        .Q    (macro_q),
        .VDD  (sim_vdd),
        .VSS  (sim_vss)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rvalid_o <= 1'b0;
        else
            rvalid_o <= req_i && !write_i;
    end
    always @* rdata_o = macro_q;
`else
    logic [7:0] mem [0:511];
    integer bit_index;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_o <= 1'b0;
            rdata_o  <= 8'd0;
        end else begin
            rvalid_o <= 1'b0;
            if (req_i) begin
                if (write_i) begin
                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                        if (wmask_i[bit_index])
                            mem[addr_i][bit_index] <= wdata_i[bit_index];
                end else begin
                    rdata_o  <= mem[addr_i];
                    rvalid_o <= 1'b1;
                end
            end
        end
    end
`endif
endmodule

`default_nettype wire
