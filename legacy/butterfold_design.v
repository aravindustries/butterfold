// Blackbox stub for the GF180 single-port synchronous SRAM macro
// gf180mcu_fd_ip_sram__sram128x8m8wm1 (128 words x 8 bits, bit-write mask).
// Ports per the PDK behavioral model. Marked (* blackbox *) so yosys keeps the
// instances (their area/timing come from the macro .lib during stat/STA).
// CEN  : chip enable, active LOW
// GWEN : global write enable, active LOW (0 = write, 1 = read)
// WEN  : per-bit write enable, active LOW
// A    : address ; D : data in ; Q : data out (1-cycle read latency)
`default_nettype none
(* blackbox *)
module gf180mcu_fd_ip_sram__sram128x8m8wm1 (
    input  wire       CLK,
    input  wire       CEN,
    input  wire       GWEN,
    input  wire [7:0] WEN,
    input  wire [6:0] A,
    input  wire [7:0] D,
    output wire [7:0] Q
);
endmodule
`default_nettype wire
// unified_mixed_radix_core - SRAM-MACRO variant.
//
// Same module interface as the register-file version (butterfold_module_io.md,
// UNIFIED MIXED-RADIX CORE), but the 128x16 complex scratch memory is a real
// GF180 single-port synchronous SRAM instead of a flip-flop register file:
//   4x gf180mcu_fd_ip_sram__sram128x8m8wm1  = re[15:8], re[7:0], im[15:8], im[7:0]
// All four macros share one address/control port (a 128 x 32b single-port RAM).
//
// Because the macro is single-port (one access/cycle) with 1-cycle read latency,
// a radix-2 butterfly is sequenced over 5 cycles:
//   IDLE: present src0(read) -> S1: capture op0, present src1(read)
//   S1  -> S2: capture op1
//   S2  -> S3: compute (twiddle multiply + add/sub + saturate), present dst0(write)
//   S3  -> S4: present dst1(write), assert uop_done
// External load and read requests borrow the same single port.
//
// This eliminates the async 128:1 read muxes and 3-write-port decoders that made
// the register-file version huge and un-timeable. PPA target only; not bit-exact.
`default_nettype none
module unified_mixed_radix_core (
    input  wire        rst_n,
    input  wire        clk,
    input  wire        uop_valid,
    output wire        uop_ready,
    input  wire [1:0]  uop_radix,
    input  wire        uop_inverse,
    input  wire [2:0]  uop_scale_shift,
    input  wire        uop_last,
    input  wire [6:0]  src_addr_0,
    input  wire [6:0]  src_addr_1,
    input  wire [6:0]  src_addr_2,
    input  wire [6:0]  dst_addr_0,
    input  wire [6:0]  dst_addr_1,
    input  wire [6:0]  dst_addr_2,
    input  wire [7:0]  twiddle_re,
    input  wire [7:0]  twiddle_im,
    input  wire        twiddle_valid,
    input  wire [6:0]  load_addr,
    input  wire [15:0] load_data,
    input  wire        load_valid,
    output wire        load_ready,
    input  wire [6:0]  read_addr,
    input  wire        read_req,
    output wire [15:0] read_data,
    output wire        read_valid,
    output wire        uop_done,
    output wire        overflow,
    output wire        saturation_occurred
);
    // ---------------- FSM ----------------
    localparam [2:0] IDLE=3'd0, S1=3'd1, S2=3'd2, S3=3'd3, S4=3'd4, RDX=3'd5;
    reg  [2:0] state;

    // captured operands
    reg signed [15:0] topr, topi, botr, boti;
    reg               uop_done_r, read_valid_r, sat_r;

    assign uop_ready  = (state == IDLE);
    assign load_ready = (state == IDLE);
    assign uop_done   = uop_done_r;
    assign read_valid = read_valid_r;
    assign overflow   = 1'b0;
    assign saturation_occurred = sat_r;

    // ---------------- arithmetic ----------------
    function signed [15:0] sat16(input signed [31:0] x);
        begin
            if      (x >  32767) sat16 =  16'sd32767;
            else if (x < -32768) sat16 = -16'sd32768;
            else                 sat16 =  x[15:0];
        end
    endfunction
    function signed [7:0] narrow(input signed [15:0] v);
        reg signed [31:0] r;
        begin
            r = (v + 8) >>> 4;
            if      (r >  127) narrow =  8'sd127;
            else if (r < -128) narrow = -8'sd128;
            else               narrow =  r[7:0];
        end
    endfunction

    // radix-2 butterfly with shared complex multiplier (kept for real datapath)
    wire signed [31:0] tr = ($signed(botr)*$signed(twiddle_re)
                           - $signed(boti)*$signed(twiddle_im) + 64) >>> 7;
    wire signed [31:0] ti = ($signed(botr)*$signed(twiddle_im)
                           + $signed(boti)*$signed(twiddle_re) + 64) >>> 7;
    wire signed [15:0] res0_re = sat16($signed(topr) + tr);
    wire signed [15:0] res0_im = sat16($signed(topi) + ti);
    wire signed [15:0] res1_re = sat16($signed(topr) - tr);
    wire signed [15:0] res1_im = sat16($signed(topi) - ti);

    // ---------------- single memory port (shared by 4 macros) ----------------
    reg  [6:0]  mem_a;
    reg         mem_we;
    reg  [15:0] re_d, im_d;
    wire [7:0]  re_q_hi, re_q_lo, im_q_hi, im_q_lo;
    wire [15:0] re_q = {re_q_hi, re_q_lo};
    wire [15:0] im_q = {im_q_hi, im_q_lo};
    wire        gwen = ~mem_we;
    wire [7:0]  wen  = mem_we ? 8'h00 : 8'hFF;

    assign read_data = {narrow($signed(re_q)), narrow($signed(im_q))};

    // combinational drive of the shared port
    always @* begin
        mem_a  = 7'd0;
        mem_we = 1'b0;
        re_d   = 16'd0;
        im_d   = 16'd0;
        case (state)
            IDLE: begin
                if (uop_valid) begin
                    mem_a = src_addr_0;                      // read op0
                end else if (load_valid) begin
                    mem_a  = load_addr;                      // external load = write
                    mem_we = 1'b1;
                    re_d   = $signed(load_data[15:8]) <<< 4;
                    im_d   = $signed(load_data[7:0])  <<< 4;
                end else if (read_req) begin
                    mem_a = read_addr;                       // external read
                end
            end
            S1: mem_a = src_addr_1;                          // read op1
            S3: begin mem_a = dst_addr_0; mem_we = 1'b1; re_d = res0_re; im_d = res0_im; end
            S4: begin mem_a = dst_addr_1; mem_we = 1'b1; re_d = res1_re; im_d = res1_im; end
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; topr <= 0; topi <= 0; botr <= 0; boti <= 0;
            uop_done_r <= 1'b0; read_valid_r <= 1'b0; sat_r <= 1'b0;
        end else begin
            uop_done_r   <= 1'b0;
            read_valid_r <= 1'b0;
            case (state)
                IDLE: begin
                    if      (uop_valid)  state <= S1;
                    else if (load_valid) state <= IDLE;      // single-cycle write
                    else if (read_req)   state <= RDX;
                end
                S1: begin topr <= $signed(re_q); topi <= $signed(im_q); state <= S2; end
                S2: begin botr <= $signed(re_q); boti <= $signed(im_q); state <= S3; end
                S3: begin
                    if (res0_re == 16'sd32767 || res0_re == -16'sd32768) sat_r <= 1'b1;
                    state <= S4;
                end
                S4: begin uop_done_r <= 1'b1; state <= IDLE; end
                RDX: begin read_valid_r <= 1'b1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end

    // ---------------- 4x GF180 single-port SRAM macros ----------------
    gf180mcu_fd_ip_sram__sram128x8m8wm1 u_mre_hi (
        .CLK(clk), .CEN(1'b0), .GWEN(gwen), .WEN(wen), .A(mem_a), .D(re_d[15:8]), .Q(re_q_hi));
    gf180mcu_fd_ip_sram__sram128x8m8wm1 u_mre_lo (
        .CLK(clk), .CEN(1'b0), .GWEN(gwen), .WEN(wen), .A(mem_a), .D(re_d[7:0]),  .Q(re_q_lo));
    gf180mcu_fd_ip_sram__sram128x8m8wm1 u_mim_hi (
        .CLK(clk), .CEN(1'b0), .GWEN(gwen), .WEN(wen), .A(mem_a), .D(im_d[15:8]), .Q(im_q_hi));
    gf180mcu_fd_ip_sram__sram128x8m8wm1 u_mim_lo (
        .CLK(clk), .CEN(1'b0), .GWEN(gwen), .WEN(wen), .A(mem_a), .D(im_d[7:0]),  .Q(im_q_lo));

endmodule
`default_nettype wire

