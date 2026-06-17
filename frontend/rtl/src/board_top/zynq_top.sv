`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Institution :
// Engineer(s) : Srirangarajan TM (Eloquencere)
//
// Project Name      : Chipathon (Track-D)
// Target Devices    : Zybo
// Tool Version      : Vivado 2025.1
// Module Hierarchy  : ila_0 (IP)
//                       zynq_fclk_scaler
// Version (DD/MM/YY):
//          01/02/25 - File Created (<Insert Commit Hash>)
//
//////////////////////////////////////////////////////////////////////////////////

module zynq_top (
    input          zynq_fclk,
    input          rst,

    // // Buttons
    // input  [3 : 1] btn,

    // // Switches
    // input  [3 : 0] sw,

    // LEDs (GREEN)
    output [3 : 0] led

    // // JA Pmod Headers (XADC)
    // input  [3 : 0] ja_p,
    // input  [3 : 0] ja_n,
    // // JB Pmod Headers (Hi-Speed)
    // input  [3 : 0] jb_p,
    // input  [3 : 0] jb_n,
    // // JC Pmod Headers (Hi-Speed)
    // input  [3 : 0] jc_p,
    // input  [3 : 0] jc_n,
    // // JD Pmod Headers (Hi-Speed)
    // input  [3 : 0] jd_p,
    // input  [3 : 0] jd_n,
    // // JE Pmod Headers (Std.)
    // input  [7 : 0] je,

    // // VGA Connector
    // output [4 : 0] vga_r,
    // output [4 : 0] vga_g,
    // output [4 : 0] vga_b,
    // output         vga_hs,
    // output         vga_vs,

    // // HDMI
    // input          hdmi_clk_n,
    // input          hdmi_clk_p,
    // output [2 : 0] hdmi_d_n,
    // output [2 : 0] hdmi_d_p,
    // output         hdmi_cec,
    // output         hdmi_hpd,
    // output         hdmi_out_en,
    // output         hdmi_scl,
    // output         hdmi_sda,

    // // I2S Audio Codec
    // inout          ac_bclk,
    // inout          ac_mclk,
    // inout          ac_muten,
    // inout          ac_pbdat,
    // inout          ac_pblrc,
    // inout          ac_recdat,
    // inout          ac_reclrc,
    // // Audio Codec (external EEPROM I2C bus)
    // inout          ac_scl,
    // inout          ac_sda,

    // // Additional Ethernet Signals
    // input          eth_int_b,
    // input          eth_rst_b,

    // // USB-OTG overcurrent detect pin
    // input          otg_oc
);
    parameter byte unsigned SCAN_PROFILE = 1; // 0 -> No Probe, 1 -> System level probe, 2.. -> block probe

    // Button debounce
    // Reset Generator

    // clk_wiz_0 zynq_fclk_scaler (
    //     // Control & Status
    //     .reset  (rst),
    //     .locked  (led[0]),
    //
    //     // Clock In Ports
    //     .clk_in1  (zynq_fclk)
    //
    //     // Clock Out Ports
    //     // .clk_out1  ()
    // );

    generate
        case (SCAN_PROFILE)
            1 : begin: system_probe
                `ifdef XILINX_SIMULATOR
                    // top_functional_checker zynq_top_func (
                    // );
                `endif

                // ila_0 zynq_top_probe (
                // );
            end: system_probe
            2 : begin
            end
        endcase
    endgenerate

`ifdef FORMAL
`endif
endmodule: zynq_top


`ifdef XILINX_SIMULATOR
    module zynq_board_emulator;
        bit zynq_fclk;
        bit rst = 1'b1;

        zynq_top dut (
            .zynq_fclk,
            .rst
        );

        initial forever begin: sim_clk_generator
            #8ns zynq_fclk = ~zynq_fclk; // 125MHz Clk
        end

        initial begin: reset_sequence
            #10_000ns;
            rst = 1'b0;
        end
    endmodule: zynq_board_emulator
`endif

