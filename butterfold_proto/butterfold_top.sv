`timescale 1ns/1ps
`default_nettype none

//==============================================================================
// ButterFold final-pin top level with GF180 SRAM-aware buffering.
//
// FINAL DIGITAL PORT LIST IS IMMUTABLE.
//
// Large physical memories:
//   * Two shared 512x8 waveform SRAMs.
//       RX: ping-pong input symbol buffers.
//       TX: ping-pong output waveform buffers.
//     Half-duplex operation allows the exact same macros to serve both roles.
//   * The transform_scheduler_core contains four 128x8 macros in parallel for
//     its 128x32 FFT/IFFT scratch store.
//
// Small storage remains registers:
//   * two 24-byte TX input banks,
//   * two 24-byte extracted-RX output banks,
//   * standalone serializer state and queue metadata.
//==============================================================================
module butterfold_top #(
    parameter integer TRANSACTION_FIFO_DEPTH = 4,
    parameter integer TX_BYTE_INTERVAL = 1
) (
    input  logic       rst_n,
    input  logic       clk,
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,
    output logic [7:0] dout,
    output logic       dout_valid_o
);

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT128  = 8'h41;
    localparam logic [7:0] CMD_IFFT128 = 8'h42;
    localparam logic [7:0] CMD_IFFT2   = 8'h43;
    localparam logic [7:0] CMD_FFT3    = 8'h44;
    localparam logic [7:0] CMD_DFT12   = 8'h45;
    localparam logic [7:0] CMD_OFDM_RX_SHORT_NORMAL_CP = 8'h46;
    localparam logic [7:0] CMD_OFDM_RX_LONG_NORMAL_CP  = 8'h47;
    localparam logic [7:0] CMD_OFDM_TX_SHORT_NORMAL_CP = 8'h48;
    localparam logic [7:0] CMD_OFDM_TX_LONG_NORMAL_CP  = 8'h49;

    localparam integer RX_SELECTED_BYTES = 24;
    localparam integer TX_INPUT_BYTES = 24;

    function automatic logic is_ofdm_command(input logic [7:0] command);
        begin
            is_ofdm_command =
                (command == CMD_OFDM_RX_SHORT_NORMAL_CP) ||
                (command == CMD_OFDM_RX_LONG_NORMAL_CP)  ||
                (command == CMD_OFDM_TX_SHORT_NORMAL_CP) ||
                (command == CMD_OFDM_TX_LONG_NORMAL_CP);
        end
    endfunction

    function automatic logic is_rx_command(input logic [7:0] command);
        begin
            is_rx_command =
                (command == CMD_OFDM_RX_SHORT_NORMAL_CP) ||
                (command == CMD_OFDM_RX_LONG_NORMAL_CP);
        end
    endfunction

    function automatic logic is_tx_command(input logic [7:0] command);
        begin
            is_tx_command =
                (command == CMD_OFDM_TX_SHORT_NORMAL_CP) ||
                (command == CMD_OFDM_TX_LONG_NORMAL_CP);
        end
    endfunction

    function automatic [8:0] ofdm_input_byte_count(input logic [7:0] command);
        begin
            case (command)
                CMD_OFDM_RX_SHORT_NORMAL_CP: ofdm_input_byte_count = 9'd274;
                CMD_OFDM_RX_LONG_NORMAL_CP:  ofdm_input_byte_count = 9'd276;
                CMD_OFDM_TX_SHORT_NORMAL_CP,
                CMD_OFDM_TX_LONG_NORMAL_CP:  ofdm_input_byte_count = 9'd24;
                default:                     ofdm_input_byte_count = 9'd0;
            endcase
        end
    endfunction

    function automatic [8:0] tx_output_byte_count(input logic [7:0] command);
        begin
            tx_output_byte_count =
                (command == CMD_OFDM_TX_LONG_NORMAL_CP) ? 9'd276 : 9'd274;
        end
    endfunction

    function automatic [8:0] standalone_input_byte_count(input logic [7:0] command);
        begin
            case (command)
                CMD_FFT2, CMD_IFFT2: standalone_input_byte_count = 9'd4;
                CMD_FFT3:            standalone_input_byte_count = 9'd6;
                CMD_FFT128,
                CMD_IFFT128:         standalone_input_byte_count = 9'd256;
                CMD_DFT12:           standalone_input_byte_count = 9'd24;
                default:             standalone_input_byte_count = 9'd0;
            endcase
        end
    endfunction

    //==========================================================================
    // Transform core
    //==========================================================================
    logic signed [15:0] core_X0_i, core_X0_q, core_X1_i, core_X1_q;
    logic signed [15:0] core_X2_i, core_X2_q;
    logic [6:0] core_result_addr0, core_result_addr1, core_result_addr2;
    logic [1:0] core_result_radix;
    logic core_result_last, core_result_valid, core_result_ready;
    logic [7:0] core_din, core_dout;
    logic core_din_valid, core_din_ready, core_dout_valid;

    transform_scheduler_core #(
        .TRANSACTION_FIFO_DEPTH(TRANSACTION_FIFO_DEPTH)
    ) u_transform_scheduler_core (
        .clk(clk), .rst_n(rst_n),
        .din(core_din), .din_valid_i(core_din_valid), .din_ready_o(core_din_ready),
        .X0_i_o(core_X0_i), .X0_q_o(core_X0_q),
        .X1_i_o(core_X1_i), .X1_q_o(core_X1_q),
        .X2_i_o(core_X2_i), .X2_q_o(core_X2_q),
        .result_addr0_o(core_result_addr0),
        .result_addr1_o(core_result_addr1),
        .result_addr2_o(core_result_addr2),
        .result_radix_o(core_result_radix),
        .result_last_o(core_result_last),
        .result_valid_o(core_result_valid),
        .result_ready_i(core_result_ready),
        .dout(core_dout), .dout_valid_o(core_dout_valid)
    );

    //==========================================================================
    // Shared 512x8 waveform SRAMs
    //==========================================================================
    localparam logic [1:0] WAVE_FREE      = 2'd0;
    localparam logic [1:0] WAVE_RX_INPUT  = 2'd1;
    localparam logic [1:0] WAVE_TX_OUTPUT = 2'd2;

    logic [1:0] wave_owner [0:1];
    logic wave_free_valid, wave_free_bank;
    assign wave_free_valid = (wave_owner[0] == WAVE_FREE) || (wave_owner[1] == WAVE_FREE);
    assign wave_free_bank  = (wave_owner[0] == WAVE_FREE) ? 1'b0 : 1'b1;

    logic wave0_req, wave0_write;
    logic [8:0] wave0_addr;
    logic [7:0] wave0_wdata, wave0_rdata;
    logic wave0_rvalid;
    logic wave1_req, wave1_write;
    logic [8:0] wave1_addr;
    logic [7:0] wave1_wdata, wave1_rdata;
    logic wave1_rvalid;

    gf180_sram_512x8_wrapper u_wave_bank0 (
        .clk(clk), .rst_n(rst_n), .req_i(wave0_req), .write_i(wave0_write),
        .addr_i(wave0_addr), .wdata_i(wave0_wdata), .wmask_i(8'hff),
        .rdata_o(wave0_rdata), .rvalid_o(wave0_rvalid)
    );
    gf180_sram_512x8_wrapper u_wave_bank1 (
        .clk(clk), .rst_n(rst_n), .req_i(wave1_req), .write_i(wave1_write),
        .addr_i(wave1_addr), .wdata_i(wave1_wdata), .wmask_i(8'hff),
        .rdata_o(wave1_rdata), .rvalid_o(wave1_rvalid)
    );

    //==========================================================================
    // Small register ping-pong banks
    //==========================================================================
    logic [7:0] tx_input_bank0 [0:TX_INPUT_BYTES-1];
    logic [7:0] tx_input_bank1 [0:TX_INPUT_BYTES-1];
    logic tx_input_used [0:1];
    logic tx_input_free_valid, tx_input_free_bank;
    assign tx_input_free_valid = !tx_input_used[0] || !tx_input_used[1];
    assign tx_input_free_bank  = !tx_input_used[0] ? 1'b0 : 1'b1;

    logic [7:0] rx_output_bank0 [0:RX_SELECTED_BYTES-1];
    logic [7:0] rx_output_bank1 [0:RX_SELECTED_BYTES-1];
    logic rx_output_used [0:1];
    logic rx_output_free_valid, rx_output_free_bank;
    assign rx_output_free_valid = !rx_output_used[0] || !rx_output_used[1];
    assign rx_output_free_bank  = !rx_output_used[0] ? 1'b0 : 1'b1;

    //==========================================================================
    // Input job queue (depth 2, preserves external command order)
    //==========================================================================
    logic job_is_rx [0:1];
    logic job_bank  [0:1];
    logic [7:0] job_command [0:1];
    logic [8:0] job_length [0:1];
    logic job_wr_ptr, job_rd_ptr;
    logic [1:0] job_count;

    logic job_push, job_pop;
    assign job_push =
        ((ext_state == EXT_CAPTURE_RX) || (ext_state == EXT_CAPTURE_TX)) &&
        external_fire && (capture_index == capture_length-1'b1);
    logic job_head_is_rx;
    logic job_head_bank;
    logic [7:0] job_head_command;
    logic [8:0] job_head_length;
    assign job_head_is_rx  = job_is_rx[job_rd_ptr];
    assign job_head_bank   = job_bank[job_rd_ptr];
    assign job_head_command= job_command[job_rd_ptr];
    assign job_head_length = job_length[job_rd_ptr];

    //==========================================================================
    // External parser
    //==========================================================================
    localparam logic [2:0] EXT_IDLE = 3'd0;
    localparam logic [2:0] EXT_CAPTURE_RX = 3'd1;
    localparam logic [2:0] EXT_CAPTURE_TX = 3'd2;
    localparam logic [2:0] EXT_BYPASS = 3'd3;
    logic [2:0] ext_state;
    logic capture_bank;
    logic [8:0] capture_length, capture_index;
    logic [7:0] capture_command;
    logic [8:0] bypass_remaining;
    logic external_fire;
    assign external_fire = din_valid_i && din_ready_o;

    logic standalone_active;
    logic [7:0] standalone_command;

    // Capture writes to physical waveform SRAM for RX only.
    logic ext_wave_write;
    assign ext_wave_write = (ext_state == EXT_CAPTURE_RX) && external_fire;

    //==========================================================================
    // OFDM feeder
    //==========================================================================
    localparam logic [2:0] FEED_IDLE = 3'd0;
    localparam logic [2:0] FEED_COMMAND = 3'd1;
    localparam logic [2:0] FEED_RX_READ_REQ = 3'd2;
    localparam logic [2:0] FEED_RX_READ_WAIT = 3'd3;
    localparam logic [2:0] FEED_RX_SEND = 3'd4;
    localparam logic [2:0] FEED_TX_SEND = 3'd5;
    logic [2:0] feed_state;
    logic feed_bank;
    logic [7:0] feed_command;
    logic [8:0] feed_length, feed_index;
    logic [7:0] feed_byte_reg;
    logic feeder_start;
    logic feed_core_fire;
    logic feed_wave_read;

    logic core_ofdm_active;
    logic [7:0] core_job_command;
    logic core_output_bank;
    logic [8:0] core_output_byte_index;
    logic [5:0] rx_selected_byte_count;

    logic feeder_output_available;
    always @* begin
        if (job_count == 0)
            feeder_output_available = 1'b0;
        else if (job_head_is_rx)
            feeder_output_available = rx_output_free_valid;
        else
            feeder_output_available = wave_free_valid;
    end

    assign feeder_start =
        (feed_state == FEED_IDLE) && !core_ofdm_active && !standalone_active &&
        (job_count != 0) && feeder_output_available;
    assign job_pop = feeder_start;

    //==========================================================================
    // RX one-RB extractor
    //==========================================================================
    logic rx_extract_start;
    logic [7:0] rx_selected_data;
    logic rx_selected_valid, rx_extract_busy, rx_extract_done;
    assign rx_extract_start = feeder_start && job_head_is_rx;

    subcarrier_extractor #(.SC_START_BIN(1), .SC_COUNT(12)) u_subcarrier_extractor (
        .clk(clk), .rst_n(rst_n), .start_i(rx_extract_start),
        .din_i(core_dout),
        .din_valid_i(core_dout_valid && core_ofdm_active && is_rx_command(core_job_command)),
        .selected_data_o(rx_selected_data), .selected_valid_o(rx_selected_valid),
        .busy_o(rx_extract_busy), .done_o(rx_extract_done)
    );

    //==========================================================================
    // Standalone serializer
    //==========================================================================
    logic [7:0] standalone_dout;
    logic standalone_dout_valid, standalone_serializer_busy;
    logic standalone_transaction_done, standalone_job_done;

    standalone_result_serializer u_standalone_result_serializer (
        .clk(clk), .rst_n(rst_n), .enable_i(standalone_active),
        .X0_i_i(core_X0_i), .X0_q_i(core_X0_q),
        .X1_i_i(core_X1_i), .X1_q_i(core_X1_q),
        .X2_i_i(core_X2_i), .X2_q_i(core_X2_q),
        .result_addr0_i(core_result_addr0), .result_addr1_i(core_result_addr1),
        .result_addr2_i(core_result_addr2), .result_radix_i(core_result_radix),
        .result_last_i(core_result_last), .result_valid_i(core_result_valid),
        .result_ready_o(core_result_ready),
        .dout_o(standalone_dout), .dout_valid_o(standalone_dout_valid),
        .busy_o(standalone_serializer_busy),
        .transaction_done_o(standalone_transaction_done), .job_done_o(standalone_job_done)
    );

    //==========================================================================
    // Output queue: RX entries point at 24-byte register banks; TX entries point
    // at the shared 512-byte waveform SRAM banks.
    //==========================================================================
    logic out_is_tx [0:1];
    logic out_bank  [0:1];
    logic [8:0] out_length [0:1];
    logic out_wr_ptr, out_rd_ptr;
    logic [1:0] out_count;
    logic out_push, out_pop;

    // Core completion / queue commit.
    logic core_rx_complete, core_tx_complete, core_rx_selected_complete;
    assign core_rx_selected_complete =
        core_ofdm_active && is_rx_command(core_job_command) &&
        rx_selected_valid && (rx_selected_byte_count == 6'd23);
    assign core_rx_complete =
        core_ofdm_active && is_rx_command(core_job_command) &&
        core_dout_valid && (core_output_byte_index == 9'd255);
    assign core_tx_complete =
        core_ofdm_active && is_tx_command(core_job_command) &&
        core_dout_valid &&
        (core_output_byte_index == tx_output_byte_count(core_job_command)-1'b1);
    assign out_push = core_rx_selected_complete || core_tx_complete;

    //==========================================================================
    // Output drain
    //==========================================================================
    logic drain_active, drain_is_tx, drain_bank;
    logic [8:0] drain_length, drain_index;
    integer tx_pace_counter;
    logic drain_start;
    assign drain_start = !drain_active && !standalone_active && (out_count != 0);
    assign out_pop = drain_start;

    // Two-byte TX prefetch FIFO hides the synchronous 512x8 read latency and
    // preserves a continuous byte stream when TX_BYTE_INTERVAL==1.
    logic [7:0] tx_prefetch [0:1];
    logic tx_pf_wr_ptr, tx_pf_rd_ptr;
    logic [1:0] tx_pf_count;
    logic [8:0] tx_req_index;
    logic tx_read_pending;
    logic tx_wave_read_req;
    logic tx_wave_read_rsp;
    logic [7:0] tx_wave_read_data;
    logic tx_drain_emit;
    logic rx_drain_emit;

    assign tx_drain_emit =
        drain_active && drain_is_tx && (tx_pf_count != 0) &&
        (tx_pace_counter == 0);
    assign rx_drain_emit = drain_active && !drain_is_tx;

    // Request another TX SRAM byte when there is capacity accounting for the
    // one response already in flight and a byte potentially emitted this cycle.
    wire [2:0] tx_reserved_slots =
        {1'b0,tx_pf_count} + (tx_read_pending ? 3'd1 : 3'd0) -
        (tx_drain_emit ? 3'd1 : 3'd0);
    assign tx_wave_read_req =
        drain_active && drain_is_tx &&
        (tx_req_index < drain_length) &&
        (tx_reserved_slots < 3'd2);

    assign tx_wave_read_rsp = drain_bank ? wave1_rvalid : wave0_rvalid;
    assign tx_wave_read_data = drain_bank ? wave1_rdata : wave0_rdata;

    //==========================================================================
    // Core input mux and external ready
    //==========================================================================
    logic direct_core_path;
    logic [7:0] feed_tx_data;
    assign feed_tx_data = feed_bank ? tx_input_bank1[feed_index] : tx_input_bank0[feed_index];

    always @* begin
        core_din = din;
        core_din_valid = 1'b0;
        direct_core_path = 1'b0;

        case (feed_state)
            FEED_COMMAND: begin core_din = feed_command; core_din_valid = 1'b1; end
            FEED_RX_SEND: begin core_din = feed_byte_reg; core_din_valid = 1'b1; end
            FEED_TX_SEND: begin core_din = feed_tx_data; core_din_valid = 1'b1; end
            default: begin
                if (ext_state == EXT_BYPASS) begin
                    direct_core_path = 1'b1;
                    core_din = din;
                    core_din_valid = din_valid_i;
                end else if (
                    (ext_state == EXT_IDLE) && din_valid_i &&
                    !is_ofdm_command(din) && !standalone_active &&
                    (job_count == 0) && (feed_state == FEED_IDLE) &&
                    !core_ofdm_active && (out_count == 0) && !drain_active
                ) begin
                    direct_core_path = 1'b1;
                    core_din = din;
                    core_din_valid = din_valid_i;
                end
            end
        endcase
    end

    assign feed_core_fire = core_din_valid && core_din_ready &&
        ((feed_state == FEED_COMMAND) || (feed_state == FEED_RX_SEND) ||
         (feed_state == FEED_TX_SEND));

    always @* begin
        din_ready_o = 1'b0;
        case (ext_state)
            EXT_CAPTURE_RX, EXT_CAPTURE_TX: din_ready_o = 1'b1;
            EXT_BYPASS: din_ready_o = (feed_state == FEED_IDLE) ? core_din_ready : 1'b0;
            default: begin
                if (is_ofdm_command(din)) begin
                    if (is_rx_command(din))
                        din_ready_o = !standalone_active && (job_count < 2) && wave_free_valid;
                    else
                        din_ready_o = !standalone_active && (job_count < 2) && tx_input_free_valid;
                end else begin
                    din_ready_o =
                        !standalone_active && (job_count == 0) &&
                        (feed_state == FEED_IDLE) && !core_ofdm_active &&
                        (out_count == 0) && !drain_active && core_din_ready;
                end
            end
        endcase
    end

    //==========================================================================
    // Shared waveform-SRAM arbitration, one independent port per bank.
    //==========================================================================
    logic feed_wave_req;
    assign feed_wave_req = (feed_state == FEED_RX_READ_REQ);

    logic core_tx_wave_write;
    assign core_tx_wave_write =
        core_ofdm_active && is_tx_command(core_job_command) && core_dout_valid;

    always @* begin
        wave0_req = 1'b0; wave0_write = 1'b0; wave0_addr = 9'd0; wave0_wdata = 8'd0;
        wave1_req = 1'b0; wave1_write = 1'b0; wave1_addr = 9'd0; wave1_wdata = 8'd0;

        // Bank 0
        if (ext_wave_write && !capture_bank) begin
            wave0_req=1'b1; wave0_write=1'b1; wave0_addr=capture_index; wave0_wdata=din;
        end else if (feed_wave_req && !feed_bank) begin
            wave0_req=1'b1; wave0_addr=feed_index;
        end else if (core_tx_wave_write && !core_output_bank) begin
            wave0_req=1'b1; wave0_write=1'b1;
            wave0_addr=core_output_byte_index; wave0_wdata=core_dout;
        end else if (tx_wave_read_req && !drain_bank) begin
            wave0_req=1'b1; wave0_addr=tx_req_index;
        end

        // Bank 1
        if (ext_wave_write && capture_bank) begin
            wave1_req=1'b1; wave1_write=1'b1; wave1_addr=capture_index; wave1_wdata=din;
        end else if (feed_wave_req && feed_bank) begin
            wave1_req=1'b1; wave1_addr=feed_index;
        end else if (core_tx_wave_write && core_output_bank) begin
            wave1_req=1'b1; wave1_write=1'b1;
            wave1_addr=core_output_byte_index; wave1_wdata=core_dout;
        end else if (tx_wave_read_req && drain_bank) begin
            wave1_req=1'b1; wave1_addr=tx_req_index;
        end
    end

    //==========================================================================
    // Final dout mux
    //==========================================================================
    logic [7:0] rx_drain_data;
    assign rx_drain_data = drain_bank ? rx_output_bank1[drain_index] : rx_output_bank0[drain_index];

    always @* begin
        if (standalone_dout_valid) begin
            dout = standalone_dout;
            dout_valid_o = 1'b1;
        end else if (tx_drain_emit) begin
            dout = tx_prefetch[tx_pf_rd_ptr];
            dout_valid_o = 1'b1;
        end else if (rx_drain_emit) begin
            dout = rx_drain_data;
            dout_valid_o = 1'b1;
        end else begin
            dout = 8'd0;
            dout_valid_o = 1'b0;
        end
    end

    //==========================================================================
    // Sequential control
    //==========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ext_state <= EXT_IDLE;
            capture_bank <= 1'b0;
            capture_length <= 9'd0;
            capture_index <= 9'd0;
            capture_command <= 8'd0;
            bypass_remaining <= 9'd0;
            standalone_active <= 1'b0;
            standalone_command <= 8'd0;

            wave_owner[0] <= WAVE_FREE;
            wave_owner[1] <= WAVE_FREE;
            tx_input_used[0] <= 1'b0; tx_input_used[1] <= 1'b0;
            rx_output_used[0] <= 1'b0; rx_output_used[1] <= 1'b0;

            job_wr_ptr <= 1'b0; job_rd_ptr <= 1'b0; job_count <= 2'd0;
            out_wr_ptr <= 1'b0; out_rd_ptr <= 1'b0; out_count <= 2'd0;

            feed_state <= FEED_IDLE;
            feed_bank <= 1'b0;
            feed_command <= 8'd0;
            feed_length <= 9'd0;
            feed_index <= 9'd0;
            feed_byte_reg <= 8'd0;

            core_ofdm_active <= 1'b0;
            core_job_command <= 8'd0;
            core_output_bank <= 1'b0;
            core_output_byte_index <= 9'd0;
            rx_selected_byte_count <= 6'd0;

            drain_active <= 1'b0;
            drain_is_tx <= 1'b0;
            drain_bank <= 1'b0;
            drain_length <= 9'd0;
            drain_index <= 9'd0;
            tx_pace_counter <= 0;
            tx_pf_wr_ptr <= 1'b0; tx_pf_rd_ptr <= 1'b0; tx_pf_count <= 2'd0;
            tx_req_index <= 9'd0;
            tx_read_pending <= 1'b0;
        end else begin
            // Standalone transaction lifetime.
            if (standalone_job_done) begin
                standalone_active <= 1'b0;
                standalone_command <= 8'd0;
            end

            // External parser/capture.
            case (ext_state)
                EXT_IDLE: if (external_fire) begin
                    if (is_rx_command(din)) begin
                        capture_bank <= wave_free_bank;
                        capture_length <= ofdm_input_byte_count(din);
                        capture_index <= 9'd0;
                        capture_command <= din;
                        wave_owner[wave_free_bank] <= WAVE_RX_INPUT;
                        ext_state <= EXT_CAPTURE_RX;
                    end else if (is_tx_command(din)) begin
                        capture_bank <= tx_input_free_bank;
                        capture_length <= 9'd24;
                        capture_index <= 9'd0;
                        capture_command <= din;
                        tx_input_used[tx_input_free_bank] <= 1'b1;
                        ext_state <= EXT_CAPTURE_TX;
                    end else if (standalone_input_byte_count(din) != 0) begin
                        standalone_active <= 1'b1;
                        standalone_command <= din;
                        bypass_remaining <= standalone_input_byte_count(din);
                        ext_state <= EXT_BYPASS;
                    end
                end

                EXT_CAPTURE_RX: if (external_fire) begin
                    if (capture_index == capture_length-1'b1) begin
                        job_is_rx[job_wr_ptr] <= 1'b1;
                        job_bank[job_wr_ptr] <= capture_bank;
                        job_command[job_wr_ptr] <= capture_command;
                        job_length[job_wr_ptr] <= capture_length;
                        job_wr_ptr <= job_wr_ptr + 1'b1;
                        capture_index <= 9'd0;
                        ext_state <= EXT_IDLE;
                    end else capture_index <= capture_index + 1'b1;
                end

                EXT_CAPTURE_TX: if (external_fire) begin
                    if (capture_bank) tx_input_bank1[capture_index] <= din;
                    else tx_input_bank0[capture_index] <= din;
                    if (capture_index == capture_length-1'b1) begin
                        job_is_rx[job_wr_ptr] <= 1'b0;
                        job_bank[job_wr_ptr] <= capture_bank;
                        job_command[job_wr_ptr] <= capture_command;
                        job_length[job_wr_ptr] <= capture_length;
                        job_wr_ptr <= job_wr_ptr + 1'b1;
                        capture_index <= 9'd0;
                        ext_state <= EXT_IDLE;
                    end else capture_index <= capture_index + 1'b1;
                end

                EXT_BYPASS: if (external_fire) begin
                    if (bypass_remaining == 9'd1) begin
                        bypass_remaining <= 9'd0;
                        ext_state <= EXT_IDLE;
                    end else bypass_remaining <= bypass_remaining - 1'b1;
                end

                default: ext_state <= EXT_IDLE;
            endcase

            // Job queue count/pop. Push occurs on final OFDM capture edge.
            if (job_pop) job_rd_ptr <= job_rd_ptr + 1'b1;
            case ({job_push,job_pop})
                2'b10: job_count <= job_count + 1'b1;
                2'b01: job_count <= job_count - 1'b1;
                default: job_count <= job_count;
            endcase

            // Start next OFDM job and reserve its output storage.
            if (feeder_start) begin
                feed_bank <= job_head_bank;
                feed_command <= job_head_command;
                feed_length <= job_head_length;
                feed_index <= 9'd0;
                feed_state <= FEED_COMMAND;
                core_ofdm_active <= 1'b1;
                core_job_command <= job_head_command;
                core_output_byte_index <= 9'd0;
                rx_selected_byte_count <= 6'd0;
                if (job_head_is_rx) begin
                    core_output_bank <= rx_output_free_bank;
                    rx_output_used[rx_output_free_bank] <= 1'b1;
                end else begin
                    core_output_bank <= wave_free_bank;
                    wave_owner[wave_free_bank] <= WAVE_TX_OUTPUT;
                end
            end

            // Feeder state machine.
            case (feed_state)
                FEED_COMMAND: if (feed_core_fire) begin
                    feed_index <= 9'd0;
                    if (is_rx_command(feed_command)) feed_state <= FEED_RX_READ_REQ;
                    else feed_state <= FEED_TX_SEND;
                end
                FEED_RX_READ_REQ: feed_state <= FEED_RX_READ_WAIT;
                FEED_RX_READ_WAIT: begin
                    if ((!feed_bank && wave0_rvalid) || (feed_bank && wave1_rvalid)) begin
                        feed_byte_reg <= feed_bank ? wave1_rdata : wave0_rdata;
                        feed_state <= FEED_RX_SEND;
                    end
                end
                FEED_RX_SEND: if (feed_core_fire) begin
                    if (feed_index == feed_length-1'b1) begin
                        wave_owner[feed_bank] <= WAVE_FREE;
                        feed_index <= 9'd0;
                        feed_state <= FEED_IDLE;
                    end else begin
                        feed_index <= feed_index + 1'b1;
                        feed_state <= FEED_RX_READ_REQ;
                    end
                end
                FEED_TX_SEND: if (feed_core_fire) begin
                    if (feed_index == feed_length-1'b1) begin
                        tx_input_used[feed_bank] <= 1'b0;
                        feed_index <= 9'd0;
                        feed_state <= FEED_IDLE;
                    end else feed_index <= feed_index + 1'b1;
                end
                default: begin end
            endcase

            // Capture core output. TX writes are performed by SRAM arbiter.
            if (core_ofdm_active && core_dout_valid) begin
                if (core_tx_complete || core_rx_complete) begin
                    core_ofdm_active <= 1'b0;
                    core_output_byte_index <= 9'd0;
                end else core_output_byte_index <= core_output_byte_index + 1'b1;
            end

            if (rx_selected_valid && core_ofdm_active && is_rx_command(core_job_command)) begin
                if (core_output_bank) rx_output_bank1[rx_selected_byte_count] <= rx_selected_data;
                else rx_output_bank0[rx_selected_byte_count] <= rx_selected_data;
                if (rx_selected_byte_count != 6'd23)
                    rx_selected_byte_count <= rx_selected_byte_count + 1'b1;
            end

            // Commit an output queue entry when its useful data is complete.
            if (out_push) begin
                out_is_tx[out_wr_ptr] <= core_tx_complete;
                out_bank[out_wr_ptr] <= core_output_bank;
                out_length[out_wr_ptr] <= core_tx_complete
                    ? tx_output_byte_count(core_job_command) : 9'd24;
                out_wr_ptr <= out_wr_ptr + 1'b1;
            end
            if (out_pop) out_rd_ptr <= out_rd_ptr + 1'b1;
            case ({out_push,out_pop})
                2'b10: out_count <= out_count + 1'b1;
                2'b01: out_count <= out_count - 1'b1;
                default: out_count <= out_count;
            endcase

            // Begin output drain.
            if (drain_start) begin
                drain_active <= 1'b1;
                drain_is_tx <= out_is_tx[out_rd_ptr];
                drain_bank <= out_bank[out_rd_ptr];
                drain_length <= out_length[out_rd_ptr];
                drain_index <= 9'd0;
                tx_pace_counter <= 0;
                tx_pf_wr_ptr <= 1'b0; tx_pf_rd_ptr <= 1'b0; tx_pf_count <= 2'd0;
                tx_req_index <= 9'd0;
                tx_read_pending <= 1'b0;
            end

            if (tx_pace_counter > 0) tx_pace_counter <= tx_pace_counter - 1;

            // TX SRAM prefetch request/response tracking.
            tx_read_pending <= tx_wave_read_req;
            if (tx_wave_read_req) tx_req_index <= tx_req_index + 1'b1;

            // Push SRAM response into 2-byte FIFO; pop when emitted.
            case ({tx_wave_read_rsp && drain_active && drain_is_tx, tx_drain_emit})
                2'b10: begin
                    tx_prefetch[tx_pf_wr_ptr] <= tx_wave_read_data;
                    tx_pf_wr_ptr <= tx_pf_wr_ptr + 1'b1;
                    tx_pf_count <= tx_pf_count + 1'b1;
                end
                2'b01: begin
                    tx_pf_rd_ptr <= tx_pf_rd_ptr + 1'b1;
                    tx_pf_count <= tx_pf_count - 1'b1;
                end
                2'b11: begin
                    tx_prefetch[tx_pf_wr_ptr] <= tx_wave_read_data;
                    tx_pf_wr_ptr <= tx_pf_wr_ptr + 1'b1;
                    tx_pf_rd_ptr <= tx_pf_rd_ptr + 1'b1;
                    tx_pf_count <= tx_pf_count;
                end
                default: begin end
            endcase

            if (tx_drain_emit) begin
                if (TX_BYTE_INTERVAL > 1) tx_pace_counter <= TX_BYTE_INTERVAL-1;
                else tx_pace_counter <= 0;
                if (drain_index == drain_length-1'b1) begin
                    drain_active <= 1'b0;
                    drain_index <= 9'd0;
                    wave_owner[drain_bank] <= WAVE_FREE;
                end else drain_index <= drain_index + 1'b1;
            end else if (rx_drain_emit) begin
                if (drain_index == drain_length-1'b1) begin
                    drain_active <= 1'b0;
                    drain_index <= 9'd0;
                    rx_output_used[drain_bank] <= 1'b0;
                end else drain_index <= drain_index + 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