`default_nettype none
module fdiq_io_adapter (
    input  wire rst_n,
    input  wire clk,
    input  wire [7:0] fdiq_in_data,
    input  wire fdiq_in_valid,
    output reg fdiq_in_ready,
    output reg [7:0] fdiq_out_data,
    output reg fdiq_out_valid,
    input  wire fdiq_out_ready,
    output reg [15:0] fd_in_data,
    output reg fd_in_valid,
    input  wire fd_in_ready,
    output reg fd_in_last,
    input  wire [15:0] fd_out_data,
    input  wire fd_out_valid,
    output reg fd_out_ready,
    input  wire fd_out_last,
    input  wire start,
    input  wire direction,
    output reg busy,
    output reg done,
    output reg iq_alignment_error
);

    // Internal states for FSM
    reg [3:0] sample_count;
    reg [7:0] I_byte;
    reg expect_I;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fdiq_in_ready <= 1'b0;
            fdiq_out_data <= 8'b0;
            fdiq_out_valid <= 1'b0;
            fd_in_data <= 16'b0;
            fd_in_valid <= 1'b0;
            fd_in_last <= 1'b0;
            fd_out_ready <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            iq_alignment_error <= 1'b0;
            sample_count <= 4'b0;
            I_byte <= 8'b0;
            expect_I <= 1'b1;
        end else begin
            // Default outputs
            fd_in_valid <= 1'b0;
            fd_in_last <= 1'b0;
            fdiq_out_valid <= 1'b0;
            done <= 1'b0;
            iq_alignment_error <= 1'b0;

            if (start && direction) begin
                busy <= 1'b1;
                sample_count <= 4'b0;
                expect_I <= 1'b1;
                fdiq_in_ready <= 1'b1;
            end

            if (busy) begin
                fdiq_in_ready <= 1'b1;
                if (fdiq_in_valid && fdiq_in_ready) begin
                    if (expect_I) begin
                        I_byte <= fdiq_in_data;
                        expect_I <= 1'b0;
                    end else begin
                        fd_in_data <= {I_byte, fdiq_in_data};
                        fd_in_valid <= 1'b1;
                        sample_count <= sample_count + 1;
                        expect_I <= 1'b1;
                        if (sample_count == 4'b1011) begin
                            fd_in_last <= 1'b1;
                            busy <= 1'b0;
                            done <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
`default_nettype wire
# rtl/ — the six ButterFold modules + structural top

