`timescale 1ns/1ps
`default_nettype none

// Cycle-accurate wrapper for the GF180MCU 128x8 synchronous single-port SRAM.
// Functional contract used by ButterFold:
//   * one request per cycle
//   * read OR write per request
//   * read data/rvalid appear one cycle after a read request
//   * writes commit on the request clock edge
// Define GF180_USE_FOUNDRY_SRAM when compiling with the official PDK model.
module gf180_sram_128x8_wrapper (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       req_i,
    input  logic       write_i,
    input  logic [6:0] addr_i,
    input  logic [7:0] wdata_i,
    input  logic [7:0] wmask_i,
    output logic [7:0] rdata_o,
    output logic       rvalid_o
);

`ifdef GF180_USE_FOUNDRY_SRAM
    wire [7:0] macro_q;
    supply1 sim_vdd;
    supply0 sim_vss;

    // The GF macro requires CEN high before the first running cycle. rst_n
    // therefore forces standby regardless of req_i.
    wire       macro_cen  = (!rst_n || !req_i) ? 1'b1 : 1'b0;
    wire       macro_gwen = write_i ? 1'b0 : 1'b1;
    wire [7:0] macro_wen  = write_i ? ~wmask_i : 8'hff;

    gf180mcu_fd_ip_sram__sram128x8m8wm1 u_sram (
        .CLK  (clk),
        .CEN  (macro_cen),
        .GWEN (macro_gwen),
        .WEN  (macro_wen),
        .A    (addr_i),
        .D    (wdata_i),
        .Q    (macro_q),
        .VDD  (sim_vdd),
        .VSS  (sim_vss)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_o <= 1'b0;
        end else begin
            rvalid_o <= req_i && !write_i;
        end
    end

    always @* rdata_o = macro_q;
`else
    logic [7:0] mem [0:127];
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
