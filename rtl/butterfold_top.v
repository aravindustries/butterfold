// butterfold_top.v — GENERATED integrated TRANSCEIVER (gen_top.py).
// Shared Q9.15 scratch memory + Q1.13 twiddles. int8 only at din/dout.
// TX (cmd 0x03): 24B -> DFT-12 -> map -> IFFT-128 -> CP -> 274B.
// RX (cmd 0x04): 274B -> drop CP -> FFT-128 -> extract -> IDFT-12 -> 24B.
// Mirrors golden/top_exec.py + golden/rx_exec.py (both close EVM<=2%).
`default_nettype none
module butterfold_top (
    input  wire clk_i, input wire rst_ni,
    input  wire [7:0] din, input wire din_valid_i, output reg din_ready_o,
    output wire [7:0] dout, output wire dout_valid_o, input wire dout_ready_i,
    output reg done_irq_o,
    input  wire scan_en_i, input wire scan_in_i, output wire scan_out_o
);
  assign scan_out_o = 1'b0;
  localparam integer TWF = 13;
  localparam integer DFR = 15;

  reg signed [23:0] gr [0:127];
  reg signed [23:0] gi [0:127];
  reg signed [23:0] xr [0:11];
  reg signed [23:0] xi [0:11];
  reg signed [23:0] sr [0:11];
  reg signed [23:0] si [0:11];
  reg signed [23:0] ar [0:11];
  reg signed [23:0] ai [0:11];

  function signed [15:0] w12r_rom; input [3:0] a; case (a)
    4'd0: w12r_rom=16'sd8192;
    4'd1: w12r_rom=16'sd7094;
    4'd2: w12r_rom=16'sd4096;
    4'd3: w12r_rom=16'sd0;
    4'd4: w12r_rom=-16'sd4096;
    4'd5: w12r_rom=-16'sd7094;
    4'd6: w12r_rom=-16'sd8192;
    4'd7: w12r_rom=-16'sd7094;
    4'd8: w12r_rom=-16'sd4096;
    4'd9: w12r_rom=16'sd0;
    4'd10: w12r_rom=16'sd4096;
    4'd11: w12r_rom=16'sd7094;
    default: w12r_rom=16'sd0; endcase endfunction
  function signed [15:0] w12i_rom; input [3:0] a; case (a)
    4'd0: w12i_rom=16'sd0;
    4'd1: w12i_rom=-16'sd4096;
    4'd2: w12i_rom=-16'sd7094;
    4'd3: w12i_rom=-16'sd8192;
    4'd4: w12i_rom=-16'sd7094;
    4'd5: w12i_rom=-16'sd4096;
    4'd6: w12i_rom=16'sd0;
    4'd7: w12i_rom=16'sd4096;
    4'd8: w12i_rom=16'sd7094;
    4'd9: w12i_rom=16'sd8192;
    4'd10: w12i_rom=16'sd7094;
    4'd11: w12i_rom=16'sd4096;
    default: w12i_rom=16'sd0; endcase endfunction
  function signed [15:0] w128r_rom; input [6:0] a; case (a)
    7'd0: w128r_rom=16'sd8192;
    7'd1: w128r_rom=16'sd8182;
    7'd2: w128r_rom=16'sd8153;
    7'd3: w128r_rom=16'sd8103;
    7'd4: w128r_rom=16'sd8035;
    7'd5: w128r_rom=16'sd7946;
    7'd6: w128r_rom=16'sd7839;
    7'd7: w128r_rom=16'sd7713;
    7'd8: w128r_rom=16'sd7568;
    7'd9: w128r_rom=16'sd7405;
    7'd10: w128r_rom=16'sd7225;
    7'd11: w128r_rom=16'sd7027;
    7'd12: w128r_rom=16'sd6811;
    7'd13: w128r_rom=16'sd6580;
    7'd14: w128r_rom=16'sd6333;
    7'd15: w128r_rom=16'sd6070;
    7'd16: w128r_rom=16'sd5793;
    7'd17: w128r_rom=16'sd5501;
    7'd18: w128r_rom=16'sd5197;
    7'd19: w128r_rom=16'sd4880;
    7'd20: w128r_rom=16'sd4551;
    7'd21: w128r_rom=16'sd4212;
    7'd22: w128r_rom=16'sd3862;
    7'd23: w128r_rom=16'sd3503;
    7'd24: w128r_rom=16'sd3135;
    7'd25: w128r_rom=16'sd2760;
    7'd26: w128r_rom=16'sd2378;
    7'd27: w128r_rom=16'sd1990;
    7'd28: w128r_rom=16'sd1598;
    7'd29: w128r_rom=16'sd1202;
    7'd30: w128r_rom=16'sd803;
    7'd31: w128r_rom=16'sd402;
    7'd32: w128r_rom=16'sd0;
    7'd33: w128r_rom=-16'sd402;
    7'd34: w128r_rom=-16'sd803;
    7'd35: w128r_rom=-16'sd1202;
    7'd36: w128r_rom=-16'sd1598;
    7'd37: w128r_rom=-16'sd1990;
    7'd38: w128r_rom=-16'sd2378;
    7'd39: w128r_rom=-16'sd2760;
    7'd40: w128r_rom=-16'sd3135;
    7'd41: w128r_rom=-16'sd3503;
    7'd42: w128r_rom=-16'sd3862;
    7'd43: w128r_rom=-16'sd4212;
    7'd44: w128r_rom=-16'sd4551;
    7'd45: w128r_rom=-16'sd4880;
    7'd46: w128r_rom=-16'sd5197;
    7'd47: w128r_rom=-16'sd5501;
    7'd48: w128r_rom=-16'sd5793;
    7'd49: w128r_rom=-16'sd6070;
    7'd50: w128r_rom=-16'sd6333;
    7'd51: w128r_rom=-16'sd6580;
    7'd52: w128r_rom=-16'sd6811;
    7'd53: w128r_rom=-16'sd7027;
    7'd54: w128r_rom=-16'sd7225;
    7'd55: w128r_rom=-16'sd7405;
    7'd56: w128r_rom=-16'sd7568;
    7'd57: w128r_rom=-16'sd7713;
    7'd58: w128r_rom=-16'sd7839;
    7'd59: w128r_rom=-16'sd7946;
    7'd60: w128r_rom=-16'sd8035;
    7'd61: w128r_rom=-16'sd8103;
    7'd62: w128r_rom=-16'sd8153;
    7'd63: w128r_rom=-16'sd8182;
    7'd64: w128r_rom=-16'sd8192;
    7'd65: w128r_rom=-16'sd8182;
    7'd66: w128r_rom=-16'sd8153;
    7'd67: w128r_rom=-16'sd8103;
    7'd68: w128r_rom=-16'sd8035;
    7'd69: w128r_rom=-16'sd7946;
    7'd70: w128r_rom=-16'sd7839;
    7'd71: w128r_rom=-16'sd7713;
    7'd72: w128r_rom=-16'sd7568;
    7'd73: w128r_rom=-16'sd7405;
    7'd74: w128r_rom=-16'sd7225;
    7'd75: w128r_rom=-16'sd7027;
    7'd76: w128r_rom=-16'sd6811;
    7'd77: w128r_rom=-16'sd6580;
    7'd78: w128r_rom=-16'sd6333;
    7'd79: w128r_rom=-16'sd6070;
    7'd80: w128r_rom=-16'sd5793;
    7'd81: w128r_rom=-16'sd5501;
    7'd82: w128r_rom=-16'sd5197;
    7'd83: w128r_rom=-16'sd4880;
    7'd84: w128r_rom=-16'sd4551;
    7'd85: w128r_rom=-16'sd4212;
    7'd86: w128r_rom=-16'sd3862;
    7'd87: w128r_rom=-16'sd3503;
    7'd88: w128r_rom=-16'sd3135;
    7'd89: w128r_rom=-16'sd2760;
    7'd90: w128r_rom=-16'sd2378;
    7'd91: w128r_rom=-16'sd1990;
    7'd92: w128r_rom=-16'sd1598;
    7'd93: w128r_rom=-16'sd1202;
    7'd94: w128r_rom=-16'sd803;
    7'd95: w128r_rom=-16'sd402;
    7'd96: w128r_rom=16'sd0;
    7'd97: w128r_rom=16'sd402;
    7'd98: w128r_rom=16'sd803;
    7'd99: w128r_rom=16'sd1202;
    7'd100: w128r_rom=16'sd1598;
    7'd101: w128r_rom=16'sd1990;
    7'd102: w128r_rom=16'sd2378;
    7'd103: w128r_rom=16'sd2760;
    7'd104: w128r_rom=16'sd3135;
    7'd105: w128r_rom=16'sd3503;
    7'd106: w128r_rom=16'sd3862;
    7'd107: w128r_rom=16'sd4212;
    7'd108: w128r_rom=16'sd4551;
    7'd109: w128r_rom=16'sd4880;
    7'd110: w128r_rom=16'sd5197;
    7'd111: w128r_rom=16'sd5501;
    7'd112: w128r_rom=16'sd5793;
    7'd113: w128r_rom=16'sd6070;
    7'd114: w128r_rom=16'sd6333;
    7'd115: w128r_rom=16'sd6580;
    7'd116: w128r_rom=16'sd6811;
    7'd117: w128r_rom=16'sd7027;
    7'd118: w128r_rom=16'sd7225;
    7'd119: w128r_rom=16'sd7405;
    7'd120: w128r_rom=16'sd7568;
    7'd121: w128r_rom=16'sd7713;
    7'd122: w128r_rom=16'sd7839;
    7'd123: w128r_rom=16'sd7946;
    7'd124: w128r_rom=16'sd8035;
    7'd125: w128r_rom=16'sd8103;
    7'd126: w128r_rom=16'sd8153;
    7'd127: w128r_rom=16'sd8182;
    default: w128r_rom=16'sd0; endcase endfunction
  function signed [15:0] w128i_rom; input [6:0] a; case (a)
    7'd0: w128i_rom=16'sd0;
    7'd1: w128i_rom=-16'sd402;
    7'd2: w128i_rom=-16'sd803;
    7'd3: w128i_rom=-16'sd1202;
    7'd4: w128i_rom=-16'sd1598;
    7'd5: w128i_rom=-16'sd1990;
    7'd6: w128i_rom=-16'sd2378;
    7'd7: w128i_rom=-16'sd2760;
    7'd8: w128i_rom=-16'sd3135;
    7'd9: w128i_rom=-16'sd3503;
    7'd10: w128i_rom=-16'sd3862;
    7'd11: w128i_rom=-16'sd4212;
    7'd12: w128i_rom=-16'sd4551;
    7'd13: w128i_rom=-16'sd4880;
    7'd14: w128i_rom=-16'sd5197;
    7'd15: w128i_rom=-16'sd5501;
    7'd16: w128i_rom=-16'sd5793;
    7'd17: w128i_rom=-16'sd6070;
    7'd18: w128i_rom=-16'sd6333;
    7'd19: w128i_rom=-16'sd6580;
    7'd20: w128i_rom=-16'sd6811;
    7'd21: w128i_rom=-16'sd7027;
    7'd22: w128i_rom=-16'sd7225;
    7'd23: w128i_rom=-16'sd7405;
    7'd24: w128i_rom=-16'sd7568;
    7'd25: w128i_rom=-16'sd7713;
    7'd26: w128i_rom=-16'sd7839;
    7'd27: w128i_rom=-16'sd7946;
    7'd28: w128i_rom=-16'sd8035;
    7'd29: w128i_rom=-16'sd8103;
    7'd30: w128i_rom=-16'sd8153;
    7'd31: w128i_rom=-16'sd8182;
    7'd32: w128i_rom=-16'sd8192;
    7'd33: w128i_rom=-16'sd8182;
    7'd34: w128i_rom=-16'sd8153;
    7'd35: w128i_rom=-16'sd8103;
    7'd36: w128i_rom=-16'sd8035;
    7'd37: w128i_rom=-16'sd7946;
    7'd38: w128i_rom=-16'sd7839;
    7'd39: w128i_rom=-16'sd7713;
    7'd40: w128i_rom=-16'sd7568;
    7'd41: w128i_rom=-16'sd7405;
    7'd42: w128i_rom=-16'sd7225;
    7'd43: w128i_rom=-16'sd7027;
    7'd44: w128i_rom=-16'sd6811;
    7'd45: w128i_rom=-16'sd6580;
    7'd46: w128i_rom=-16'sd6333;
    7'd47: w128i_rom=-16'sd6070;
    7'd48: w128i_rom=-16'sd5793;
    7'd49: w128i_rom=-16'sd5501;
    7'd50: w128i_rom=-16'sd5197;
    7'd51: w128i_rom=-16'sd4880;
    7'd52: w128i_rom=-16'sd4551;
    7'd53: w128i_rom=-16'sd4212;
    7'd54: w128i_rom=-16'sd3862;
    7'd55: w128i_rom=-16'sd3503;
    7'd56: w128i_rom=-16'sd3135;
    7'd57: w128i_rom=-16'sd2760;
    7'd58: w128i_rom=-16'sd2378;
    7'd59: w128i_rom=-16'sd1990;
    7'd60: w128i_rom=-16'sd1598;
    7'd61: w128i_rom=-16'sd1202;
    7'd62: w128i_rom=-16'sd803;
    7'd63: w128i_rom=-16'sd402;
    7'd64: w128i_rom=16'sd0;
    7'd65: w128i_rom=16'sd402;
    7'd66: w128i_rom=16'sd803;
    7'd67: w128i_rom=16'sd1202;
    7'd68: w128i_rom=16'sd1598;
    7'd69: w128i_rom=16'sd1990;
    7'd70: w128i_rom=16'sd2378;
    7'd71: w128i_rom=16'sd2760;
    7'd72: w128i_rom=16'sd3135;
    7'd73: w128i_rom=16'sd3503;
    7'd74: w128i_rom=16'sd3862;
    7'd75: w128i_rom=16'sd4212;
    7'd76: w128i_rom=16'sd4551;
    7'd77: w128i_rom=16'sd4880;
    7'd78: w128i_rom=16'sd5197;
    7'd79: w128i_rom=16'sd5501;
    7'd80: w128i_rom=16'sd5793;
    7'd81: w128i_rom=16'sd6070;
    7'd82: w128i_rom=16'sd6333;
    7'd83: w128i_rom=16'sd6580;
    7'd84: w128i_rom=16'sd6811;
    7'd85: w128i_rom=16'sd7027;
    7'd86: w128i_rom=16'sd7225;
    7'd87: w128i_rom=16'sd7405;
    7'd88: w128i_rom=16'sd7568;
    7'd89: w128i_rom=16'sd7713;
    7'd90: w128i_rom=16'sd7839;
    7'd91: w128i_rom=16'sd7946;
    7'd92: w128i_rom=16'sd8035;
    7'd93: w128i_rom=16'sd8103;
    7'd94: w128i_rom=16'sd8153;
    7'd95: w128i_rom=16'sd8182;
    7'd96: w128i_rom=16'sd8192;
    7'd97: w128i_rom=16'sd8182;
    7'd98: w128i_rom=16'sd8153;
    7'd99: w128i_rom=16'sd8103;
    7'd100: w128i_rom=16'sd8035;
    7'd101: w128i_rom=16'sd7946;
    7'd102: w128i_rom=16'sd7839;
    7'd103: w128i_rom=16'sd7713;
    7'd104: w128i_rom=16'sd7568;
    7'd105: w128i_rom=16'sd7405;
    7'd106: w128i_rom=16'sd7225;
    7'd107: w128i_rom=16'sd7027;
    7'd108: w128i_rom=16'sd6811;
    7'd109: w128i_rom=16'sd6580;
    7'd110: w128i_rom=16'sd6333;
    7'd111: w128i_rom=16'sd6070;
    7'd112: w128i_rom=16'sd5793;
    7'd113: w128i_rom=16'sd5501;
    7'd114: w128i_rom=16'sd5197;
    7'd115: w128i_rom=16'sd4880;
    7'd116: w128i_rom=16'sd4551;
    7'd117: w128i_rom=16'sd4212;
    7'd118: w128i_rom=16'sd3862;
    7'd119: w128i_rom=16'sd3503;
    7'd120: w128i_rom=16'sd3135;
    7'd121: w128i_rom=16'sd2760;
    7'd122: w128i_rom=16'sd2378;
    7'd123: w128i_rom=16'sd1990;
    7'd124: w128i_rom=16'sd1598;
    7'd125: w128i_rom=16'sd1202;
    7'd126: w128i_rom=16'sd803;
    7'd127: w128i_rom=16'sd402;
    default: w128i_rom=16'sd0; endcase endfunction
  function [6:0] brev; input [6:0] a; case (a)
    7'd0: brev=7'd0;
    7'd1: brev=7'd64;
    7'd2: brev=7'd32;
    7'd3: brev=7'd96;
    7'd4: brev=7'd16;
    7'd5: brev=7'd80;
    7'd6: brev=7'd48;
    7'd7: brev=7'd112;
    7'd8: brev=7'd8;
    7'd9: brev=7'd72;
    7'd10: brev=7'd40;
    7'd11: brev=7'd104;
    7'd12: brev=7'd24;
    7'd13: brev=7'd88;
    7'd14: brev=7'd56;
    7'd15: brev=7'd120;
    7'd16: brev=7'd4;
    7'd17: brev=7'd68;
    7'd18: brev=7'd36;
    7'd19: brev=7'd100;
    7'd20: brev=7'd20;
    7'd21: brev=7'd84;
    7'd22: brev=7'd52;
    7'd23: brev=7'd116;
    7'd24: brev=7'd12;
    7'd25: brev=7'd76;
    7'd26: brev=7'd44;
    7'd27: brev=7'd108;
    7'd28: brev=7'd28;
    7'd29: brev=7'd92;
    7'd30: brev=7'd60;
    7'd31: brev=7'd124;
    7'd32: brev=7'd2;
    7'd33: brev=7'd66;
    7'd34: brev=7'd34;
    7'd35: brev=7'd98;
    7'd36: brev=7'd18;
    7'd37: brev=7'd82;
    7'd38: brev=7'd50;
    7'd39: brev=7'd114;
    7'd40: brev=7'd10;
    7'd41: brev=7'd74;
    7'd42: brev=7'd42;
    7'd43: brev=7'd106;
    7'd44: brev=7'd26;
    7'd45: brev=7'd90;
    7'd46: brev=7'd58;
    7'd47: brev=7'd122;
    7'd48: brev=7'd6;
    7'd49: brev=7'd70;
    7'd50: brev=7'd38;
    7'd51: brev=7'd102;
    7'd52: brev=7'd22;
    7'd53: brev=7'd86;
    7'd54: brev=7'd54;
    7'd55: brev=7'd118;
    7'd56: brev=7'd14;
    7'd57: brev=7'd78;
    7'd58: brev=7'd46;
    7'd59: brev=7'd110;
    7'd60: brev=7'd30;
    7'd61: brev=7'd94;
    7'd62: brev=7'd62;
    7'd63: brev=7'd126;
    7'd64: brev=7'd1;
    7'd65: brev=7'd65;
    7'd66: brev=7'd33;
    7'd67: brev=7'd97;
    7'd68: brev=7'd17;
    7'd69: brev=7'd81;
    7'd70: brev=7'd49;
    7'd71: brev=7'd113;
    7'd72: brev=7'd9;
    7'd73: brev=7'd73;
    7'd74: brev=7'd41;
    7'd75: brev=7'd105;
    7'd76: brev=7'd25;
    7'd77: brev=7'd89;
    7'd78: brev=7'd57;
    7'd79: brev=7'd121;
    7'd80: brev=7'd5;
    7'd81: brev=7'd69;
    7'd82: brev=7'd37;
    7'd83: brev=7'd101;
    7'd84: brev=7'd21;
    7'd85: brev=7'd85;
    7'd86: brev=7'd53;
    7'd87: brev=7'd117;
    7'd88: brev=7'd13;
    7'd89: brev=7'd77;
    7'd90: brev=7'd45;
    7'd91: brev=7'd109;
    7'd92: brev=7'd29;
    7'd93: brev=7'd93;
    7'd94: brev=7'd61;
    7'd95: brev=7'd125;
    7'd96: brev=7'd3;
    7'd97: brev=7'd67;
    7'd98: brev=7'd35;
    7'd99: brev=7'd99;
    7'd100: brev=7'd19;
    7'd101: brev=7'd83;
    7'd102: brev=7'd51;
    7'd103: brev=7'd115;
    7'd104: brev=7'd11;
    7'd105: brev=7'd75;
    7'd106: brev=7'd43;
    7'd107: brev=7'd107;
    7'd108: brev=7'd27;
    7'd109: brev=7'd91;
    7'd110: brev=7'd59;
    7'd111: brev=7'd123;
    7'd112: brev=7'd7;
    7'd113: brev=7'd71;
    7'd114: brev=7'd39;
    7'd115: brev=7'd103;
    7'd116: brev=7'd23;
    7'd117: brev=7'd87;
    7'd118: brev=7'd55;
    7'd119: brev=7'd119;
    7'd120: brev=7'd15;
    7'd121: brev=7'd79;
    7'd122: brev=7'd47;
    7'd123: brev=7'd111;
    7'd124: brev=7'd31;
    7'd125: brev=7'd95;
    7'd126: brev=7'd63;
    7'd127: brev=7'd127;
    default: brev=7'd0; endcase endfunction

  function signed [23:0] sat24; input signed [47:0] x;
    sat24 = (x>48'sd8388607)?24'sd8388607:(x<-48'sd8388608)?-24'sd8388608:x[23:0]; endfunction
  function signed [7:0] nar8; input signed [23:0] v; reg signed [47:0] r; begin
    r = ($signed(v) + (48'sd1<<<(DFR-8))) >>> (DFR-7);
    nar8 = (r>127)?8'sd127:(r<-128)?-8'sd128:r[7:0]; end endfunction
  function signed [23:0] div12; input signed [47:0] x;
    div12 = ($signed(x)*48'sd2731 + 48'sd16384) >>> 15; endfunction

  localparam S_IDLE=0,S_LOAD=1,S_DFT=2,S_ZERO=3,S_MAP=4,S_FFT=5,S_EXT=6,S_IDFT=7,S_OUT=8,S_DONE=9;
  reg [3:0] st;
  reg       mode;                 // 0=TX, 1=RX
  reg [8:0] bcnt;
  reg [3:0] dn, dk, mi;
  reg signed [47:0] accr, acci;
  reg [7:0] zc, ocnt;
  reg [2:0] stage;
  reg [6:0] grp, kk;
  reg       ophase;
  reg signed [23:0] ib;

  wire signed [23:0] din_ext = $signed(din);
  wire [8:0] sidx = bcnt[8:1];
  wire [8:0] rxa9 = sidx - 9'd9;          // RX useful-sample index (0..127 when sidx>=9)
  wire [6:0] rxa  = rxa9[6:0];

  // 12-pt MAC (TX forward DFT on xr/xi; RX inverse IDFT on ar/ai + /12)
  wire [3:0] m12 = (dn*dk)%12;
  wire signed [15:0] fwr = w12r_rom(m12);
  wire signed [15:0] fwi = w12i_rom(m12);
  wire signed [47:0] dt_r = $signed(xr[dk])*fwr - $signed(xi[dk])*fwi;   // TX
  wire signed [47:0] dt_i = $signed(xr[dk])*fwi + $signed(xi[dk])*fwr;
  wire signed [47:0] it_r = $signed(ar[dk])*fwr - $signed(ai[dk])*(-fwi);// RX (conj)
  wire signed [47:0] it_i = $signed(ar[dk])*(-fwi) + $signed(ai[dk])*fwr;
  wire signed [47:0] nra = accr + (mode ? it_r : dt_r);
  wire signed [47:0] nia = acci + (mode ? it_i : dt_i);

  // butterfly (TX: inverse => conjugate twiddle + >>1 ; RX: forward => no conj, no shift)
  wire [6:0] btop = grp + kk;
  wire [6:0] bbot = grp + (7'd1<<stage) + kk;
  wire [6:0] twa  = kk << (6-stage);
  wire signed [15:0] cwr = w128r_rom(twa);
  wire signed [15:0] cwi = mode ? w128i_rom(twa) : -w128i_rom(twa);
  wire signed [47:0] tpr = $signed(gr[bbot])*cwr - $signed(gi[bbot])*cwi;
  wire signed [47:0] tpi = $signed(gr[bbot])*cwi + $signed(gi[bbot])*cwr;
  wire signed [47:0] btr = (tpr + (48'sd1<<<(TWF-1))) >>> TWF;
  wire signed [47:0] bti = (tpi + (48'sd1<<<(TWF-1))) >>> TWF;
  wire signed [47:0] add_r = $signed(gr[btop]) + btr;
  wire signed [47:0] sub_r = $signed(gr[btop]) - btr;
  wire signed [47:0] add_i = $signed(gi[btop]) + bti;
  wire signed [47:0] sub_i = $signed(gi[btop]) - bti;

  wire [7:0] out_lin = (ocnt < 8'd9) ? (8'd119 + ocnt) : (ocnt - 8'd9);
  assign dout_valid_o = (st == S_OUT);
  assign dout = mode ? (ophase ? nar8(si[ocnt[3:0]]) : nar8(sr[ocnt[3:0]]))
                     : (ophase ? nar8(gi[out_lin])   : nar8(gr[out_lin]));

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st<=S_IDLE; din_ready_o<=0; done_irq_o<=0; mode<=0;
      bcnt<=0; dn<=0; dk<=0; mi<=0; accr<=0; acci<=0; zc<=0; ocnt<=0;
      stage<=0; grp<=0; kk<=0; ophase<=0;
    end else begin
      done_irq_o<=0;
      case (st)
        S_IDLE: begin
          din_ready_o<=1;
          if (din_valid_i && (din==8'h03 || din==8'h04)) begin
            st<=S_LOAD; bcnt<=0; mode<=(din==8'h04);
          end
        end
        S_LOAD: begin
          din_ready_o<=1;
          if (din_valid_i) begin
            if (bcnt[0]==1'b0) ib <= din_ext <<< (DFR-7);
            else begin
              if (!mode) begin xr[sidx[3:0]]<=ib; xi[sidx[3:0]]<=din_ext<<<(DFR-7); end
              else if (sidx >= 9'd9) begin
                gr[brev(rxa)] <= ib;
                gi[brev(rxa)] <= din_ext<<<(DFR-7);
              end
            end
            if (bcnt == (mode ? 9'd273 : 9'd23)) begin
              din_ready_o<=0; dn<=0; dk<=0; accr<=0; acci<=0; stage<=0; grp<=0; kk<=0;
              st <= mode ? S_FFT : S_DFT;
            end else bcnt<=bcnt+9'd1;
          end
        end
        S_DFT: begin
          if (dk==4'd11) begin
            sr[dn] <= sat24((nra + (48'sd1<<<(TWF-1))) >>> TWF);
            si[dn] <= sat24((nia + (48'sd1<<<(TWF-1))) >>> TWF);
            dk<=0; accr<=0; acci<=0;
            if (dn==4'd11) begin st<=S_ZERO; zc<=0; end else dn<=dn+4'd1;
          end else begin accr<=nra; acci<=nia; dk<=dk+4'd1; end
        end
        S_ZERO: begin
          gr[zc[6:0]]<=24'sd0; gi[zc[6:0]]<=24'sd0;
          if (zc==8'd127) begin st<=S_MAP; mi<=0; end else zc<=zc+8'd1;
        end
        S_MAP: begin
          gr[brev(7'd58 + mi)] <= sr[mi];
          gi[brev(7'd58 + mi)] <= si[mi];
          if (mi==4'd11) begin st<=S_FFT; stage<=0; grp<=0; kk<=0; end else mi<=mi+4'd1;
        end
        S_FFT: begin
          gr[btop]<=sat24(mode ? add_r : ((add_r+48'sd1)>>>1));
          gi[btop]<=sat24(mode ? add_i : ((add_i+48'sd1)>>>1));
          gr[bbot]<=sat24(mode ? sub_r : ((sub_r+48'sd1)>>>1));
          gi[bbot]<=sat24(mode ? sub_i : ((sub_i+48'sd1)>>>1));
          if (kk == (7'd1<<stage)-7'd1) begin
            kk<=0;
            if ({1'b0,grp} + (8'd1<<(stage+1)) >= 9'd128) begin
              grp<=0;
              if (stage==3'd6) begin
                if (mode) begin st<=S_EXT; mi<=0; end
                else begin st<=S_OUT; ocnt<=0; ophase<=0; end
              end else stage<=stage+3'd1;
            end else grp<=grp + (7'd1<<(stage+1));
          end else kk<=kk+7'd1;
        end
        S_EXT: begin
          ar[mi] <= gr[7'd58+mi]; ai[mi] <= gi[7'd58+mi];
          if (mi==4'd11) begin st<=S_IDFT; dn<=0; dk<=0; accr<=0; acci<=0; end else mi<=mi+4'd1;
        end
        S_IDFT: begin
          if (dk==4'd11) begin
            sr[dn] <= sat24(div12((nra + (48'sd1<<<(TWF-1))) >>> TWF));
            si[dn] <= sat24(div12((nia + (48'sd1<<<(TWF-1))) >>> TWF));
            dk<=0; accr<=0; acci<=0;
            if (dn==4'd11) begin st<=S_OUT; ocnt<=0; ophase<=0; end else dn<=dn+4'd1;
          end else begin accr<=nra; acci<=nia; dk<=dk+4'd1; end
        end
        S_OUT: begin
          if (dout_ready_i) begin
            if (ophase) begin
              ophase<=0;
              if (ocnt == (mode ? 8'd11 : 8'd136)) st<=S_DONE;
              else ocnt<=ocnt+8'd1;
            end else ophase<=1;
          end
        end
        S_DONE: begin done_irq_o<=1; st<=S_IDLE; end
        default: st<=S_IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