RTL for the modular DFT-s-OFDM chip, authored from `../butterfold_module_io.md`.

| file | role |
|---|---|
| `scheduler_addr_control.v` | control brain — sequences DFT-12 / FFT-128 / IFFT-128; addresses, CP, mapping |
| `unified_mixed_radix_core.v` | 128×16 complex scratch memory (flip-flop **register file**) + shared complex multiplier + radix-2 butterfly |
| `twiddle_source.v` | quantized Q1.7 twiddle ROM (+ conjugate for inverse) |
| `subcarrier_map_extract.v` | TX map / RX extract — bins 58..69 of the 128-bin grid |
| `fdiq_io_adapter.v` | frequency-domain I/Q byte ↔ 16-bit complex packing |
| `tdiq_io_adapter_cp.v` | time-domain I/Q packing + CP insert/remove |
| `butterfold_top.v` | **structural** top — instantiates all six and wires them to the chip interface |

`butterfold_top.v` here uses the flip-flop **register-file** scratch memory. An
**SRAM-macro** variant of the core (4× GF180 `sram128x8`) lives in `../rtl_sram/`
and is dropped in by swapping only `unified_mixed_radix_core.v`.

For area / timing / power of both, see `../REPORT.md` and run
`../scripts/ppa_regfile.sh` / `../scripts/ppa_sram.sh` inside the container.
`default_nettype none
module scheduler_addr_control (
    input  wire rst_n,
    input  wire clk,
    input  wire cmd_valid,
    output reg  cmd_ready,
    input  wire [2:0] cmd_op,
    input  wire long_cp,
    output reg  uop_valid,
    input  wire uop_ready,
    output reg [1:0] uop_radix,
    output reg  uop_inverse,
    output reg [2:0] uop_scale_shift,
    output reg  uop_last,
    output reg [6:0] src_addr_0,
    output reg [6:0] src_addr_1,
    output reg [6:0] src_addr_2,
    output reg [6:0] dst_addr_0,
    output reg [6:0] dst_addr_1,
    output reg [6:0] dst_addr_2,
    output wire tw_req,
    output reg [6:0] tw_addr,
    output reg tw_conjugate,
    input  wire tw_valid,
    output wire map_start,
    output wire map_direction,
    output wire [6:0] first_subcarrier,
    input  wire map_done,
    output wire cp_start,
    output wire cp_insert,
    output wire [3:0] cp_len,
    input  wire cp_done,
    output wire input_bank_select,
    output wire output_bank_select,
    output wire busy,
    output wire done,
    output wire error,
    output reg [15:0] cycle_count
);

    reg [2:0] stage;
    reg [6:0] grp;
    reg [6:0] kk;
    reg [8:0] cnt;
    reg active;

    wire [6:0] half = 7'd1 << stage;
    wire [7:0] m = 8'd1 << (stage + 1);

    assign first_subcarrier = 7'd58;
    assign cp_len = 4'd9;
    assign map_start = 1'b0;
    assign map_direction = 1'b0;
    assign cp_start = 1'b0;
    assign cp_insert = 1'b0;
    assign input_bank_select = 1'b0;
    assign output_bank_select = 1'b0;
    assign busy = active;
    assign done = (cnt == 9'd447);
    assign error = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage <= 3'd0;
            grp <= 7'd0;
            kk <= 7'd0;
            cnt <= 9'd0;
            active <= 1'b0;
            cmd_ready <= 1'b1;
        end else begin
            if (cmd_valid && cmd_ready && cmd_op == 3'b010) begin
                active <= 1'b1;
                cmd_ready <= 1'b0;
            end

            if (active && uop_ready) begin
                if (kk == half - 1) begin
                    kk <= 7'd0;
                    if (grp + m >= 128) begin
                        grp <= 7'd0;
                        if (stage == 3'd6) begin
                            active <= 1'b0;
                            stage <= 3'd0;
                        end else begin
                            stage <= stage + 1;
                        end
                    end else begin
                        grp <= grp + m;
                    end
                end else begin
                    kk <= kk + 1;
                end

                cnt <= cnt + 1;
            end
        end
    end

    always @(*) begin
        uop_valid = active;
        src_addr_0 = grp + kk;
        src_addr_1 = grp + half + kk;
        dst_addr_0 = grp + kk;
        dst_addr_1 = grp + half + kk;
        tw_addr = kk << (6 - stage);
        uop_inverse = 1'b1;
        uop_radix = 2'b10;
        uop_scale_shift = 3'b001;
        uop_last = (cnt == 9'd447);
        tw_conjugate = 1'b1;
    end

endmodule
`default_nettype wire
module subcarrier_map_extract (
    input wire rst_n,
    input wire clk,
    input wire start,
    input wire map_not_extract,
    input wire [6:0] first_subcarrier,
    output reg busy,
    output reg done,
    output reg config_error,
    input wire [15:0] in_data,
    input wire in_valid,
    output reg in_ready,
    input wire in_last,
    output reg [15:0] out_data,
    output reg out_valid,
    input wire out_ready,
    output reg out_last,
    output reg [6:0] mem_addr,
    output reg mem_write,
    output reg [15:0] mem_wdata,
    input wire [15:0] mem_rdata,
    input wire mem_rvalid
);

    // Internal reg definitions
    reg [3:0] state; // state machine
    reg [3:0] load_counter; // counter for loading samples
    reg [6:0] emit_counter; // counter for emitting data
    reg [15:0] buffer[11:0]; // buffer for the subcarrier samples

    localparam IDLE = 0,
               LOAD = 1,
               EMIT = 2,
               DONE = 3;

    // Tie memory interface to zero for mapping mode
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr <= 7'b0;
            mem_write <= 1'b0;
            mem_wdata <= 16'b0;
        end else begin
            mem_addr <= 7'b0;
            mem_write <= 1'b0;
            mem_wdata <= 16'b0;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_counter <= 4'b0;
            emit_counter <= 7'b0;
            busy <= 1'b0;
            done <= 1'b0;
            config_error <= 1'b0;
            in_ready <= 1'b0;
            out_data <= 16'b0;
            out_valid <= 1'b0;
            out_last <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    config_error <= 1'b0;
                    if (start) begin
                        if (map_not_extract) begin
                            // Check configuration
                            if (first_subcarrier + 12 <= 128) begin
                                state <= LOAD;
                                busy <= 1'b1;
                            end else begin
                                config_error <= 1'b1;
                                state <= DONE;
                            end
                        end
                    end
                end
                LOAD: begin
                    in_ready <= 1'b1;
                    if (in_valid && in_ready) begin
                        buffer[load_counter] <= in_data;
                        load_counter <= load_counter + 1;
                        if (load_counter == 11 || in_last) begin
                            state <= EMIT;
                            in_ready <= 1'b0;
                        end
                    end
                end
                EMIT: begin
                    out_valid <= 1'b1;
                    out_data <= 16'b0;
                    if (emit_counter >= first_subcarrier &&
                        emit_counter < first_subcarrier + 12) begin
                        out_data <= buffer[emit_counter - first_subcarrier];
                    end
                    emit_counter <= emit_counter + 1;
                    if (emit_counter == 127) begin
                        out_last <= 1'b1;
                        state <= DONE;
                    end else begin
                        out_last <= 1'b0;
                    end
                end
                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule// tdiq_io_adapter_cp - ports from butterfold_module_io.md (TDIQ I/O ADAPTER WITH CP)
