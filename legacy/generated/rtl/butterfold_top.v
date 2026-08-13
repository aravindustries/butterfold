// butterfold_top.v — STRUCTURAL integration of the six ButterFold modules
// defined in butterfold_module_io.md:
//   fdiq_io_adapter, unified_mixed_radix_core, twiddle_source,
//   scheduler_addr_control, subcarrier_map_extract, tdiq_io_adapter_cp.
//
// This replaces the earlier monolithic single-memory "golden" top. It is the
// synthesis / PPA target: every block is a real instance wired into the
// datapath the spec describes — scheduler drives the core and twiddle source,
// subcarrier map/extract sits on the frequency side, the TDIQ+CP adapter on the
// time side, and the FDIQ adapter on the frequency-domain I/O side.
//
// Bit-exact golden-EVM closure is intentionally OUT OF SCOPE here; the purpose
// of this top is a faithful area / timing / power / schematic estimate of the
// modular chip. The top-level glue (command capture + memory address pointers +
// stream muxes) is deliberately thin.
`default_nettype none
module butterfold_top (
    input  wire       clk_i,
    input  wire       rst_ni,
    input  wire [7:0] din,
    input  wire       din_valid_i,
    output wire       din_ready_o,
    output wire [7:0] dout,
    output wire       dout_valid_o,
    input  wire       dout_ready_i,
    output reg        done_irq_o,
    input  wire       scan_en_i,
    input  wire       scan_in_i,
    output wire       scan_out_o
);
    wire clk   = clk_i;
    wire rst_n = rst_ni;

    // ------------------------------------------------------------------
    // Command capture: the first accepted din byte is the command opcode
    // (low 3 bits match the scheduler cmd_op encoding). 0x03 = TX, 0x04 = RX.
    // ------------------------------------------------------------------
    reg  [2:0] cmd_op_r;
    reg        cmd_seen;
    reg        cmd_pulse;
    wire       is_tx = cmd_seen & (cmd_op_r == 3'b011);   // TX chain
    wire       is_rx = cmd_seen & (cmd_op_r == 3'b100);   // RX chain

    // ------------------------------------------------------------------
    // Inter-module nets
    // ------------------------------------------------------------------
    // scheduler outputs
    wire        sch_cmd_ready;
    wire        sch_uop_valid, sch_uop_inverse, sch_uop_last;
    wire [1:0]  sch_uop_radix;
    wire [2:0]  sch_uop_scale_shift;
    wire [6:0]  sch_src0, sch_src1, sch_src2, sch_dst0, sch_dst1, sch_dst2;
    wire        sch_tw_req, sch_tw_conjugate;
    wire [6:0]  sch_tw_addr;
    wire        sch_map_start, sch_map_direction;
    wire [6:0]  sch_first_subcarrier;
    wire        sch_cp_start, sch_cp_insert;
    wire [3:0]  sch_cp_len;
    wire        sch_input_bank, sch_output_bank;
    wire        sch_busy, sch_done, sch_error;
    wire [15:0] sch_cycle_count;

    // core outputs
    wire        core_uop_ready, core_load_ready, core_read_valid;
    wire [15:0] core_read_data;
    wire        core_uop_done, core_overflow, core_sat;

    // twiddle-source outputs
    wire [7:0]  tw_re, tw_im;
    wire        tw_valid;

    // fdiq outputs
    wire        fdiq_in_ready, fdiq_out_valid;
    wire [7:0]  fdiq_out_data;
    wire [15:0] fdiq_fd_in_data;
    wire        fdiq_fd_in_valid, fdiq_fd_in_last, fdiq_fd_out_ready;
    wire        fdiq_busy, fdiq_done, fdiq_iq_err;

    // subcarrier map/extract outputs
    wire        map_busy, map_done, map_config_error, map_in_ready;
    wire [15:0] map_out_data, map_mem_wdata;
    wire        map_out_valid, map_out_last, map_mem_write;
    wire [6:0]  map_mem_addr;

    // tdiq outputs
    wire        tdiq_in_ready, tdiq_out_valid;
    wire [7:0]  tdiq_out_data;
    wire [15:0] tdiq_rx_symbol_data;
    wire        tdiq_rx_symbol_valid, tdiq_rx_symbol_last;
    wire [6:0]  tdiq_tx_rd_addr;
    wire        tdiq_tx_rd_req;
    wire        tdiq_busy, tdiq_done, tdiq_cp_error, tdiq_sc_error, tdiq_iq_err;

    // ------------------------------------------------------------------
    // Top-level glue: scratch-memory load / read address pointers. The stream
    // adapters supply data; the top supplies the sequential address.
    // ------------------------------------------------------------------
    reg  [6:0] load_ptr, read_ptr;

    wire        core_load_valid = is_tx ? fdiq_fd_in_valid
                                : is_rx ? tdiq_rx_symbol_valid : 1'b0;
    wire [15:0] core_load_data  = is_tx ? fdiq_fd_in_data : tdiq_rx_symbol_data;
    wire        rx_emit_req      = is_rx & sch_busy;
    wire        core_read_req    = is_tx ? tdiq_tx_rd_req  : rx_emit_req;
    wire [6:0]  core_read_addr   = is_tx ? tdiq_tx_rd_addr : read_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_op_r   <= 3'd0;
            cmd_seen   <= 1'b0;
            cmd_pulse  <= 1'b0;
            load_ptr   <= 7'd0;
            read_ptr   <= 7'd0;
            done_irq_o <= 1'b0;
        end else begin
            cmd_pulse  <= 1'b0;
            done_irq_o <= sch_done;
            if (din_valid_i && din_ready_o && !cmd_seen) begin
                cmd_op_r  <= din[2:0];
                cmd_seen  <= 1'b1;
                cmd_pulse <= 1'b1;
            end
            if (sch_done) cmd_seen <= 1'b0;                 // ready for next command
            if (core_load_valid && core_load_ready) load_ptr <= load_ptr + 7'd1;
            if (core_read_req)                       read_ptr <= read_ptr + 7'd1;
        end
    end

    // ------------------------------------------------------------------
    // External byte-stream muxes (command first, then TX via FDIQ-in / TDIQ-out,
    // RX via TDIQ-in / FDIQ-out).
    // ------------------------------------------------------------------
    assign din_ready_o  = !cmd_seen ? 1'b1
                        : is_tx     ? fdiq_in_ready
                        : is_rx     ? tdiq_in_ready
                        :             1'b0;
    assign dout         = is_rx ? fdiq_out_data  : tdiq_out_data;
    assign dout_valid_o = is_rx ? fdiq_out_valid : tdiq_out_valid;

    // ------------------------------------------------------------------
    // Module instances
    // ------------------------------------------------------------------
    scheduler_addr_control u_sch (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(cmd_pulse), .cmd_ready(sch_cmd_ready), .cmd_op(cmd_op_r), .long_cp(1'b0),
        .uop_valid(sch_uop_valid), .uop_ready(core_uop_ready),
        .uop_radix(sch_uop_radix), .uop_inverse(sch_uop_inverse),
        .uop_scale_shift(sch_uop_scale_shift), .uop_last(sch_uop_last),
        .src_addr_0(sch_src0), .src_addr_1(sch_src1), .src_addr_2(sch_src2),
        .dst_addr_0(sch_dst0), .dst_addr_1(sch_dst1), .dst_addr_2(sch_dst2),
        .tw_req(sch_tw_req), .tw_addr(sch_tw_addr), .tw_conjugate(sch_tw_conjugate),
        .tw_valid(tw_valid),
        .map_start(sch_map_start), .map_direction(sch_map_direction),
        .first_subcarrier(sch_first_subcarrier), .map_done(map_done),
        .cp_start(sch_cp_start), .cp_insert(sch_cp_insert), .cp_len(sch_cp_len),
        .cp_done(tdiq_done),
        .input_bank_select(sch_input_bank), .output_bank_select(sch_output_bank),
        .busy(sch_busy), .done(sch_done), .error(sch_error), .cycle_count(sch_cycle_count)
    );

    unified_mixed_radix_core u_core (
        .clk(clk), .rst_n(rst_n),
        .uop_valid(sch_uop_valid), .uop_ready(core_uop_ready),
        .uop_radix(sch_uop_radix), .uop_inverse(sch_uop_inverse),
        .uop_scale_shift(sch_uop_scale_shift), .uop_last(sch_uop_last),
        .src_addr_0(sch_src0), .src_addr_1(sch_src1), .src_addr_2(sch_src2),
        .dst_addr_0(sch_dst0), .dst_addr_1(sch_dst1), .dst_addr_2(sch_dst2),
        .twiddle_re(tw_re), .twiddle_im(tw_im), .twiddle_valid(tw_valid),
        .load_addr(load_ptr), .load_data(core_load_data), .load_valid(core_load_valid),
        .load_ready(core_load_ready),
        .read_addr(core_read_addr), .read_req(core_read_req),
        .read_data(core_read_data), .read_valid(core_read_valid),
        .uop_done(core_uop_done), .overflow(core_overflow),
        .saturation_occurred(core_sat)
    );

    twiddle_source u_tw (
        .clk(clk), .rst_n(rst_n),
        .tw_req(sch_tw_req), .tw_addr(sch_tw_addr), .tw_conjugate(sch_tw_conjugate),
        .tw_re(tw_re), .tw_im(tw_im), .tw_valid(tw_valid)
    );

    fdiq_io_adapter u_fdiq (
        .clk(clk), .rst_n(rst_n),
        .fdiq_in_data(din), .fdiq_in_valid(din_valid_i & is_tx & cmd_seen),
        .fdiq_in_ready(fdiq_in_ready),
        .fdiq_out_data(fdiq_out_data), .fdiq_out_valid(fdiq_out_valid),
        .fdiq_out_ready(dout_ready_i & is_rx),
        .fd_in_data(fdiq_fd_in_data), .fd_in_valid(fdiq_fd_in_valid),
        .fd_in_ready(is_tx ? core_load_ready : 1'b0), .fd_in_last(fdiq_fd_in_last),
        .fd_out_data(map_out_data), .fd_out_valid(map_out_valid),
        .fd_out_ready(fdiq_fd_out_ready), .fd_out_last(map_out_last),
        .start(cmd_pulse), .direction(is_tx),
        .busy(fdiq_busy), .done(fdiq_done), .iq_alignment_error(fdiq_iq_err)
    );

    subcarrier_map_extract u_map (
        .clk(clk), .rst_n(rst_n),
        .start(sch_map_start), .map_not_extract(sch_map_direction),
        .first_subcarrier(sch_first_subcarrier),
        .busy(map_busy), .done(map_done), .config_error(map_config_error),
        .in_data(core_read_data), .in_valid(core_read_valid),
        .in_ready(map_in_ready), .in_last(read_ptr == 7'd11),
        .out_data(map_out_data), .out_valid(map_out_valid),
        .out_ready(fdiq_fd_out_ready), .out_last(map_out_last),
        .mem_addr(map_mem_addr), .mem_write(map_mem_write), .mem_wdata(map_mem_wdata),
        .mem_rdata(core_read_data), .mem_rvalid(core_read_valid)
    );

    tdiq_io_adapter_cp u_tdiq (
        .clk(clk), .rst_n(rst_n),
        .tdiq_in_data(din), .tdiq_in_valid(din_valid_i & is_rx & cmd_seen),
        .tdiq_in_ready(tdiq_in_ready),
        .tdiq_out_data(tdiq_out_data), .tdiq_out_valid(tdiq_out_valid),
        .tdiq_out_ready(dout_ready_i & is_tx),
        .cp_start(sch_cp_start), .cp_insert(sch_cp_insert), .cp_len(sch_cp_len),
        .rx_symbol_data(tdiq_rx_symbol_data), .rx_symbol_valid(tdiq_rx_symbol_valid),
        .rx_symbol_ready(is_rx ? core_load_ready : 1'b0),
        .rx_symbol_last(tdiq_rx_symbol_last),
        .tx_symbol_rd_addr(tdiq_tx_rd_addr), .tx_symbol_rd_req(tdiq_tx_rd_req),
        .tx_symbol_rd_data(core_read_data), .tx_symbol_rd_valid(core_read_valid),
        .busy(tdiq_busy), .done(tdiq_done), .cp_error(tdiq_cp_error),
        .sample_count_error(tdiq_sc_error), .iq_alignment_error(tdiq_iq_err)
    );

    // ------------------------------------------------------------------
    // Observability tie-off: fold every status/flag output that has no
    // dedicated chip pin into a sticky aggregate, so synthesis retains the
    // flag logic for a faithful PPA estimate. Exposed on the (otherwise
    // placeholder) scan pin.
    // ------------------------------------------------------------------
    wire status_bits = core_uop_done ^ core_overflow ^ core_sat
                     ^ sch_error ^ sch_busy ^ sch_input_bank ^ sch_output_bank
                     ^ (^sch_cycle_count) ^ sch_cmd_ready
                     ^ map_config_error ^ map_busy ^ map_in_ready
                     ^ (^map_mem_addr) ^ map_mem_write ^ (^map_mem_wdata)
                     ^ fdiq_busy ^ fdiq_done ^ fdiq_iq_err ^ fdiq_fd_in_last
                     ^ tdiq_busy ^ tdiq_cp_error ^ tdiq_sc_error ^ tdiq_iq_err
                     ^ tdiq_rx_symbol_last;
    reg status_sticky;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) status_sticky <= 1'b0;
        else        status_sticky <= status_sticky ^ status_bits;

    assign scan_out_o = scan_en_i ? status_sticky : scan_in_i;

endmodule
`default_nettype wire
