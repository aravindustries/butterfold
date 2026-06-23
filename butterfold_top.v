// butterfold_top.v  —  GENERATED hierarchical reference by gen_reference.py
// DFT-s-OFDM TX core: 12-pt DFT -> centered map -> 128-pt IFFT -> CP -> 274 bytes
//
// Wrapper/control around butterfold_kernel (the locked bit-exact datapath):
//   - block-streaming FSM (load -> DFT -> IFFT -> emit)
//   - input deserializer (24 bytes -> 12 complex symbols)
//   - CP + centered-map address generator (samp, tau, w_idx)  <-- cyclic prefix here
//   - output serializer (I then Q bytes)
// The shared complex multiplier and twiddle ROMs live in butterfold_kernel.
//
// Frozen params: K=12, M=128, CP=9, centered START=58, twiddle bits A=B=9, SHIFT=25

`timescale 1ns/1ps
module butterfold_top (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        mode,        // 0 = TX (golden path), 1 = RX
  input  wire  [7:0] din,
  input  wire        din_valid,
  output reg   [7:0] dout,
  output reg         dout_valid,
  output reg         busy,
  output reg         done
);

  // ── FSM states ──────────────────────────────────────────────────────────
  localparam S_IDLE = 3'd0;
  localparam S_LOAD = 3'd1;   // capture 24 input bytes (12 complex symbols)
  localparam S_DFT  = 3'd2;   // 12x12 MACs -> 12 spread bins (one MAC/cycle)
  localparam S_IFFT = 3'd3;   // 12 MACs per output sample (one MAC/cycle)
  localparam S_EMIT = 3'd4;   // stream the sample's I then Q byte

  reg [2:0]  state;
  reg [4:0]  load_cnt;        // 0..23
  reg [3:0]  dft_j, dft_n;    // DFT outer/inner indices 0..11
  reg [7:0]  samp;            // current output sample 0..136
  reg [3:0]  ifft_j;          // IFFT accumulation index 0..11
  reg        emit_half;       // 0 = emit I byte, 1 = emit Q byte

  // ── Input buffer (24 signed bytes) ──────────────────────────────────────
  (* mem2reg *) reg signed [7:0] inbuf [0:23];

  // ── DFT result: 12 complex spread bins (sized to worst case) ────────────
  (* mem2reg *) reg signed [23:0] spread_re [0:11];
  (* mem2reg *) reg signed [23:0] spread_im [0:11];

  // ── Shared accumulator and pending output bytes ─────────────────────────
  reg signed [39:0] acc_re, acc_im;
  reg signed [7:0]  out_i_byte, out_q_byte;

  // ── Operand mux + CP/centered-map address generation (control logic) ─────
  // tau implements cyclic-prefix ordering: the last CP=9 IFFT samples are
  // emitted first (samp < CP), then the body samples 0..M-1.
  reg signed [23:0] a_re, a_im;   // operand A into the kernel
  reg        use_ifft;
  reg  [6:0] tau;                           // IFFT time index (CP-adjusted)
  reg  [6:0] w_idx;                         // ((START+j)*tau) mod 128

  always @(*) begin
    tau   = (samp < 9) ? (samp + 119) : (samp - 9);
    w_idx = (((58 + ifft_j) * tau) & 7'h7f);
    if (state == S_IFFT) begin
      a_re     = spread_re[ifft_j];
      a_im     = spread_im[ifft_j];
      use_ifft = 1'b1;
    end else begin   // S_DFT operands
      a_re     = inbuf[2*dft_n];
      a_im     = inbuf[2*dft_n + 1];
      use_ifft = 1'b0;
    end
  end

  // ── Locked bit-exact datapath ───────────────────────────────────────────
  wire signed [39:0] prod_re, prod_im;
  wire signed [7:0] byte_re, byte_im;
  wire signed [39:0] fin_re = acc_re + prod_re;   // full sum incl. final term
  wire signed [39:0] fin_im = acc_im + prod_im;

  butterfold_kernel u_kernel (
    .a_re(a_re), .a_im(a_im), .use_ifft(use_ifft),
    .dft_n(dft_n), .dft_j(dft_j), .w_idx(w_idx),
    .prod_re(prod_re), .prod_im(prod_im),
    .sum_re(fin_re), .sum_im(fin_im),
    .byte_re(byte_re), .byte_im(byte_im)
  );

  // ── Single sequential FSM (drives all state) ────────────────────────────
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      load_cnt   <= 5'd0;
      dft_j      <= 4'd0;
      dft_n      <= 4'd0;
      samp       <= 8'd0;
      ifft_j     <= 4'd0;
      emit_half  <= 1'b0;
      acc_re     <= 40'sd0;
      acc_im     <= 40'sd0;
      out_i_byte <= 8'sd0;
      out_q_byte <= 8'sd0;
      dout       <= 8'd0;
      dout_valid <= 1'b0;
      busy       <= 1'b0;
      done       <= 1'b0;
    end else begin
      done       <= 1'b0;
      dout_valid <= 1'b0;

      case (state)
        S_IDLE: begin
          busy <= 1'b0;
          if (din_valid) begin
            inbuf[0] <= din;
            load_cnt <= 5'd1;
            busy     <= 1'b1;
            state    <= S_LOAD;
          end
        end

        S_LOAD: begin
          busy <= 1'b1;
          inbuf[load_cnt] <= din;
          if (load_cnt == 5'd23) begin
            load_cnt <= 5'd0;
            dft_j    <= 4'd0;
            dft_n    <= 4'd0;
            acc_re   <= 40'sd0;
            acc_im   <= 40'sd0;
            state    <= S_DFT;
          end else begin
            load_cnt <= load_cnt + 5'd1;
          end
        end

        // 12-point DFT: spread[j] = sum_n symbol[n] * W12[(n*j) mod 12]
        S_DFT: begin
          busy <= 1'b1;
          if (dft_n == 4'd11) begin
            spread_re[dft_j] <= fin_re[23:0];   // last term + store
            spread_im[dft_j] <= fin_im[23:0];
            acc_re <= 40'sd0;
            acc_im <= 40'sd0;
            dft_n  <= 4'd0;
            if (dft_j == 4'd11) begin
              dft_j  <= 4'd0;
              samp   <= 8'd0;
              ifft_j <= 4'd0;
              state  <= S_IFFT;
            end else begin
              dft_j <= dft_j + 4'd1;
            end
          end else begin
            acc_re <= acc_re + prod_re;
            acc_im <= acc_im + prod_im;
            dft_n  <= dft_n + 4'd1;
          end
        end

        // IFFT (centered map + CP): time[samp] = sum_j spread[j] * W128[(START+j)*tau]
        S_IFFT: begin
          busy <= 1'b1;
          if (ifft_j == 4'd11) begin
            out_i_byte <= byte_re;             // round/saturate the full sum
            out_q_byte <= byte_im;
            acc_re     <= 40'sd0;
            acc_im     <= 40'sd0;
            ifft_j     <= 4'd0;
            emit_half  <= 1'b0;
            state      <= S_EMIT;
          end else begin
            acc_re <= acc_re + prod_re;
            acc_im <= acc_im + prod_im;
            ifft_j <= ifft_j + 4'd1;
          end
        end

        // Stream I then Q for the current sample
        S_EMIT: begin
          busy       <= 1'b1;
          dout_valid <= 1'b1;
          if (emit_half == 1'b0) begin
            dout      <= out_i_byte;
            emit_half <= 1'b1;
          end else begin
            dout      <= out_q_byte;
            emit_half <= 1'b0;
            if (samp == 136) begin         // 136 = last sample
              state <= S_IDLE;
              done  <= 1'b1;
            end else begin
              samp   <= samp + 8'd1;
              ifft_j <= 4'd0;
              state  <= S_IFFT;
            end
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
