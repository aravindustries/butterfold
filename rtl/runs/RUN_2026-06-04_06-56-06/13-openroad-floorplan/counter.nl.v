module counter (clk,
    rst,
    q);
 input clk;
 input rst;
 output [3:0] q;

 wire _00_;
 wire _01_;
 wire _02_;
 wire _03_;
 wire _04_;
 wire _05_;
 wire _06_;
 wire _07_;

 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _08_ (.A1(q[0]),
    .A2(q[1]),
    .B(q[2]),
    .ZN(_04_));
 gf180mcu_fd_sc_mcu7t5v0__and3_1 _09_ (.A1(q[0]),
    .A2(q[1]),
    .A3(q[2]),
    .Z(_05_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _10_ (.A1(rst),
    .A2(_04_),
    .A3(_05_),
    .ZN(_00_));
 gf180mcu_fd_sc_mcu7t5v0__xnor2_1 _11_ (.A1(q[3]),
    .A2(_05_),
    .ZN(_06_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _12_ (.A1(rst),
    .A2(_06_),
    .ZN(_01_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _13_ (.A1(q[0]),
    .A2(rst),
    .ZN(_02_));
 gf180mcu_fd_sc_mcu7t5v0__xnor2_1 _14_ (.A1(q[0]),
    .A2(q[1]),
    .ZN(_07_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _15_ (.A1(rst),
    .A2(_07_),
    .ZN(_03_));
 gf180mcu_fd_sc_mcu7t5v0__dffq_1 _16_ (.D(_02_),
    .CLK(clk),
    .Q(q[0]));
 gf180mcu_fd_sc_mcu7t5v0__dffq_1 _17_ (.D(_03_),
    .CLK(clk),
    .Q(q[1]));
 gf180mcu_fd_sc_mcu7t5v0__dffq_1 _18_ (.D(_00_),
    .CLK(clk),
    .Q(q[2]));
 gf180mcu_fd_sc_mcu7t5v0__dffq_1 _19_ (.D(_01_),
    .CLK(clk),
    .Q(q[3]));
endmodule
