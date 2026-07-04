"""
gen_top.py — generate the integrated butterfold_top.v datapath.

Mirrors golden/top_exec.py bit-for-bit (DFRAC=15, TWFRAC=13): a shared 128-entry
Q9.15 scratch memory carries the whole transform (DFT-12 -> centered map ->
bit-reverse -> 448-butterfly IFFT -> CP), int8 only at din/dout. This precision
closes the EVM <= 2% gate; the modular int8/Q5.11 streaming interfaces cannot.

Twiddle ROMs (Q1.13) are baked in as case functions so the module is fully
self-contained and synthesizable (no $readmemh) — clean through LibreLane/GDS.
"""
from __future__ import annotations
import pathlib
import numpy as np

ROOT  = pathlib.Path(__file__).parent
OUT   = ROOT / "generated" / "rtl" / "butterfold_top.v"
DFRAC, TWFRAC, START = 15, 13, 58


def _tw(n):
    idx = np.arange(n); tw = np.exp(-2j * np.pi * idx / n); sc = 1 << TWFRAC
    return ([int(round(v)) for v in tw.real * sc], [int(round(v)) for v in tw.imag * sc])


def _bitrev(n=128):
    bits = int(np.log2(n)); out = []
    for i in range(n):
        r = 0
        for b in range(bits):
            r = (r << 1) | ((i >> b) & 1)
        out.append(r)
    return out


def _rom(name, vals, aw):
    L = [f"  function signed [15:0] {name}; input [{aw-1}:0] a; case (a)"]
    for i, v in enumerate(vals):
        vs = f"16'sd{v}" if v >= 0 else f"-16'sd{-v}"
        L.append(f"    {aw}'d{i}: {name}={vs};")
    L.append(f"    default: {name}=16'sd0; endcase endfunction")
    return "\n".join(L)


def _brev_fn(perm):
    L = ["  function [6:0] brev; input [6:0] a; case (a)"]
    for i, p in enumerate(perm):
        L.append(f"    7'd{i}: brev=7'd{p};")
    L.append("    default: brev=7'd0; endcase endfunction")
    return "\n".join(L)


