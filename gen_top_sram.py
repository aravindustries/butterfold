"""
gen_top_sram.py — SRAM-backed variant of the integrated ButterFold transceiver top.

Same algorithm, ports and arithmetic as gen_top.py (bit-exact to golden/top_exec.py
and golden/rx_exec.py), but the 128-entry x 24-bit complex scratch memory (gr/gi)
is a real GF180 SINGLE-PORT SRAM instead of a flip-flop register file:
  gr -> 3x gf180mcu_fd_ip_sram__sram128x8m8wm1  (bytes [23:16],[15:8],[7:0])
  gi -> 3x  "                                  "
All 6 macros share one 7-bit address port (one access/cycle, 1-cycle read latency).

Because the register-file top read/wrote FOUR grid locations per cycle, every state
that touches gr/gi is re-sequenced onto the single port:
  * FFT butterfly  -> 5 sub-cycles  (read top, read bot, compute+write top, write bot)
  * EXTRACT        -> 2 sub-cycles  (present addr, capture)
  * TX OUT         -> read+capture the sample, then stream its I and Q bytes
The small 12-entry DFT buffers (xr/xi/sr/si/ar/ai) stay as registers.

Result is a functionally identical transceiver whose scratch memory is SRAM — the
end-to-end SRAM counterpart of the register-file gen_top.py. PPA/GDS use the macro
blackbox; simulation uses rtl_sram/sram128x8_behav.v.
"""
from __future__ import annotations
import pathlib
import gen_top   # reuse _tw / _bitrev / _rom / _brev_fn

ROOT  = pathlib.Path(__file__).parent
OUT   = ROOT / "generated" / "rtl" / "butterfold_top_sram.v"
DFRAC, TWFRAC, START = gen_top.DFRAC, gen_top.TWFRAC, gen_top.START


