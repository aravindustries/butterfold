module padframe_characterize_netlist(
    input  wire pad_in,
    output wire in_c_y,
    output wire in_s_y,
    output wire chain2_y,
    output wire chain4_y,
    output wire chain6_y,
    output wire chain8_y,
    input  wire out_a,
    output wire out_pad,
    output wire out_pad01,
    output wire out_pad10,
    output wire out_pad11,
    output wire out_pad11f
);
  wire c0, c1, c2, c3, c4, c5, c6, c7;
  gf180mcu_fd_io__in_c u_in_c(.PU(1'b0), .PD(1'b0), .PAD(pad_in), .Y(in_c_y));
  gf180mcu_fd_io__in_s u_in_s(.PU(1'b0), .PD(1'b0), .PAD(pad_in), .Y(in_s_y));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b0(.I(in_c_y), .Z(c0));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b1(.I(c0), .Z(chain2_y));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b2(.I(chain2_y), .Z(c2));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b3(.I(c2), .Z(chain4_y));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b4(.I(chain4_y), .Z(c4));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b5(.I(c4), .Z(chain6_y));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b6(.I(chain6_y), .Z(c6));
  gf180mcu_fd_sc_mcu9t5v0__buf_1 b7(.I(c6), .Z(chain8_y));
  gf180mcu_fd_io__bi_t u_out(
      .CS(1'b0), .SL(1'b0), .IE(1'b0), .OE(1'b1),
      .PU(1'b0), .PD(1'b0), .A(out_a), .PDRV0(1'b0), .PDRV1(1'b0),
      .PAD(out_pad)
  );
  gf180mcu_fd_io__bi_t u_out01(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(out_a),.PDRV0(1'b0),.PDRV1(1'b1),.PAD(out_pad01));
  gf180mcu_fd_io__bi_t u_out10(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(out_a),.PDRV0(1'b1),.PDRV1(1'b0),.PAD(out_pad10));
  gf180mcu_fd_io__bi_t u_out11(.CS(1'b0),.SL(1'b0),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(out_a),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(out_pad11));
  gf180mcu_fd_io__bi_t u_out11f(.CS(1'b0),.SL(1'b1),.IE(1'b0),.OE(1'b1),.PU(1'b0),.PD(1'b0),.A(out_a),.PDRV0(1'b1),.PDRV1(1'b1),.PAD(out_pad11f));
endmodule
