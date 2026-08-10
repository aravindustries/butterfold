`timescale 1ns/1ps
`default_nettype none

// Pad-level production wrapper.  butterfold_top remains the frozen reusable
// core.  GF180 I/O controls are strapped for fixed unidirectional operation.
module butterfold_padframe_top (
    input  wire       pad_rst_n,
    input  wire       pad_clk,
    input  wire [7:0] pad_din,
    input  wire       pad_din_valid_i,
    inout  wire       pad_din_ready_o,
    inout  wire [7:0] pad_dout,
    inout  wire       pad_dout_valid_o
);
    supply1 VDD;
    supply0 VSS;
    wire rst_iso;
    wire rst_root_in;
    wire core_rst_n;
    wire clk_iso;
    wire clk_root_in;
    wire core_clk;
    wire [7:0] core_din_pad;
    wire [7:0] core_din_iso;
    wire [7:0] core_din;
    wire core_din_valid_pad;
    wire core_din_valid_iso;
    wire core_din_valid;
    wire core_din_ready;
    wire [7:0] core_dout;
    wire core_dout_valid;

    gf180mcu_fd_io__in_c u_pad_clk(
        .PU(1'b0), .PD(1'b0), .PAD(pad_clk), .Y(clk_iso),
        .DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_rst_n(
        .PU(1'b0), .PD(1'b0), .PAD(pad_rst_n), .Y(rst_iso),
        .DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din_valid(
        .PU(1'b0), .PD(1'b0), .PAD(pad_din_valid_i), .Y(core_din_valid_pad),
        .DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));

    gf180mcu_fd_io__in_c u_pad_din0(.PU(1'b0),.PD(1'b0),.PAD(pad_din[0]),.Y(core_din_pad[0]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din1(.PU(1'b0),.PD(1'b0),.PAD(pad_din[1]),.Y(core_din_pad[1]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din2(.PU(1'b0),.PD(1'b0),.PAD(pad_din[2]),.Y(core_din_pad[2]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din3(.PU(1'b0),.PD(1'b0),.PAD(pad_din[3]),.Y(core_din_pad[3]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din4(.PU(1'b0),.PD(1'b0),.PAD(pad_din[4]),.Y(core_din_pad[4]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din5(.PU(1'b0),.PD(1'b0),.PAD(pad_din[5]),.Y(core_din_pad[5]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din6(.PU(1'b0),.PD(1'b0),.PAD(pad_din[6]),.Y(core_din_pad[6]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__in_c u_pad_din7(.PU(1'b0),.PD(1'b0),.PAD(pad_din[7]),.Y(core_din_pad[7]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));

    // Every input pad sees only a minimum-input-capacitance isolation cell.
    // The second stage drives the core-side network; this prevents in_c/Y
    // from directly seeing the multi-pF synthesized input cone.
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din0_iso(.I(core_din_pad[0]),.Z(core_din_iso[0]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din1_iso(.I(core_din_pad[1]),.Z(core_din_iso[1]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din2_iso(.I(core_din_pad[2]),.Z(core_din_iso[2]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din3_iso(.I(core_din_pad[3]),.Z(core_din_iso[3]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din4_iso(.I(core_din_pad[4]),.Z(core_din_iso[4]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din5_iso(.I(core_din_pad[5]),.Z(core_din_iso[5]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din6_iso(.I(core_din_pad[6]),.Z(core_din_iso[6]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_din7_iso(.I(core_din_pad[7]),.Z(core_din_iso[7]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din0_drive(.I(core_din_iso[0]),.Z(core_din[0]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din1_drive(.I(core_din_iso[1]),.Z(core_din[1]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din2_drive(.I(core_din_iso[2]),.Z(core_din[2]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din3_drive(.I(core_din_iso[3]),.Z(core_din[3]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din4_drive(.I(core_din_iso[4]),.Z(core_din[4]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din5_drive(.I(core_din_iso[5]),.Z(core_din[5]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din6_drive(.I(core_din_iso[6]),.Z(core_din[6]));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_din7_drive(.I(core_din_iso[7]),.Z(core_din[7]));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_valid_iso(.I(core_din_valid_pad),.Z(core_din_valid_iso));
    gf180mcu_fd_sc_mcu9t5v0__buf_8 u_valid_drive(.I(core_din_valid_iso),.Z(core_din_valid));

    // Dedicated pad isolation stage.  CTS inserts its root buffer on core_clk,
    // never on the weak in_c/Y pin.
    gf180mcu_fd_sc_mcu9t5v0__clkbuf_1 u_clk_iso(.I(clk_iso),.Z(core_clk));
    gf180mcu_fd_sc_mcu9t5v0__buf_1 u_rst_iso(.I(rst_iso),.Z(rst_root_in));
    gf180mcu_fd_sc_mcu9t5v0__buf_16 u_rst_root(.I(rst_root_in),.Z(core_rst_n));

    butterfold_top u_core(
        .rst_n(core_rst_n), .clk(core_clk), .din(core_din),
        .din_valid_i(core_din_valid), .din_ready_o(core_din_ready),
        .dout(core_dout), .dout_valid_o(core_dout_valid));

    // Programmable bidirectional cell fixed as a low-drive output:
    // IE=0, OE=1, PDRV=00, CMOS input threshold, slow-slew disabled.
    gf180mcu_fd_io__bi_t u_pad_din_ready(
        .CS(1'b0), .SL(1'b0), .IE(1'b0), .OE(1'b1), .PU(1'b0), .PD(1'b0),
        .A(core_din_ready), .PDRV0(1'b1), .PDRV1(1'b1),
        .PAD(pad_din_ready_o), .DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout_valid(
        .CS(1'b0), .SL(1'b0), .IE(1'b0), .OE(1'b1), .PU(1'b0), .PD(1'b0),
        .A(core_dout_valid), .PDRV0(1'b1), .PDRV1(1'b1),
        .PAD(pad_dout_valid_o), .DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout0(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[0]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[0]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout1(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[1]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[1]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout2(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[2]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[2]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout3(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[3]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[3]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout4(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[4]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[4]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout5(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[5]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[5]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout6(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[6]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[6]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));
    gf180mcu_fd_io__bi_t u_pad_dout7(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(core_dout[7]),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(pad_dout[7]),.DVDD(VDD),.DVSS(VSS),.VDD(VDD),.VSS(VSS));

    // Pad-ring power continuity cells.  They are physical infrastructure and
    // do not add logical protocol pins.
    gf180mcu_fd_io__dvdd u_pad_dvdd(.DVDD(VDD), .DVSS(VSS), .VSS(VSS));
    gf180mcu_fd_io__dvss u_pad_dvss(.DVDD(VDD), .DVSS(VSS), .VDD(VDD));
    gf180mcu_fd_io__cor u_corner_sw(.DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__cor u_corner_se(.DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__cor u_corner_ne(.DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
    gf180mcu_fd_io__cor u_corner_nw(.DVDD(VDD), .DVSS(VSS), .VDD(VDD), .VSS(VSS));
endmodule

`default_nettype wire
