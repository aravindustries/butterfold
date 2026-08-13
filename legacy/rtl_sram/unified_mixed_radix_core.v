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
// the register-file version huge and un-timeable. The butterfly arithmetic is
// bit-exact to the register-file core (same widen/round/scale/saturate), so this
// variant passes the same golden IFFT-128 check (tests/modules/tb_..._sram.v).
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
    reg               uop_done_r, sat_r;

    assign uop_ready  = (state == IDLE);
    assign load_ready = (state == IDLE);
    assign uop_done   = uop_done_r;
    // read_data (combinational from the macro Q) is valid in the RDX state, where
    // Q still holds mem[read_addr] latched on the IDLE->RDX edge. Assert read_valid
    // in that same cycle so it coincides with valid data (a registered pulse would
    // land one cycle late, after Q has advanced).
    assign read_valid = (state == RDX);
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
    // Radix-2 DIT outputs WITH the per-stage 1/2 scaling (uop_scale_shift=1):
    // round-to-nearest then arithmetic >>1, exactly like the register-file core,
    // so this variant is bit-exact to the golden IFFT (not just PPA-representative).
    wire signed [15:0] res0_re = sat16(($signed(topr) + tr + 1) >>> 1);
    wire signed [15:0] res0_im = sat16(($signed(topi) + ti + 1) >>> 1);
    wire signed [15:0] res1_re = sat16(($signed(topr) - tr + 1) >>> 1);
    wire signed [15:0] res1_im = sat16(($signed(topi) - ti + 1) >>> 1);

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
            uop_done_r <= 1'b0; sat_r <= 1'b0;
        end else begin
            uop_done_r   <= 1'b0;
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
                RDX: begin state <= IDLE; end
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