def generate() -> str:
    w12r, w12i = gen_top._tw(12); w128r, w128i = gen_top._tw(128); perm = gen_top._bitrev(128)
    def sram(name, bytesel, q):
        return (f"  gf180mcu_fd_ip_sram__sram128x8m8wm1 {name} (.CLK(clk_i), .CEN(1'b0),\n"
                f"      .GWEN(gwen), .WEN(wen), .A(mem_a), .D({bytesel}), .Q({q}));")
    return f"""// butterfold_top_sram.v — GENERATED integrated TRANSCEIVER, SRAM scratch (gen_top_sram.py).
// Same math as butterfold_top.v (register-file) but gr/gi live in 6 single-port
// GF180 sram128x8 macros; grid accesses are sequenced over the single port.
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

  // small register buffers (unchanged from the register-file top)
  reg signed [23:0] xr [0:11];
  reg signed [23:0] xi [0:11];
  reg signed [23:0] sr [0:11];
  reg signed [23:0] si [0:11];
  reg signed [23:0] ar [0:11];
  reg signed [23:0] ai [0:11];

{gen_top._rom('w12r_rom', w12r, 4)}
{gen_top._rom('w12i_rom', w12i, 4)}
{gen_top._rom('w128r_rom', w128r, 7)}
{gen_top._rom('w128i_rom', w128i, 7)}
{gen_top._brev_fn(perm)}

  function signed [23:0] sat24; input signed [47:0] x;
    sat24 = (x>48'sd8388607)?24'sd8388607:(x<-48'sd8388608)?-24'sd8388608:x[23:0]; endfunction
  function signed [7:0] nar8; input signed [23:0] v; reg signed [47:0] r; begin
    r = ($signed(v) + (48'sd1<<<(DFR-8))) >>> (DFR-7);
    nar8 = (r>127)?8'sd127:(r<-128)?-8'sd128:r[7:0]; end endfunction
  function signed [23:0] div12; input signed [47:0] x;
    div12 = ($signed(x)*48'sd2731 + 48'sd16384) >>> 15; endfunction

  // ---------------- single-port SRAM scratch (gr/gi, 128 x 24) ----------------
  reg  [6:0]  mem_a;
  reg         mem_we;
  reg  signed [23:0] gr_d, gi_d;
  wire [23:0] gr_q, gi_q;
  wire        gwen = ~mem_we;
  wire [7:0]  wen  = mem_we ? 8'h00 : 8'hFF;
{sram('u_gr2','gr_d[23:16]','gr_q[23:16]')}
{sram('u_gr1','gr_d[15:8]' ,'gr_q[15:8]')}
{sram('u_gr0','gr_d[7:0]'  ,'gr_q[7:0]')}
{sram('u_gi2','gi_d[23:16]','gi_q[23:16]')}
{sram('u_gi1','gi_d[15:8]' ,'gi_q[15:8]')}
{sram('u_gi0','gi_d[7:0]'  ,'gi_q[7:0]')}

  localparam S_IDLE=0,S_LOAD=1,S_DFT=2,S_ZERO=3,S_MAP=4,S_FFT=5,S_EXT=6,S_IDFT=7,S_OUT=8,S_DONE=9;
  reg [3:0] st;
  reg [2:0] ss;                   // sub-state for memory sequencing
  reg       mode;                 // 0=TX, 1=RX
  reg [8:0] bcnt;
  reg [3:0] dn, dk, mi;
  reg signed [47:0] accr, acci;
  reg [7:0] zc, ocnt;
  reg [2:0] stage;
  reg [6:0] grp, kk;
  reg       ophase;
  reg signed [23:0] ib;
  reg signed [23:0] topr, topi;   // captured butterfly operands / results
  reg signed [23:0] subr, subi;
  reg signed [23:0] cr, ci;       // captured TX output sample

  wire signed [23:0] din_ext = $signed(din);
  wire [8:0] sidx = bcnt[8:1];
  wire [8:0] rxa9 = sidx - 9'd9;
  wire [6:0] rxa  = rxa9[6:0];

  // 12-pt MAC (unchanged: operates on the register buffers, not the SRAM)
  wire [3:0] m12 = (dn*dk)%12;
  wire signed [15:0] fwr = w12r_rom(m12);
  wire signed [15:0] fwi = w12i_rom(m12);
  wire signed [47:0] dt_r = $signed(xr[dk])*fwr - $signed(xi[dk])*fwi;
  wire signed [47:0] dt_i = $signed(xr[dk])*fwi + $signed(xi[dk])*fwr;
  wire signed [47:0] it_r = $signed(ar[dk])*fwr - $signed(ai[dk])*(-fwi);
  wire signed [47:0] it_i = $signed(ar[dk])*(-fwi) + $signed(ai[dk])*fwr;
  wire signed [47:0] nra = accr + (mode ? it_r : dt_r);
  wire signed [47:0] nia = acci + (mode ? it_i : dt_i);

  // butterfly (uses captured top + LIVE bottom read on gr_q/gi_q in ss==2)
  wire [6:0] btop = grp + kk;
  wire [6:0] bbot = grp + (7'd1<<stage) + kk;
  wire [6:0] twa  = kk << (6-stage);
  wire signed [15:0] cwr = w128r_rom(twa);
  wire signed [15:0] cwi = mode ? w128i_rom(twa) : -w128i_rom(twa);
  wire signed [47:0] tpr = $signed(gr_q)*cwr - $signed(gi_q)*cwi;
  wire signed [47:0] tpi = $signed(gr_q)*cwi + $signed(gi_q)*cwr;
  wire signed [47:0] btr = (tpr + (48'sd1<<<(TWF-1))) >>> TWF;
  wire signed [47:0] bti = (tpi + (48'sd1<<<(TWF-1))) >>> TWF;
  wire signed [47:0] add_r = $signed(topr) + btr;
  wire signed [47:0] add_i = $signed(topi) + bti;
  wire signed [47:0] sub_r = $signed(topr) - btr;
  wire signed [47:0] sub_i = $signed(topi) - bti;
  wire signed [23:0] wadd_r = sat24(mode ? add_r : ((add_r+48'sd1)>>>1));
  wire signed [23:0] wadd_i = sat24(mode ? add_i : ((add_i+48'sd1)>>>1));
  wire signed [23:0] wsub_r = sat24(mode ? sub_r : ((sub_r+48'sd1)>>>1));
  wire signed [23:0] wsub_i = sat24(mode ? sub_i : ((sub_i+48'sd1)>>>1));

  wire [7:0] out_lin = (ocnt < 8'd9) ? (8'd119 + ocnt) : (ocnt - 8'd9);
  assign dout_valid_o = (st == S_OUT) && (mode || (ss == 3'd2));
  assign dout = mode ? (ophase ? nar8(si[ocnt[3:0]]) : nar8(sr[ocnt[3:0]]))
                     : (ophase ? nar8(ci) : nar8(cr));

  // ---------------- combinational single-port memory driver ----------------
  always @* begin
    mem_a = 7'd0; mem_we = 1'b0; gr_d = 24'sd0; gi_d = 24'sd0;
    case (st)
      S_LOAD: if (mode && din_valid_i && bcnt[0] && (sidx >= 9'd9)) begin
                mem_a = brev(rxa); mem_we = 1'b1;
                gr_d = ib; gi_d = din_ext <<< (DFR-7);
              end
      S_ZERO: begin mem_a = zc[6:0]; mem_we = 1'b1; gr_d = 24'sd0; gi_d = 24'sd0; end
      S_MAP:  begin mem_a = brev(7'd{START} + mi); mem_we = 1'b1; gr_d = sr[mi]; gi_d = si[mi]; end
      S_FFT: case (ss)
               3'd0: mem_a = btop;                                   // read top
               3'd1: mem_a = bbot;                                   // read bot
               3'd2: begin mem_a = btop; mem_we = 1'b1; gr_d = wadd_r; gi_d = wadd_i; end
               3'd3: begin mem_a = bbot; mem_we = 1'b1; gr_d = subr;  gi_d = subi;  end
               default: ;
             endcase
      S_EXT:  mem_a = 7'd{START} + mi;                               // read grid[58+mi]
      S_OUT:  if (!mode) mem_a = out_lin[6:0];                       // TX read grid[out_lin]
      default: ;
    endcase
  end

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st<=S_IDLE; ss<=0; din_ready_o<=0; done_irq_o<=0; mode<=0;
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
            else if (!mode) begin xr[sidx[3:0]]<=ib; xi[sidx[3:0]]<=din_ext<<<(DFR-7); end
            // RX grid write is issued by the combinational memory driver above
            if (bcnt == (mode ? 9'd273 : 9'd23)) begin
              din_ready_o<=0; dn<=0; dk<=0; accr<=0; acci<=0; stage<=0; grp<=0; kk<=0; ss<=0;
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
          if (zc==8'd127) begin st<=S_MAP; mi<=0; end else zc<=zc+8'd1;
        end
        S_MAP: begin
          if (mi==4'd11) begin st<=S_FFT; stage<=0; grp<=0; kk<=0; ss<=0; end else mi<=mi+4'd1;
        end
        S_FFT: case (ss)
          3'd0: ss<=3'd1;                                    // ss0 presented top (read)
          3'd1: begin topr<=$signed(gr_q); topi<=$signed(gi_q); ss<=3'd2; end  // gr_q=top; present bot
          3'd2: begin subr<=wsub_r; subi<=wsub_i; ss<=3'd3; end                // gr_q=bot; write top; reg sub
          3'd3: ss<=3'd4;                                    // write bot
          3'd4: begin
            ss<=3'd0;
            if (kk == (7'd1<<stage)-7'd1) begin
              kk<=0;
              if ({{1'b0,grp}} + (8'd1<<(stage+1)) >= 9'd128) begin
                grp<=0;
                if (stage==3'd6) begin
                  if (mode) begin st<=S_EXT; mi<=0; end
                  else begin st<=S_OUT; ocnt<=0; ophase<=0; end
                end else stage<=stage+3'd1;
              end else grp<=grp + (7'd1<<(stage+1));
            end else kk<=kk+7'd1;
          end
          default: ss<=3'd0;
        endcase
        S_EXT: case (ss)
          3'd0: ss<=3'd1;                                    // ss0 presented grid[58+mi]
          3'd1: begin
            ar[mi]<=$signed(gr_q); ai[mi]<=$signed(gi_q); ss<=3'd0;
            if (mi==4'd11) begin st<=S_IDFT; dn<=0; dk<=0; accr<=0; acci<=0; end else mi<=mi+4'd1;
          end
          default: ss<=3'd0;
        endcase
        S_IDFT: begin
          if (dk==4'd11) begin
            sr[dn] <= sat24(div12((nra + (48'sd1<<<(TWF-1))) >>> TWF));
            si[dn] <= sat24(div12((nia + (48'sd1<<<(TWF-1))) >>> TWF));
            dk<=0; accr<=0; acci<=0;
            if (dn==4'd11) begin st<=S_OUT; ocnt<=0; ophase<=0; end else dn<=dn+4'd1;
          end else begin accr<=nra; acci<=nia; dk<=dk+4'd1; end
        end
        S_OUT: begin
          if (mode) begin                                   // RX: from sr/si registers (no SRAM)
            if (dout_ready_i) begin
              if (ophase) begin
                ophase<=0;
                if (ocnt == 8'd11) st<=S_DONE; else ocnt<=ocnt+8'd1;
              end else ophase<=1;
            end
          end else case (ss)                                // TX: read grid[out_lin], then stream I,Q
            3'd0: ss<=3'd1;                                  // ss0 presented out_lin
            3'd1: begin cr<=$signed(gr_q); ci<=$signed(gi_q); ss<=3'd2; end
            3'd2: if (dout_ready_i) begin
                    if (ophase) begin
                      ophase<=0;
                      if (ocnt == 8'd136) st<=S_DONE;
                      else begin ocnt<=ocnt+8'd1; ss<=3'd0; end
                    end else ophase<=1;
                  end
            default: ss<=3'd0;
          endcase
        end
        S_DONE: begin done_irq_o<=1; st<=S_IDLE; ss<=0; end
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
    print(f"[gen_top_sram] wrote {OUT} ({len(generate().splitlines())} lines)")