// Synchronous FSM for RX CP-removal path
`default_nettype none
module tdiq_io_adapter_cp (
    input  wire rst_n,
    input  wire clk,
    input  wire [7:0] tdiq_in_data,
    input  wire tdiq_in_valid,
    output wire tdiq_in_ready,
    output wire [7:0] tdiq_out_data,
    output wire tdiq_out_valid,
    input  wire tdiq_out_ready,
    input  wire cp_start,
    input  wire cp_insert,
    input  wire [3:0] cp_len,
    output wire [15:0] rx_symbol_data,
    output wire rx_symbol_valid,
    input  wire rx_symbol_ready,
    output wire rx_symbol_last,
    output wire [6:0] tx_symbol_rd_addr,
    output wire tx_symbol_rd_req,
    input  wire [15:0] tx_symbol_rd_data,
    input  wire tx_symbol_rd_valid,
    output wire busy,
    output wire done,
    output wire cp_error,
    output wire sample_count_error,
    output wire iq_alignment_error
);

    reg [7:0] scount;
    reg active;
    reg have_i;
    reg [7:0] i_data;
    reg [15:0] internal_rx_symbol_data;
    reg internal_rx_symbol_valid;
    reg internal_rx_symbol_last;
    reg internal_busy;
    reg internal_done;

    assign tdiq_in_ready = active;
    assign tdiq_out_data = 8'b0;
    assign tdiq_out_valid = 1'b0;
    assign rx_symbol_data = internal_rx_symbol_data;
    assign rx_symbol_valid = internal_rx_symbol_valid;
    assign rx_symbol_last = internal_rx_symbol_last;
    assign tx_symbol_rd_addr = 7'b0;
    assign tx_symbol_rd_req = 1'b0;
    assign busy = internal_busy;
    assign done = internal_done;
    assign cp_error = 1'b0;
    assign sample_count_error = 1'b0;
    assign iq_alignment_error = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scount <= 8'b0;
            active <= 1'b0;
            have_i <= 1'b0;
            i_data <= 8'b0;
            internal_rx_symbol_data <= 16'b0;
            internal_rx_symbol_valid <= 1'b0;
            internal_rx_symbol_last <= 1'b0;
            internal_busy <= 1'b0;
            internal_done <= 1'b0;
        end else begin
            internal_rx_symbol_valid <= 1'b0;
            internal_rx_symbol_last <= 1'b0;
            internal_done <= 1'b0;

            if (cp_start && !cp_insert && !active) begin
                active <= 1'b1;
                internal_busy <= 1'b1;
                scount <= 8'b0;
            end else if (active && tdiq_in_valid && tdiq_in_ready) begin
                if (!have_i) begin
                    i_data <= tdiq_in_data;
                    have_i <= 1'b1;
                end else begin
                    if (scount >= cp_len) begin
                        internal_rx_symbol_data <= {i_data, tdiq_in_data};
                        internal_rx_symbol_valid <= 1'b1;
                        if (scount == 136) begin
                            internal_rx_symbol_last <= 1'b1;
                            internal_done <= 1'b1;
                            active <= 1'b0;
                            internal_busy <= 1'b0;
                        end
                    end
                    scount <= scount + 1;
                    have_i <= 1'b0;
                end
            end
        end
    end

endmodule
`default_nettype wire
`default_nettype none
module twiddle_source (
    input  wire rst_n,
    input  wire clk,
    input  wire tw_req,
    input  wire [6:0] tw_addr,
    input  wire tw_conjugate,
    output reg [7:0] tw_re,
    output reg [7:0] tw_im,
    output reg tw_valid
);

    reg signed [7:0] base_re, base_im;

    // Combinational logic to set base values for twiddle factors
    always @* begin
        case (tw_addr)
            7'd0:  {base_re, base_im} = 16'sb01111111_00000000; // 127, 0
            7'd1:  {base_re, base_im} = 16'sb01101110_11000001; // 110, -63
            7'd2:  {base_re, base_im} = 16'sb01000000_10010010; // 64, -110
            7'd3:  {base_re, base_im} = 16'sb00000000_10000001; // 0, -127
            7'd4:  {base_re, base_im} = 16'sb11000001_10010010; // -63, -110
            7'd5:  {base_re, base_im} = 16'sb10010010_11000000; // -110, -64
            7'd6:  {base_re, base_im} = 16'sb10000001_00000000; // -127, 0
            7'd7:  {base_re, base_im} = 16'sb10010010_00111111; // -110, 63
            7'd8:  {base_re, base_im} = 16'sb11000000_01101110; // -64, 110
            7'd9:  {base_re, base_im} = 16'sb00000000_01111111; // 0, 127
            7'd10: {base_re, base_im} = 16'sb00111111_01101110; // 63, 110
            7'd11: {base_re, base_im} = 16'sb01101110_01000000; // 110, 64
            default: {base_re, base_im} = 16'sb00000000_00000000; // 0, 0
        endcase
    end

    // Sequential logic with clock and reset handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tw_re <= 8'b0;
            tw_im <= 8'b0;
            tw_valid <= 1'b0;
        end else begin
            tw_re <= base_re;
            tw_im <= tw_conjugate ? (~base_im + 8'd1) : base_im;
            tw_valid <= tw_req;
        end
    end

endmodule

`default_nettype wire
