`timescale 1ns/1ps
`default_nettype none

// Cycle-accurate wrapper for the GF180MCU 256x8 synchronous single-port SRAM.
module gf180_sram_256x8_wrapper (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       req_i,
    input  logic       write_i,
    input  logic [7:0] addr_i,
    input  logic [7:0] wdata_i,
    input  logic [7:0] wmask_i,
    output logic [7:0] rdata_o,
    output logic       rvalid_o
);
`ifdef GF180_USE_FOUNDRY_SRAM
    wire [7:0] macro_q;
    supply1 sim_vdd;
    supply0 sim_vss;
`ifdef SYNTHESIS
    // Dedicated strong drivers isolate macro-pin capacitance and prevent the
    // identical controls of the two byte macros from merging after flattening.
    wire macro_cen, macro_gwen;
    wire [7:0] macro_wen, macro_addr, macro_wdata;
    (* keep *) gf180mcu_fd_sc_mcu9t5v0__nand2_4 u_cen_driver
        (.A1(rst_n), .A2(req_i), .ZN(macro_cen));
    (* keep *) gf180mcu_fd_sc_mcu9t5v0__clkinv_4 u_gwen_driver
        (.I(write_i), .ZN(macro_gwen));
    // The logical 16-bit port always performs full-byte writes.  Sharing the
    // local, already-strengthened active-low write signal across this macro's
    // GWEN/WEN pins avoids eighteen loads on the controller write decode while
    // retaining the foundry macro's per-bit interface semantics.
    assign macro_wen = {8{macro_gwen}};
    genvar synth_pin;
    generate
        for (synth_pin = 0; synth_pin < 8; synth_pin = synth_pin + 1) begin : g_pin_drive
            (* keep *) gf180mcu_fd_sc_mcu9t5v0__buf_4 u_addr_driver
                (.I(addr_i[synth_pin]), .Z(macro_addr[synth_pin]));
            (* keep *) gf180mcu_fd_sc_mcu9t5v0__buf_4 u_data_driver
                (.I(wdata_i[synth_pin]), .Z(macro_wdata[synth_pin]));
        end
    endgenerate
`else
    // The official functional model samples through a delayed internal clock.
    // This simulation-only low-phase hold prevents a zero-time request race;
    // it is deliberately excluded from the physical netlist.
    logic sim_req, sim_write;
    logic [7:0] sim_addr, sim_wdata, sim_wmask;
    always_latch begin
        if (!rst_n) begin
            sim_req <= 1'b0; sim_write <= 1'b0; sim_addr <= 8'd0;
            sim_wdata <= 8'd0; sim_wmask <= 8'd0;
        end else if (!clk) begin
            sim_req <= req_i; sim_write <= write_i; sim_addr <= addr_i;
            sim_wdata <= wdata_i; sim_wmask <= wmask_i;
        end
    end
    wire [7:0] macro_addr = sim_addr;
    wire [7:0] macro_wdata = sim_wdata;
    wire macro_cen = (!rst_n || !sim_req);
    wire macro_gwen = !sim_write;
    wire [7:0] macro_wen = sim_write ? ~sim_wmask : 8'hff;
`endif
    gf180mcu_fd_ip_sram__sram256x8m8wm1 u_sram (
        .CLK(clk), .CEN(macro_cen), .GWEN(macro_gwen), .WEN(macro_wen),
        .A(macro_addr), .D(macro_wdata), .Q(macro_q),
        .VDD(sim_vdd), .VSS(sim_vss)
    );
    always @(posedge clk or negedge rst_n)
        if (!rst_n) rvalid_o <= 1'b0;
        else rvalid_o <= req_i && !write_i;
    always @* rdata_o = macro_q;
`else
    logic [7:0] mem [0:255];
    integer bit_index;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rvalid_o <= 1'b0; rdata_o <= 8'd0; end
        else begin
            rvalid_o <= 1'b0;
            if (req_i) begin
                if (write_i) begin
                    for (bit_index=0; bit_index<8; bit_index=bit_index+1)
                        if (wmask_i[bit_index]) mem[addr_i][bit_index] <= wdata_i[bit_index];
                end else begin rdata_o <= mem[addr_i]; rvalid_o <= 1'b1; end
            end
        end
    end
`endif
endmodule
`default_nettype wire