def generate() -> str:
    w12r, w12i = _tw(12); w128r, w128i = _tw(128); perm = _bitrev(128)
    return f"""// butterfold_top.v — GENERATED integrated datapath (gen_top.py).
// Full fixed-point DFT-s-OFDM TX in a shared Q9.15 scratch memory, Q1.{TWFRAC} twiddles.
// DFT-12 -> map(START={START}) -> bit-reverse -> IFFT-128 (448 butterflies) -> CP-9.
// Command: din byte0=0x03 then 24 payload bytes; streams 274 bytes on dout.
// int8 only at din/dout. Mirrors golden/top_exec.py (closes EVM<=2%).
`default_nettype none
module butterfold_top (
    input  wire clk_i, input wire rst_ni,
    input  wire [7:0] din, input wire din_valid_i, output reg din_ready_o,
    output wire [7:0] dout, output wire dout_valid_o, input wire dout_ready_i,
    output reg done_irq_o,
    input  wire scan_en_i, input wire scan_in_i, output wire scan_out_o
);
  assign scan_out_o = 1'b0;
  localparam integer TWF = {TWFRAC};
  localparam integer DFR = {DFRAC};

  reg signed [23:0] gr [0:127];
  reg signed [23:0] gi [0:127];
  reg signed [23:0] xr [0:11];
  reg signed [23:0] xi [0:11];
  reg signed [23:0] sr [0:11];
  reg signed [23:0] si [0:11];

{_rom('w12r_rom', w12r, 4)}
{_rom('w12i_rom', w12i, 4)}
{_rom('w128r_rom', w128r, 7)}
{_rom('w128i_rom', w128i, 7)}
{_brev_fn(perm)}

  function signed [23:0] sat24; input signed [47:0] x;
    sat24 = (x>48'sd8388607)?24'sd8388607:(x<-48'sd8388608)?-24'sd8388608:x[23:0]; endfunction
  function signed [7:0] nar8; input signed [23:0] v; reg signed [47:0] r; begin
    r = ($signed(v) + (48'sd1<<<(DFR-8))) >>> (DFR-7);
    nar8 = (r>127)?8'sd127:(r<-128)?-8'sd128:r[7:0]; end endfunction

  localparam S_IDLE=0,S_LOAD=1,S_DFT=2,S_ZERO=3,S_MAP=4,S_IFFT=5,S_OUT=6,S_DONE=7;
  reg [2:0] st;
  reg [4:0] bcnt;
  reg [3:0] dn, dk, mi;
  reg signed [47:0] accr, acci;
  reg [7:0] zc, ocnt;
  reg [2:0] stage;
  reg [6:0] grp, kk;
  reg       ophase;
  reg signed [23:0] ib;

  wire signed [23:0] din_ext = $signed(din);   // sign-extend to 24b BEFORE shifting
  wire [3:0] m12 = (dn*dk)%12;
  wire signed [47:0] term_r = $signed(xr[dk])*w12r_rom(m12) - $signed(xi[dk])*w12i_rom(m12);
  wire signed [47:0] term_i = $signed(xr[dk])*w12i_rom(m12) + $signed(xi[dk])*w12r_rom(m12);
  wire signed [47:0] nra = accr + term_r;
  wire signed [47:0] nia = acci + term_i;

  wire [6:0] btop = grp + kk;
  wire [6:0] bbot = grp + (7'd1<<stage) + kk;
  wire [6:0] twa  = kk << (6-stage);
  wire signed [15:0] cwr = w128r_rom(twa);
  wire signed [15:0] cwi = -w128i_rom(twa);
  wire signed [47:0] tpr = $signed(gr[bbot])*cwr - $signed(gi[bbot])*cwi;
  wire signed [47:0] tpi = $signed(gr[bbot])*cwi + $signed(gi[bbot])*cwr;
  wire signed [47:0] btr = (tpr + (48'sd1<<<(TWF-1))) >>> TWF;
  wire signed [47:0] bti = (tpi + (48'sd1<<<(TWF-1))) >>> TWF;
  wire [7:0] out_lin = (ocnt < 8'd9) ? (8'd119 + ocnt) : (ocnt - 8'd9);
  // combinational output: dout always reflects the CURRENT (ocnt,ophase) byte,
  // so it never lags the handshake advance (that off-by-one duplicates byte 0).
  assign dout_valid_o = (st == S_OUT);
  assign dout = ophase ? nar8(gi[out_lin]) : nar8(gr[out_lin]);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st<=S_IDLE; din_ready_o<=0; done_irq_o<=0;
      bcnt<=0; dn<=0; dk<=0; mi<=0; accr<=0; acci<=0; zc<=0; ocnt<=0;
      stage<=0; grp<=0; kk<=0; ophase<=0;
    end else begin
      done_irq_o<=0;
      case (st)
        S_IDLE: begin
          din_ready_o<=1;
          if (din_valid_i && din == 8'h03) begin st<=S_LOAD; bcnt<=0; end
        end
        S_LOAD: begin
          din_ready_o<=1;
          if (din_valid_i) begin
            if (bcnt[0]==1'b0) ib <= din_ext <<< (DFR-7);
            else begin xr[bcnt[4:1]] <= ib; xi[bcnt[4:1]] <= din_ext <<< (DFR-7); end
            if (bcnt==5'd23) begin st<=S_DFT; din_ready_o<=0; dn<=0; dk<=0; accr<=0; acci<=0; end
            else bcnt<=bcnt+5'd1;
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
          gr[brev(7'd{START} + mi)] <= sr[mi];
          gi[brev(7'd{START} + mi)] <= si[mi];
          if (mi==4'd11) begin st<=S_IFFT; stage<=0; grp<=0; kk<=0; end
          else mi<=mi+4'd1;
        end
        S_IFFT: begin
          gr[btop]<=sat24(($signed(gr[btop])+btr+48'sd1)>>>1);
          gi[btop]<=sat24(($signed(gi[btop])+bti+48'sd1)>>>1);
          gr[bbot]<=sat24(($signed(gr[btop])-btr+48'sd1)>>>1);
          gi[bbot]<=sat24(($signed(gi[btop])-bti+48'sd1)>>>1);
          if (kk == (7'd1<<stage)-7'd1) begin
            kk<=0;
            if ({{1'b0,grp}} + (8'd1<<(stage+1)) >= 9'd128) begin
              grp<=0;
              if (stage==3'd6) begin st<=S_OUT; ocnt<=0; ophase<=0; end
              else stage<=stage+3'd1;
            end else grp<=grp + (7'd1<<(stage+1));
          end else kk<=kk+7'd1;
        end
        S_OUT: begin
          if (dout_ready_i) begin           // dout_valid_o is high throughout S_OUT
            if (ophase) begin
              ophase<=0;
              if (ocnt==8'd136) st<=S_DONE;
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
"""


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(generate(), encoding="utf-8")
    print(f"[gen_top] wrote {OUT} ({len(generate().splitlines())} lines)")
