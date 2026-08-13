`timescale 1ns/1ps
`default_nettype none

//==============================================================================
// Global scheduler / real-time buffering wrapper
//
// This module preserves every existing standalone transform command while
// buffering the OFDM modes around the proven transform_scheduler_core.
//
// The two input banks decouple timed waveform capture from folded computation:
// while the core drains/processes bank A, the external byte stream can fill B.
// The two output banks decouple DFT-s-OFDM generation from timed waveform
// delivery: while bank A is emitted, the core may fill B.
//
// The ping-pong buffers intentionally live at the 8-bit Q1.7 boundary instead
// of duplicating the 16-bit FFT scratch RAM. This provides the required symbol
// decoupling at substantially lower storage cost.
//==============================================================================
module scheduler #(
    parameter integer TRANSACTION_FIFO_DEPTH = 4,
    // Number of clk cycles between transmitted TDIQ bytes. Keep at 1 for the
    // legacy regression. At clk=61.44 MHz, set to 16 for a 3.84 MB/s byte
    // stream = 1.92 Msamples/s complex waveform rate.
    parameter integer TX_BYTE_INTERVAL = 1
) (
    input logic clk,
    input logic rst_n,

    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,

    output logic signed [15:0] X0_i_o,
    output logic signed [15:0] X0_q_o,
    output logic signed [15:0] X1_i_o,
    output logic signed [15:0] X1_q_o,
    output logic signed [15:0] X2_i_o,
    output logic signed [15:0] X2_q_o,

    output logic [6:0] result_addr0_o,
    output logic [6:0] result_addr1_o,
    output logic [6:0] result_addr2_o,
    output logic [1:0] result_radix_o,
    output logic       result_last_o,

    output logic result_valid_o,
    input  logic result_ready_i,

    output logic [7:0] dout,
    output logic       dout_valid_o
);

    //--------------------------------------------------------------------------
    // Command map. Opcodes are unchanged; only the CP terminology is corrected.
    //--------------------------------------------------------------------------
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

    localparam integer SHORT_NORMAL_CP = 9;
    localparam integer LONG_NORMAL_CP  = 10;
    localparam integer MAX_FRAME_BYTES = 2 * (128 + LONG_NORMAL_CP); // 276
    localparam integer RX_SELECTED_BYTES = 2 * 12;                   // 24

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
                CMD_OFDM_RX_SHORT_NORMAL_CP:
                    ofdm_input_byte_count = 9'd274;
                CMD_OFDM_RX_LONG_NORMAL_CP:
                    ofdm_input_byte_count = 9'd276;
                CMD_OFDM_TX_SHORT_NORMAL_CP,
                CMD_OFDM_TX_LONG_NORMAL_CP:
                    ofdm_input_byte_count = 9'd24;
                default:
                    ofdm_input_byte_count = 9'd0;
            endcase
        end
    endfunction

    function automatic [8:0] tx_output_byte_count(input logic [7:0] command);
        begin
            tx_output_byte_count =
                (command == CMD_OFDM_TX_LONG_NORMAL_CP) ? 9'd276 : 9'd274;
        end
    endfunction

    function automatic [8:0] standalone_input_byte_count(
        input logic [7:0] command
    );
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

    //--------------------------------------------------------------------------
    // Proven transform core interface
    //--------------------------------------------------------------------------
    logic [7:0] core_din;
    logic       core_din_valid;
    logic       core_din_ready;
    logic [7:0] core_dout;
    logic       core_dout_valid;

    transform_scheduler_core #(
        .TRANSACTION_FIFO_DEPTH(TRANSACTION_FIFO_DEPTH)
    ) u_transform_scheduler_core (
        .clk              (clk),
        .rst_n            (rst_n),
        .din              (core_din),
        .din_valid_i      (core_din_valid),
        .din_ready_o      (core_din_ready),
        .X0_i_o           (X0_i_o),
        .X0_q_o           (X0_q_o),
        .X1_i_o           (X1_i_o),
        .X1_q_o           (X1_q_o),
        .X2_i_o           (X2_i_o),
        .X2_q_o           (X2_q_o),
        .result_addr0_o   (result_addr0_o),
        .result_addr1_o   (result_addr1_o),
        .result_addr2_o   (result_addr2_o),
        .result_radix_o   (result_radix_o),
        .result_last_o    (result_last_o),
        .result_valid_o   (result_valid_o),
        .result_ready_i   (result_ready_i),
        .dout             (core_dout),
        .dout_valid_o     (core_dout_valid),
        .debug_mode_i     (1'b0), .debug_req_i(1'b0),
        .debug_write_i    (1'b0), .debug_addr_i(8'd0),
        .debug_wdata_i    (16'd0), .debug_ready_o(),
        .debug_rdata_o    (), .debug_rvalid_o()
    );

    //--------------------------------------------------------------------------
    // Input ping-pong frame buffers
    //--------------------------------------------------------------------------
    logic [7:0] input_bank0 [0:MAX_FRAME_BYTES-1];
    logic [7:0] input_bank1 [0:MAX_FRAME_BYTES-1];

    logic       input_bank0_used;
    logic       input_bank1_used;
    logic [7:0] input_bank_command [0:1];
    logic [8:0] input_bank_length  [0:1];

    logic       input_queue_bank [0:1];
    logic       input_queue_write_pointer;
    logic       input_queue_read_pointer;
    logic [1:0] input_queue_count;

    logic input_free_valid;
    logic input_free_bank;

    assign input_free_valid = !input_bank0_used || !input_bank1_used;
    assign input_free_bank  = !input_bank0_used ? 1'b0 : 1'b1;

    //--------------------------------------------------------------------------
    // External input parser
    //--------------------------------------------------------------------------
    localparam logic [1:0] EXT_IDLE    = 2'd0;
    localparam logic [1:0] EXT_CAPTURE = 2'd1;
    localparam logic [1:0] EXT_BYPASS  = 2'd2;

    logic [1:0] ext_state;
    logic       capture_bank;
    logic [8:0] capture_length;
    logic [8:0] capture_index;
    logic [7:0] capture_command;
    logic [8:0] bypass_remaining;

    logic external_fire;
    logic capture_final_fire;
    logic input_queue_push;
    logic input_queue_pop;

    logic direct_core_path;
    logic direct_core_valid;

    assign external_fire = din_valid_i && din_ready_o;
    assign capture_final_fire =
        (ext_state == EXT_CAPTURE) && external_fire &&
        (capture_index == capture_length - 1'b1);
    assign input_queue_push = capture_final_fire;

    //--------------------------------------------------------------------------
    // Output ping-pong buffers. Both RX FDIQ and TX TDIQ responses are queued
    // here, so the single dout port always preserves command order.
    //--------------------------------------------------------------------------
    logic [7:0] output_bank0 [0:MAX_FRAME_BYTES-1];
    logic [7:0] output_bank1 [0:MAX_FRAME_BYTES-1];

    logic       output_bank0_used;
    logic       output_bank1_used;
    logic [8:0] output_bank_length [0:1];
    logic       output_bank_is_tx  [0:1];

    logic       output_queue_bank [0:1];
    logic       output_queue_write_pointer;
    logic       output_queue_read_pointer;
    logic [1:0] output_queue_count;

    logic output_free_valid;
    logic output_free_bank;

    assign output_free_valid = !output_bank0_used || !output_bank1_used;
    assign output_free_bank  = !output_bank0_used ? 1'b0 : 1'b1;

    //--------------------------------------------------------------------------
    // OFDM feeder: drains one buffered input frame into the original scheduler.
    //--------------------------------------------------------------------------
    logic       feed_active;
    logic       feed_bank;
    logic       feed_command_phase;
    logic [7:0] feed_command;
    logic [8:0] feed_length;
    logic [8:0] feed_index;
    logic [7:0] feed_data;
    logic       feed_fire;

    logic       core_ofdm_active;
    logic [7:0] core_job_command;
    logic       core_output_bank;
    logic [8:0] core_output_byte_index;
    logic [5:0] rx_selected_byte_count;

    logic feeder_start;
    logic direct_request_now;

    assign feed_data = feed_bank
        ? input_bank1[feed_index]
        : input_bank0[feed_index];

    // A pending buffered OFDM frame has priority over a new standalone command.
    // A direct standalone transaction only owns the core while its payload is
    // actively being forwarded. Buffered OFDM jobs otherwise take priority,
    // preventing a held standalone command from starving the feeder.
    assign direct_request_now = (ext_state == EXT_BYPASS);

    assign feeder_start =
        !feed_active && !core_ofdm_active &&
        (input_queue_count != 0) &&
        output_free_valid &&
        !direct_request_now;

    assign input_queue_pop = feeder_start;

    assign feed_fire = feed_active && core_din_valid && core_din_ready;

    //--------------------------------------------------------------------------
    // One-RB RX extraction: bins 1..12, matching the fixed TX allocation.
    //--------------------------------------------------------------------------
    logic       rx_extract_start;
    logic [7:0] rx_selected_data;
    logic       rx_selected_valid;
    logic       rx_extract_busy;
    logic       rx_extract_done;

    assign rx_extract_start = feeder_start &&
        is_rx_command(input_bank_command[input_queue_bank[input_queue_read_pointer]]);

    subcarrier_extractor #(
        .SC_START_BIN(1),
        .SC_COUNT(12)
    ) u_subcarrier_extractor (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_i          (rx_extract_start),
        .din_i            (core_dout),
        .din_valid_i      (core_dout_valid && core_ofdm_active &&
                           is_rx_command(core_job_command)),
        .selected_data_o  (rx_selected_data),
        .selected_valid_o (rx_selected_valid),
        .busy_o           (rx_extract_busy),
        .done_o           (rx_extract_done)
    );

    //--------------------------------------------------------------------------
    // Core input mux and external din_ready
    //--------------------------------------------------------------------------
    always @* begin
        direct_core_path = 1'b0;
        direct_core_valid = 1'b0;

        if (feed_active) begin
            core_din = feed_command_phase ? feed_command : feed_data;
            core_din_valid = 1'b1;
        end else begin
            core_din = din;
            core_din_valid = 1'b0;

            if (ext_state == EXT_BYPASS) begin
                direct_core_path = 1'b1;
                direct_core_valid = din_valid_i;
                core_din_valid = din_valid_i;
            end else if (
                (ext_state == EXT_IDLE) &&
                !is_ofdm_command(din) &&
                (input_queue_count == 0) &&
                !core_ofdm_active
            ) begin
                direct_core_path = 1'b1;
                direct_core_valid = din_valid_i;
                core_din_valid = din_valid_i;
            end
        end

        din_ready_o = 1'b0;
        case (ext_state)
            EXT_CAPTURE: begin
                // The frame bank was reserved when the command was accepted.
                din_ready_o = 1'b1;
            end

            EXT_BYPASS: begin
                din_ready_o = feed_active ? 1'b0 : core_din_ready;
            end

            default: begin
                if (is_ofdm_command(din)) begin
                    // OFDM traffic is buffered and can arrive while the core is
                    // still processing the previous symbol.
                    din_ready_o = input_free_valid;
                end else begin
                    // Standalone traffic remains direct and is held behind any
                    // already-buffered OFDM frame to preserve command order.
                    din_ready_o =
                        (input_queue_count == 0) &&
                        !feed_active && !core_ofdm_active &&
                        core_din_ready;
                end
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Core-output capture and output queue creation
    //--------------------------------------------------------------------------
    logic core_rx_selected_complete;
    logic core_tx_complete;
    logic core_rx_complete;
    logic output_queue_push;

    assign core_rx_selected_complete =
        core_ofdm_active && is_rx_command(core_job_command) &&
        core_dout_valid && (core_output_byte_index == 9'd25);

    assign core_rx_complete =
        core_ofdm_active && is_rx_command(core_job_command) &&
        core_dout_valid && (core_output_byte_index == 9'd255);

    assign core_tx_complete =
        core_ofdm_active && is_tx_command(core_job_command) &&
        core_dout_valid &&
        (core_output_byte_index == tx_output_byte_count(core_job_command) - 1'b1);

    assign output_queue_push = core_rx_selected_complete || core_tx_complete;

    //--------------------------------------------------------------------------
    // External output drain and optional TX waveform pacing
    //--------------------------------------------------------------------------
    logic       drain_active;
    logic       drain_bank;
    logic [8:0] drain_length;
    logic [8:0] drain_index;
    logic       drain_is_tx;
    integer     tx_pace_counter;

    logic output_queue_pop;
    logic drain_start;
    logic drain_emit;
    logic [7:0] drain_data;

    assign drain_start = !drain_active && (output_queue_count != 0);
    assign output_queue_pop = drain_start;

    assign drain_data = drain_bank
        ? output_bank1[drain_index]
        : output_bank0[drain_index];

    assign dout = drain_data;
    assign dout_valid_o =
        drain_active && (!drain_is_tx || (tx_pace_counter == 0));
    assign drain_emit = dout_valid_o;

    //--------------------------------------------------------------------------
    // Sequential control
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ext_state <= EXT_IDLE;
            capture_bank <= 1'b0;
            capture_length <= 9'd0;
            capture_index <= 9'd0;
            capture_command <= 8'd0;
            bypass_remaining <= 9'd0;

            input_bank0_used <= 1'b0;
            input_bank1_used <= 1'b0;
            input_queue_write_pointer <= 1'b0;
            input_queue_read_pointer <= 1'b0;
            input_queue_count <= 2'd0;

            output_bank0_used <= 1'b0;
            output_bank1_used <= 1'b0;
            output_queue_write_pointer <= 1'b0;
            output_queue_read_pointer <= 1'b0;
            output_queue_count <= 2'd0;

            feed_active <= 1'b0;
            feed_bank <= 1'b0;
            feed_command_phase <= 1'b0;
            feed_command <= 8'd0;
            feed_length <= 9'd0;
            feed_index <= 9'd0;

            core_ofdm_active <= 1'b0;
            core_job_command <= 8'd0;
            core_output_bank <= 1'b0;
            core_output_byte_index <= 9'd0;
            rx_selected_byte_count <= 6'd0;

            drain_active <= 1'b0;
            drain_bank <= 1'b0;
            drain_length <= 9'd0;
            drain_index <= 9'd0;
            drain_is_tx <= 1'b0;
            tx_pace_counter <= 0;
        end else begin
            //------------------------------------------------------------------
            // External parser / capture
            //------------------------------------------------------------------
            case (ext_state)
                EXT_IDLE: begin
                    if (external_fire) begin
                        if (is_ofdm_command(din)) begin
                            capture_bank <= input_free_bank;
                            capture_length <= ofdm_input_byte_count(din);
                            capture_index <= 9'd0;
                            capture_command <= din;

                            input_bank_command[input_free_bank] <= din;
                            input_bank_length[input_free_bank] <=
                                ofdm_input_byte_count(din);
                            if (input_free_bank)
                                input_bank1_used <= 1'b1;
                            else
                                input_bank0_used <= 1'b1;

                            ext_state <= EXT_CAPTURE;
                        end else if (standalone_input_byte_count(din) != 0) begin
                            bypass_remaining <= standalone_input_byte_count(din);
                            ext_state <= EXT_BYPASS;
                        end
                    end
                end

                EXT_CAPTURE: begin
                    if (external_fire) begin
                        if (capture_bank)
                            input_bank1[capture_index] <= din;
                        else
                            input_bank0[capture_index] <= din;

                        if (capture_index == capture_length - 1'b1) begin
                            capture_index <= 9'd0;
                            ext_state <= EXT_IDLE;
                        end else begin
                            capture_index <= capture_index + 1'b1;
                        end
                    end
                end

                EXT_BYPASS: begin
                    if (external_fire) begin
                        if (bypass_remaining == 9'd1) begin
                            bypass_remaining <= 9'd0;
                            ext_state <= EXT_IDLE;
                        end else begin
                            bypass_remaining <= bypass_remaining - 1'b1;
                        end
                    end
                end

                default: ext_state <= EXT_IDLE;
            endcase

            //------------------------------------------------------------------
            // Input queue
            //------------------------------------------------------------------
            if (input_queue_push) begin
                input_queue_bank[input_queue_write_pointer] <= capture_bank;
                input_queue_write_pointer <= input_queue_write_pointer + 1'b1;
            end
            if (input_queue_pop)
                input_queue_read_pointer <= input_queue_read_pointer + 1'b1;

            case ({input_queue_push, input_queue_pop})
                2'b10: input_queue_count <= input_queue_count + 1'b1;
                2'b01: input_queue_count <= input_queue_count - 1'b1;
                default: input_queue_count <= input_queue_count;
            endcase

            //------------------------------------------------------------------
            // Begin a buffered OFDM job. Reserve an output bank before sending
            // the command so a completed symbol can never be dropped.
            //------------------------------------------------------------------
            if (feeder_start) begin
                feed_active <= 1'b1;
                feed_bank <= input_queue_bank[input_queue_read_pointer];
                feed_command <= input_bank_command[
                    input_queue_bank[input_queue_read_pointer]
                ];
                feed_length <= input_bank_length[
                    input_queue_bank[input_queue_read_pointer]
                ];
                feed_index <= 9'd0;
                feed_command_phase <= 1'b1;

                core_ofdm_active <= 1'b1;
                core_job_command <= input_bank_command[
                    input_queue_bank[input_queue_read_pointer]
                ];
                core_output_bank <= output_free_bank;
                core_output_byte_index <= 9'd0;
                rx_selected_byte_count <= 6'd0;

                if (output_free_bank)
                    output_bank1_used <= 1'b1;
                else
                    output_bank0_used <= 1'b1;
            end

            //------------------------------------------------------------------
            // Drain buffered input into the proven scheduler.
            //------------------------------------------------------------------
            if (feed_fire) begin
                if (feed_command_phase) begin
                    feed_command_phase <= 1'b0;
                    feed_index <= 9'd0;
                end else if (feed_index == feed_length - 1'b1) begin
                    feed_active <= 1'b0;
                    feed_index <= 9'd0;
                    if (feed_bank)
                        input_bank1_used <= 1'b0;
                    else
                        input_bank0_used <= 1'b0;
                end else begin
                    feed_index <= feed_index + 1'b1;
                end
            end

            //------------------------------------------------------------------
            // Capture OFDM core output.
            //------------------------------------------------------------------
            if (core_ofdm_active && core_dout_valid) begin
                if (is_tx_command(core_job_command)) begin
                    if (core_output_bank)
                        output_bank1[core_output_byte_index] <= core_dout;
                    else
                        output_bank0[core_output_byte_index] <= core_dout;
                end

                if (core_tx_complete || core_rx_complete) begin
                    core_ofdm_active <= 1'b0;
                    core_output_byte_index <= 9'd0;
                end else begin
                    core_output_byte_index <= core_output_byte_index + 1'b1;
                end
            end

            if (rx_selected_valid && core_ofdm_active &&
                is_rx_command(core_job_command)) begin
                if (core_output_bank)
                    output_bank1[rx_selected_byte_count] <= rx_selected_data;
                else
                    output_bank0[rx_selected_byte_count] <= rx_selected_data;
                rx_selected_byte_count <= rx_selected_byte_count + 1'b1;
            end

            //------------------------------------------------------------------
            // Output queue metadata is committed when the useful RX RB is fully
            // captured or when a TX waveform burst is complete.
            //------------------------------------------------------------------
            if (output_queue_push) begin
                output_queue_bank[output_queue_write_pointer] <= core_output_bank;
                output_queue_write_pointer <= output_queue_write_pointer + 1'b1;

                if (core_rx_selected_complete) begin
                    output_bank_length[core_output_bank] <= RX_SELECTED_BYTES;
                    output_bank_is_tx[core_output_bank] <= 1'b0;
                end else begin
                    output_bank_length[core_output_bank] <=
                        tx_output_byte_count(core_job_command);
                    output_bank_is_tx[core_output_bank] <= 1'b1;
                end
            end

            if (output_queue_pop)
                output_queue_read_pointer <= output_queue_read_pointer + 1'b1;

            case ({output_queue_push, output_queue_pop})
                2'b10: output_queue_count <= output_queue_count + 1'b1;
                2'b01: output_queue_count <= output_queue_count - 1'b1;
                default: output_queue_count <= output_queue_count;
            endcase

            //------------------------------------------------------------------
            // Output drain / TX byte pacing
            //------------------------------------------------------------------
            if (tx_pace_counter > 0)
                tx_pace_counter <= tx_pace_counter - 1;

            if (drain_start) begin
                drain_active <= 1'b1;
                drain_bank <= output_queue_bank[output_queue_read_pointer];
                drain_length <= output_bank_length[
                    output_queue_bank[output_queue_read_pointer]
                ];
                drain_is_tx <= output_bank_is_tx[
                    output_queue_bank[output_queue_read_pointer]
                ];
                drain_index <= 9'd0;
            end

            if (drain_emit) begin
                if (drain_is_tx && (TX_BYTE_INTERVAL > 1))
                    tx_pace_counter <= TX_BYTE_INTERVAL - 1;
                else
                    tx_pace_counter <= 0;

                if (drain_index == drain_length - 1'b1) begin
                    drain_active <= 1'b0;
                    drain_index <= 9'd0;
                    if (drain_bank)
                        output_bank1_used <= 1'b0;
                    else
                        output_bank0_used <= 1'b0;
                end else begin
                    drain_index <= drain_index + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
