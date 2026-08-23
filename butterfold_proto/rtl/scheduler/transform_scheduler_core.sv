`timescale 1ns/1ps
`default_nettype none

module transform_scheduler_core #(
    parameter integer TRANSACTION_FIFO_DEPTH = 1,
    parameter integer TX_BYTE_INTERVAL = 1
) (
    input logic clk,
    input logic rst_n,

    // Input byte stream.
    // FFT2/IFFT2: command, x0_i, x0_q, x1_i, x1_q
    // FFT3:       command, x0_i, x0_q, x1_i, x1_q, x2_i, x2_q
    // FFT64:      command, x[0].i, x[0].q, ... x[63].i, x[63].q
    // IFFT64:     command, X[0].i, X[0].q, ... X[63].i, X[63].q
    // DFT12:      command, x[0].i, x[0].q, ... x[11].i, x[11].q
    // OFDM_RX:    command, 4/5-sample reduced-grid CP, then 64 useful samples.
    // DFTS_TX:    command, 12 frequency samples; output uses a 4/5-sample CP.
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,

    // One complete mixed-radix result transaction. X2 is meaningful when
    // result_radix_o == 3.
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

    // Byte-stream output used by OFDM_RX (FDIQ) and DFT-s-OFDM TX (TDIQ).
    // The receiver is assumed always ready whenever dout_valid_o is asserted.
    output logic [7:0] dout,
    output logic       dout_valid_o,

    // Idle-only post-silicon access to the physical 256x16 scratch port.
    // The top-level command engine holds debug_mode_i for the complete
    // transaction; active transform owners always have priority.
    input  logic        debug_mode_i,
    input  logic        debug_req_i,
    input  logic        debug_write_i,
    input  logic [7:0]  debug_addr_i,
    input  logic [15:0] debug_wdata_i,
    output logic        debug_ready_o,
    output logic [15:0] debug_rdata_o,
    output logic        debug_rvalid_o
`ifdef USE_POWER_PINS
    , inout wire VDD
    , inout wire VSS
`endif
);

    //==========================================================================
    // Commands and constants
    //==========================================================================

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT64   = 8'h41;
    localparam logic [7:0] CMD_IFFT64  = 8'h42;
    localparam logic [7:0] CMD_IFFT2   = 8'h43;
    localparam logic [7:0] CMD_FFT3    = 8'h44;
    localparam logic [7:0] CMD_DFT12              = 8'h45;
    localparam logic [7:0] CMD_OFDM_RX_SHORT_NORMAL_CP   = 8'h46;
    localparam logic [7:0] CMD_OFDM_RX_LONG_NORMAL_CP = 8'h47;
    localparam logic [7:0] CMD_OFDM_TX_SHORT_NORMAL_CP    = 8'h48;
    localparam logic [7:0] CMD_OFDM_TX_LONG_NORMAL_CP  = 8'h49;

    localparam logic [3:0] OFDM_SHORT_NORMAL_CP_LENGTH = 4'd4;
    localparam logic [3:0] OFDM_LONG_NORMAL_CP_LENGTH  = 4'd5;
    localparam logic [7:0] FFT_N = 8'd64;
    localparam logic [2:0] FFT_FINAL_STAGE = 3'd5;
    localparam integer IFFT_NORMALIZE_SHIFT = 6;

    localparam logic [1:0] UOP_RADIX2 = 2'b01;
    localparam logic [1:0] UOP_RADIX3 = 2'b10;

    // Q1.7 encodes -1 exactly but cannot encode +1 exactly. For unity
    // twiddles, the scheduler negates x1 and sends W=-1, so W*(-x1)=x1.
    localparam logic signed [7:0] UNITY_PROXY_RE = 8'sh80;
    localparam logic signed [7:0] UNITY_PROXY_IM = 8'sh00;

    // round((sqrt(3)/2)*128) = 111. The radix-3 core multiplies
    // (x1-x2) by -j*sqrt(3)/2 using the existing complex multiplier.
    localparam logic signed [7:0] FFT3_COEFF_RE = 8'sd0;
    localparam logic signed [7:0] FFT3_COEFF_IM = -8'sd111;

    // Exact forward FFT4 twiddle W4^1 = -j.
    localparam logic signed [7:0] NEG_J_RE = 8'sd0;
    localparam logic signed [7:0] NEG_J_IM = 8'sh80;

    localparam integer FIFO_POINTER_WIDTH =
        (TRANSACTION_FIFO_DEPTH <= 1)
            ? 1
            : $clog2(TRANSACTION_FIFO_DEPTH);

    localparam integer FIFO_COUNT_WIDTH =
        $clog2(TRANSACTION_FIFO_DEPTH + 1);

    // Result metadata can cover every queued small transform plus the butterfly's
    // elastic input/output storage.
    localparam integer RESULT_META_DEPTH = TRANSACTION_FIFO_DEPTH + 2;
    localparam integer RESULT_META_POINTER_WIDTH =
        (RESULT_META_DEPTH <= 1) ? 1 : $clog2(RESULT_META_DEPTH);
    localparam integer RESULT_META_COUNT_WIDTH =
        $clog2(RESULT_META_DEPTH + 1);

    //==========================================================================
    // Utility functions
    //==========================================================================

    function automatic logic signed [15:0] sign_extend_q17 (
        input logic [7:0] value
    );
        begin
            sign_extend_q17 = $signed({{8{value[7]}}, value});
        end
    endfunction

    function automatic logic signed [15:0] negate_q17 (
        input logic [7:0] value
    );
        logic signed [15:0] extended_value;
        begin
            extended_value = $signed({{8{value[7]}}, value});
            negate_q17 = -extended_value;
        end
    endfunction

    function automatic logic signed [15:0] negate16 (
        input logic signed [15:0] value
    );
        begin
            negate16 = -value;
        end
    endfunction

    function automatic logic signed [7:0] negate8 (
        input logic signed [7:0] value
    );
        begin
            negate8 = -value;
        end
    endfunction

    function automatic logic [6:0] bit_reverse6 (
        input logic [6:0] value
    );
        begin
            bit_reverse6 = {
                1'b0, value[0], value[1], value[2],
                value[3], value[4], value[5]
            };
        end
    endfunction

    // Good-Thomas input CRT mapping for N=12=3x4:
    // n = 4*n1 + 9*n2 (mod 12).
    function automatic logic [3:0] dft12_input_address (
        input logic [1:0] n1,
        input logic [1:0] n2
    );
        begin
            case (n2)
                2'd0: begin
                    case (n1)
                        2'd0: dft12_input_address = 4'd0;
                        2'd1: dft12_input_address = 4'd4;
                        default: dft12_input_address = 4'd8;
                    endcase
                end
                2'd1: begin
                    case (n1)
                        2'd0: dft12_input_address = 4'd9;
                        2'd1: dft12_input_address = 4'd1;
                        default: dft12_input_address = 4'd5;
                    endcase
                end
                2'd2: begin
                    case (n1)
                        2'd0: dft12_input_address = 4'd6;
                        2'd1: dft12_input_address = 4'd10;
                        default: dft12_input_address = 4'd2;
                    endcase
                end
                default: begin
                    case (n1)
                        2'd0: dft12_input_address = 4'd3;
                        2'd1: dft12_input_address = 4'd7;
                        default: dft12_input_address = 4'd11;
                    endcase
                end
            endcase
        end
    endfunction

    // Good-Thomas output CRT mapping:
    // k = 4*k1 + 3*k2 (mod 12).
    function automatic logic [3:0] dft12_output_address (
        input logic [1:0] k1,
        input logic [1:0] k2
    );
        begin
            case (k1)
                2'd0: begin
                    case (k2)
                        2'd0: dft12_output_address = 4'd0;
                        2'd1: dft12_output_address = 4'd3;
                        2'd2: dft12_output_address = 4'd6;
                        default: dft12_output_address = 4'd9;
                    endcase
                end
                2'd1: begin
                    case (k2)
                        2'd0: dft12_output_address = 4'd4;
                        2'd1: dft12_output_address = 4'd7;
                        2'd2: dft12_output_address = 4'd10;
                        default: dft12_output_address = 4'd1;
                    endcase
                end
                default: begin
                    case (k2)
                        2'd0: dft12_output_address = 4'd8;
                        2'd1: dft12_output_address = 4'd11;
                        2'd2: dft12_output_address = 4'd2;
                        default: dft12_output_address = 4'd5;
                    endcase
                end
            endcase
        end
    endfunction

    function automatic logic [FIFO_POINTER_WIDTH-1:0]
        increment_fifo_pointer (
            input logic [FIFO_POINTER_WIDTH-1:0] pointer
        );
        begin
            if (pointer == TRANSACTION_FIFO_DEPTH - 1) begin
                increment_fifo_pointer = '0;
            end else begin
                increment_fifo_pointer = pointer + 1'b1;
            end
        end
    endfunction

    function automatic logic [RESULT_META_POINTER_WIDTH-1:0]
        increment_result_meta_pointer (
            input logic [RESULT_META_POINTER_WIDTH-1:0] pointer
        );
        begin
            if (pointer == RESULT_META_DEPTH - 1) begin
                increment_result_meta_pointer = '0;
            end else begin
                increment_result_meta_pointer = pointer + 1'b1;
            end
        end
    endfunction

    //==========================================================================
    // Input parser
    //==========================================================================

    typedef enum logic [4:0] {
        RX_COMMAND,
        RX_SMALL_X0_I,
        RX_SMALL_X0_Q,
        RX_SMALL_X1_I,
        RX_SMALL_X1_Q,
        RX_SMALL_X2_I,
        RX_SMALL_X2_Q,
        RX_FFT128_I,
        RX_FFT128_Q,
        RX_FFT128_BLOCKED,
        RX_DFT12_I,
        RX_DFT12_Q,
        RX_DFT12_BLOCKED,
        RX_OFDM_CAPTURE,
        RX_OFDM_BLOCKED,
        RX_TX_CAPTURE,
        RX_TX_BLOCKED
    } rx_state_t;

    rx_state_t rx_state;
    rx_state_t rx_next_state;

    logic signed [15:0] rx_small_x0_i;
    logic signed [15:0] rx_small_x0_q;
    logic signed [15:0] rx_small_x1_i;
    logic signed [15:0] rx_small_x1_q;
    logic signed [15:0] rx_small_x2_i;
    logic               rx_small_inverse;
    logic               rx_small_radix3;

    logic signed [15:0] rx_fft128_i;
    logic        [6:0]  rx_fft128_index;

    logic signed [15:0] rx_dft12_i;
    logic        [3:0]  rx_dft12_index;

    logic din_fire;
    logic fft128_input_write;
    logic fft128_block_ready;
    logic fft128_block_inverse;
    logic dft12_input_write;
    logic dft12_block_ready;

    // OFDM_RX adapter/control signals.
    logic       ofdm_capture_start;
    logic [3:0] ofdm_capture_cp_length;
    logic       ofdm_din_ready;
    logic signed [15:0] ofdm_sample_i;
    logic signed [15:0] ofdm_sample_q;
    logic        [6:0]  ofdm_sample_index;
    logic               ofdm_sample_valid;
    logic               ofdm_sample_ready;
    logic               ofdm_capture_busy;
    logic               ofdm_capture_done;
    logic               ofdm_input_write;
    logic               ofdm_fft_block_ready;
    logic               fft_mem_ready;

    logic       fft128_ofdm_active;
    logic       fft128_tx_active;
    logic       ofdm_output_start;
    logic [7:0] ofdm_rx_dout;
    logic       ofdm_rx_dout_valid;
    logic       ofdm_output_busy;
    logic       ofdm_output_done;

    // DFT-s-OFDM TX adapter/control signals.
    logic       tx_capture_start;
    logic [3:0] tx_capture_cp_length;
    logic [3:0] tx_cp_length_reg;
    logic       tx_din_ready;
    logic signed [15:0] tx_sample_i;
    logic signed [15:0] tx_sample_q;
    logic        [3:0]  tx_sample_index;
    logic               tx_sample_valid;
    logic               tx_sample_ready;
    logic               tx_capture_busy;
    logic               tx_capture_done;
    logic               tx_input_write;
    logic               tx_dft12_block_ready;
    logic               dft12_tx_active;

    logic       tx_mapper_start;
    logic [3:0] tx_mapper_source_addr;
    logic       tx_mapper_write_valid;
    logic [6:0] tx_mapper_write_addr;
    logic signed [15:0] tx_mapper_write_i;
    logic signed [15:0] tx_mapper_write_q;
    logic       tx_mapper_busy;
    logic       tx_mapper_done;
    logic       tx_ifft_block_ready;

    // Declared before continuous assignments for Icarus compatibility.
    logic       dft12_start;
    logic       dft12_done;

    logic       tx_output_start;
    logic [7:0] tx_dout;
    logic       tx_dout_valid;
    logic       tx_output_busy;
    logic       tx_output_done;

    assign din_fire = din_valid_i && din_ready_o;

    assign fft128_input_write =
        (rx_state == RX_FFT128_Q) && din_fire;

    assign dft12_input_write =
        (rx_state == RX_DFT12_Q) && din_fire;

    assign ofdm_capture_start =
        (rx_state == RX_COMMAND) && din_fire &&
        ((din == CMD_OFDM_RX_SHORT_NORMAL_CP) ||
         (din == CMD_OFDM_RX_LONG_NORMAL_CP));

    assign ofdm_capture_cp_length =
        (din == CMD_OFDM_RX_LONG_NORMAL_CP)
            ? OFDM_LONG_NORMAL_CP_LENGTH
            : OFDM_SHORT_NORMAL_CP_LENGTH;

    assign ofdm_sample_ready = fft_mem_ready;
    assign ofdm_input_write = ofdm_sample_valid && ofdm_sample_ready;

    assign tx_capture_start =
        (rx_state == RX_COMMAND) && din_fire &&
        ((din == CMD_OFDM_TX_SHORT_NORMAL_CP) ||
         (din == CMD_OFDM_TX_LONG_NORMAL_CP));

    assign tx_capture_cp_length =
        (din == CMD_OFDM_TX_LONG_NORMAL_CP)
            ? OFDM_LONG_NORMAL_CP_LENGTH
            : OFDM_SHORT_NORMAL_CP_LENGTH;

    assign tx_sample_ready = 1'b1;
    assign tx_input_write = tx_sample_valid && tx_sample_ready;

    // Start mapping only after the TX DFT12 result block is complete.  The
    // final RAM/hold writes commit on this edge, before mapping consumes them.
    assign tx_mapper_start = dft12_done && dft12_tx_active;

    //==========================================================================
    // Small-transform transaction FIFO
    //==========================================================================

    logic signed [15:0] fifo_x0_i [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x0_q [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x1_i [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x1_q [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x2_i [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x2_q [0:TRANSACTION_FIFO_DEPTH-1];
    logic               fifo_inverse [0:TRANSACTION_FIFO_DEPTH-1];
    logic               fifo_radix3 [0:TRANSACTION_FIFO_DEPTH-1];

    logic [FIFO_POINTER_WIDTH-1:0] fifo_write_pointer;
    logic [FIFO_POINTER_WIDTH-1:0] fifo_read_pointer;
    logic [FIFO_COUNT_WIDTH-1:0]   fifo_count;

    logic fifo_empty;
    logic fifo_full;
    logic fifo_push;
    logic fifo_pop;

    // Number of small-transform transactions accepted by the butterfly but not yet
    // accepted at the result interface. The elastic butterfly can hold an
    // output transaction and a following input transaction simultaneously.
    logic [2:0] small_inflight_count;
    logic       small_result_fire;

    // One metadata entry is pushed whenever a small operation is fully
    // issued to the butterfly. Results return in issue order, so the head bit
    // identifies the returning radix and whether IFFT2 /2 normalization is required.
    logic result_meta_inverse [0:RESULT_META_DEPTH-1];
    logic result_meta_radix3 [0:RESULT_META_DEPTH-1];
    logic [RESULT_META_POINTER_WIDTH-1:0] result_meta_write_pointer;
    logic [RESULT_META_POINTER_WIDTH-1:0] result_meta_read_pointer;
    logic [RESULT_META_COUNT_WIDTH-1:0]   result_meta_count;
    logic result_meta_empty;
    logic result_meta_full;
    logic result_meta_push;
    logic result_meta_pop;
    logic small_result_inverse;
    logic small_result_radix3;

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count == TRANSACTION_FIFO_DEPTH);

    assign result_meta_empty = (result_meta_count == 0);
    assign result_meta_full  = (result_meta_count == RESULT_META_DEPTH);
    assign result_meta_push  = fifo_pop;
    assign result_meta_pop   = small_result_fire;
    assign small_result_inverse =
        !result_meta_empty &&
        result_meta_inverse[result_meta_read_pointer];
    assign small_result_radix3 =
        !result_meta_empty &&
        result_meta_radix3[result_meta_read_pointer];

    assign fifo_push =
        (((rx_state == RX_SMALL_X1_Q) && !rx_small_radix3) ||
         ((rx_state == RX_SMALL_X2_Q) &&  rx_small_radix3)) &&
        din_fire;

    //==========================================================================
    // FFT128/IFFT128 scratch RAM
    //
    // Natural-order input sample n is stored at bit_reverse6(n). The iterative
    // radix-2 DIT stages then produce natural-order output bins.
    //==========================================================================

    // The physically significant 128-complex-sample store is implemented as
    // two GF180 256x8 synchronous single-port SRAM macros. Complex accesses
    // use {Q[15:0],I[15:0]}; active FFT execution owns the direct 16-bit port.
    logic        fft_mem_req;
    logic        fft_mem_write;
    logic [6:0]  fft_mem_addr;
    logic [31:0] fft_mem_wdata;
    logic [31:0] fft_mem_rdata;
    logic        fft_mem_rvalid;
    logic mod_half_req, mod_half_write, mod_half_ready, mod_half_rvalid;
    logic [7:0] mod_half_addr;
    logic [15:0] mod_half_wdata, mod_half_rdata;
    logic mod_active, mod_done, mod_inverse, mod_ofdm, mod_tx;
    logic mod_issue_valid, mod_issue_ready, mod_result_ready;
    logic signed [15:0] mod_x0_i,mod_x0_q,mod_x1_i,mod_x1_q;
    logic signed [7:0] mod_tw_re,mod_tw_im;
    logic mod_diag_valid,mod_diag_ready,mod_diag_last;
    logic signed [15:0] mod_diag_X0_i,mod_diag_X0_q,mod_diag_X1_i,mod_diag_X1_q;
    logic [6:0] mod_diag_addr0,mod_diag_addr1;

    // Output-adapter read requests share the physical FFT SRAM port.  Keep
    // these declarations ahead of the arbitration logic for Icarus.
    logic        ofdm_mem_req;
    logic [6:0]  ofdm_mem_addr;
    logic        tx_mem_req;
    logic [7:0]  tx_mem_addr;

    // Registered FFT operands/results bridge synchronous SRAM latency to the
    // existing latency-insensitive mixed-radix butterfly.
    logic signed [15:0] fft_operand0_i, fft_operand0_q;
    logic signed [15:0] fft_operand1_i, fft_operand1_q;
    logic signed [15:0] fft_result0_i, fft_result0_q;
    logic signed [15:0] fft_result1_i, fft_result1_q;

    // Hard-coded forward W128 twiddle constants. Small read-only constants stay
    // in local combinational ROM rather than consuming synchronous SRAM macros.
    logic signed [7:0] fft128_twiddle_re;
    logic signed [7:0] fft128_twiddle_im;

    //==========================================================================
    // Shared FFT128/IFFT128 folded scheduling state
    //==========================================================================

    typedef enum logic [3:0] {
        F128_IDLE,
        F128_READ0_REQ,
        F128_READ0_WAIT,
        F128_READ1_REQ,
        F128_READ1_WAIT,
        F128_PREPARE,
        F128_ISSUE,
        F128_WAIT_RESULT,
        F128_WRITE0,
        F128_WRITE1,
        F128_OUTPUT_WAIT
    } fft128_state_t;

    fft128_state_t fft128_state;

    logic       fft128_active;
    logic       fft128_start;
    logic       fft128_done;
    logic       fft128_inverse_active;
    logic [2:0] fft128_stage;
    logic [6:0] fft128_group_base;
    logic [5:0] fft128_j;
    assign fft128_active = mod_active;
    assign fft128_inverse_active = mod_inverse;
    assign fft128_ofdm_active = mod_ofdm;
    assign fft128_tx_active = mod_tx;

    logic [6:0] fft128_half_size;
    logic [7:0] fft128_group_size;
    logic [6:0] fft128_addr0;
    logic [6:0] fft128_addr1;
    logic [2:0] fft128_next_stage;
    logic [6:0] fft128_next_group_base;
    logic [5:0] fft128_next_j;
    logic [6:0] fft128_next_addr0;
    logic [6:0] fft128_next_addr1;
    logic [5:0] fft128_twiddle_index;
    logic [5:0] fft128_next_twiddle_index;
    logic [5:0] fft128_issue_twiddle_index;

    logic fft128_last_butterfly;
    logic fft128_final_stage;

    assign fft128_half_size =
        7'd1 << fft128_stage;

    assign fft128_group_size =
        8'd2 << fft128_stage;

    assign fft128_addr0 =
        fft128_group_base + fft128_j;

    assign fft128_addr1 =
        fft128_addr0 + fft128_half_size;

    // stage 0: shift 6, stage 6: shift 0
    assign fft128_twiddle_index =
        fft128_j << (6 - fft128_stage);
    assign fft128_next_twiddle_index =
        fft128_next_j << (6 - fft128_next_stage);

    assign fft128_final_stage =
        (fft128_stage == FFT_FINAL_STAGE);

    assign fft128_last_butterfly =
        fft128_final_stage &&
        (fft128_group_base == 7'd0) &&
        (fft128_j == 6'd31);

    always @* begin
        fft128_next_stage = fft128_stage;
        fft128_next_group_base = fft128_group_base;
        fft128_next_j = fft128_j + 1'b1;
        if (fft128_j == fft128_half_size - 1'b1) begin
            fft128_next_j = 6'd0;
            if (fft128_group_base + fft128_group_size >= FFT_N) begin
                fft128_next_group_base = 7'd0;
                fft128_next_stage = fft128_stage + 1'b1;
            end else begin
                fft128_next_group_base =
                    fft128_group_base + fft128_group_size[6:0];
            end
        end
        fft128_next_addr0 = fft128_next_group_base + fft128_next_j;
        fft128_next_addr1 = fft128_next_addr0 + (7'd1 << fft128_next_stage);
    end

    logic [1:0] fft128_prefetch_requests;
    logic [1:0] fft128_prefetch_responses;
    logic signed [15:0] fft128_prefetch0_i, fft128_prefetch0_q;
    logic signed [15:0] fft128_prefetch1_i, fft128_prefetch1_q;
    logic fft128_prefetch_complete;
    logic fft128_prefetch_complete_now;
    logic fft128_next_issued;

    assign fft128_prefetch_complete =
        (fft128_prefetch_responses == 2'd2);
    assign fft128_prefetch_complete_now = fft128_prefetch_complete ||
        ((fft128_prefetch_responses == 2'd1) && fft_mem_rvalid);

    fft128_twiddle_rom u_fft128_twiddle_rom (
        .addr_i (fft128_issue_twiddle_index),
        .re_o   (fft128_twiddle_re),
        .im_o   (fft128_twiddle_im)
    );

    gf180_sram_256x16_complex u_fft_scratch_sram (
        .clk     (clk),
        .rst_n   (rst_n),
        .req_i   (fft_mem_req),
        .write_i (fft_mem_write),
        .addr_i  (fft_mem_addr),
        .wdata_i (fft_mem_wdata),
        .ready_o (fft_mem_ready),
        .rdata_o (fft_mem_rdata),
        .rvalid_o(fft_mem_rvalid),
        .half_mode_i(mod_active || tx_output_busy || debug_mode_i),
        .half_req_i(mod_active ? mod_half_req :
                    (tx_output_busy ? tx_mem_req : debug_req_i)),
        // TX readout never writes.  Keep its busy/owner decode out of the
        // SRAM write-enable cone; debug writes are accepted only while idle.
        .half_write_i((mod_active && mod_half_write) ||
                      (debug_mode_i && debug_write_i)),
        .half_addr_i(mod_active ? mod_half_addr :
                     (tx_output_busy ? tx_mem_addr : debug_addr_i)),
        .half_wdata_i(mod_active ? mod_half_wdata :
                      (tx_output_busy ? 16'd0 : debug_wdata_i)),
        .half_ready_o(mod_half_ready),
        .half_rdata_o(mod_half_rdata), .half_rvalid_o(mod_half_rvalid)
`ifdef USE_POWER_PINS
        , .VDD(VDD), .VSS(VSS)
`endif
    );

    assign debug_ready_o = debug_mode_i && !mod_active && !tx_output_busy &&
                           mod_half_ready;
    assign debug_rdata_o = mod_half_rdata;
    assign debug_rvalid_o = debug_mode_i && !mod_active && !tx_output_busy &&
                            mod_half_rvalid;

    //==========================================================================
    // DFT12 Good-Thomas / prime-factor engine
    //
    // Since 3 and 4 are coprime, a 12-point DFT can be decomposed without
    // inter-stage twiddles:
    //   - four radix-3 DFTs,
    //   - three radix-4 DFTs, each realized by four radix-2 butterflies.
    // Total: 4 radix-3 + 12 radix-2 = 16 mixed-radix operations.
    //==========================================================================

    logic signed [15:0] dft12_ram_i [0:11];
    logic signed [15:0] dft12_ram_q [0:11];

    // Most natural-order TX results can reuse the in-place DFT12 RAM.  With
    // groups evaluated in order 0,1,2, only outputs 6, 9, and 10 overlap
    // intermediates that a later group still needs.  Keep just those three
    // complex values aside instead of duplicating the complete 12-word RAM.
    logic signed [15:0] tx_dft12_hold_i [0:2];
    logic signed [15:0] tx_dft12_hold_q [0:2];

    localparam logic [2:0] D12_PHASE_RADIX3      = 3'd0;
    localparam logic [2:0] D12_PHASE_FFT4_EVEN   = 3'd1;
    localparam logic [2:0] D12_PHASE_FFT4_ODD    = 3'd2;
    localparam logic [2:0] D12_PHASE_FINAL_EVEN  = 3'd3;
    localparam logic [2:0] D12_PHASE_FINAL_ODD   = 3'd4;

    typedef enum logic [1:0] {
        D12_IDLE,
        D12_PREPARE,
        D12_ISSUE,
        D12_WAIT_RESULT
    } dft12_state_t;

    dft12_state_t dft12_state;
    logic         dft12_active;
    logic [2:0]   dft12_phase;
    logic [4:0]   dft12_phase_onehot;
    logic [1:0]   dft12_group;

    logic [3:0] dft12_addr0;
    logic [3:0] dft12_addr1;
    logic [3:0] dft12_addr2;
    logic [3:0] dft12_base;
    logic       dft12_final_operation;
    logic       dft12_last_operation;
    logic [3:0] dft12_out_addr0;
    logic [3:0] dft12_out_addr1;

    assign dft12_base = {dft12_group, 2'b00};

    always @* begin
        dft12_addr0 = 4'd0;
        dft12_addr1 = 4'd0;
        dft12_addr2 = 4'd0;

        case (dft12_phase)
            D12_PHASE_RADIX3: begin
                dft12_addr0 = dft12_input_address(2'd0, dft12_group);
                dft12_addr1 = dft12_input_address(2'd1, dft12_group);
                dft12_addr2 = dft12_input_address(2'd2, dft12_group);
            end
            D12_PHASE_FFT4_EVEN: begin
                dft12_addr0 = dft12_base;
                dft12_addr1 = dft12_base + 4'd2;
            end
            D12_PHASE_FFT4_ODD: begin
                dft12_addr0 = dft12_base + 4'd1;
                dft12_addr1 = dft12_base + 4'd3;
            end
            D12_PHASE_FINAL_EVEN: begin
                dft12_addr0 = dft12_base;
                dft12_addr1 = dft12_base + 4'd1;
            end
            default: begin
                dft12_addr0 = dft12_base + 4'd2;
                dft12_addr1 = dft12_base + 4'd3;
            end
        endcase
    end

    assign dft12_final_operation =
        (dft12_phase == D12_PHASE_FINAL_EVEN) ||
        (dft12_phase == D12_PHASE_FINAL_ODD);

    assign dft12_last_operation =
        (dft12_phase == D12_PHASE_FINAL_ODD) &&
        (dft12_group == 2'd2);

    assign dft12_out_addr0 = dft12_output_address(
        dft12_group,
        (dft12_phase == D12_PHASE_FINAL_EVEN) ? 2'd0 : 2'd1
    );
    assign dft12_out_addr1 = dft12_output_address(
        dft12_group,
        (dft12_phase == D12_PHASE_FINAL_EVEN) ? 2'd2 : 2'd3
    );

    //==========================================================================
    // Shared mixed-radix butterfly interface
    //==========================================================================

    logic [1:0]         bf_uop_in;
    logic               bf_uop_valid;
    logic               bf_uop_ready;

    logic signed [15:0] bf_x0_i;
    logic               bf_x0_i_valid;
    logic               bf_x0_i_ready;
    logic signed [15:0] bf_x0_q;
    logic               bf_x0_q_valid;
    logic               bf_x0_q_ready;

    logic signed [15:0] bf_x1_i;
    logic               bf_x1_i_valid;
    logic               bf_x1_i_ready;
    logic signed [15:0] bf_x1_q;
    logic               bf_x1_q_valid;
    logic               bf_x1_q_ready;

    logic signed [15:0] bf_x2_i;
    logic               bf_x2_i_valid;
    logic               bf_x2_i_ready;
    logic signed [15:0] bf_x2_q;
    logic               bf_x2_q_valid;
    logic               bf_x2_q_ready;

    logic signed [7:0]  bf_twiddle_re;
    logic               bf_twiddle_re_valid;
    logic               bf_twiddle_re_ready;
    logic signed [7:0]  bf_twiddle_im;
    logic               bf_twiddle_im_valid;
    logic               bf_twiddle_im_ready;

    logic signed [15:0] bf_X0_i;
    logic signed [15:0] bf_X0_q;
    logic signed [15:0] bf_X1_i;
    logic signed [15:0] bf_X1_q;
    logic signed [15:0] bf_X2_i;
    logic signed [15:0] bf_X2_q;

    logic bf_out_valid;
    logic bf_out_ready;
    logic bf_result_fire;
    logic dft12_writeback_fire;

    logic small_issue_active;
    logic fft128_issue_active;
    logic fft128_overlap_issue;
    logic dft12_issue_active;

    assign small_issue_active =
        !fft128_active && !dft12_active &&
        !fifo_empty && !result_meta_full;

    // Load the next operation into the butterfly's elastic input registers
    // while the current operation is still using the scalar multiplier.  At
    // the current result-transfer edge the arithmetic stage drains and the
    // waiting operation advances without an extra issue bubble.
    assign fft128_overlap_issue = 1'b0;
    assign fft128_issue_active = fft128_active && mod_issue_valid;
    assign fft128_issue_twiddle_index = fft128_overlap_issue
        ? fft128_next_twiddle_index : fft128_twiddle_index;

    assign dft12_issue_active =
        dft12_active && (dft12_state == D12_ISSUE);

    // Data/uop mux between a queued small transform and the radix-2 operations
    // used by the folded 128-point engine.
    always @* begin
        bf_uop_in = UOP_RADIX2;
        bf_x0_i = '0;
        bf_x0_q = '0;
        bf_x1_i = '0;
        bf_x1_q = '0;
        bf_x2_i = '0;
        bf_x2_q = '0;
        bf_twiddle_re = '0;
        bf_twiddle_im = '0;

        if (fft128_issue_active) begin
            bf_uop_in = UOP_RADIX2;
            bf_x0_i=mod_x0_i; bf_x0_q=mod_x0_q;
            bf_x1_i=mod_x1_i; bf_x1_q=mod_x1_q;
            bf_twiddle_re=mod_tw_re; bf_twiddle_im=mod_tw_im;
        end else if (dft12_issue_active) begin
            if (dft12_phase == D12_PHASE_RADIX3) begin
                bf_uop_in = UOP_RADIX3;
                bf_x0_i = dft12_ram_i[dft12_addr0];
                bf_x0_q = dft12_ram_q[dft12_addr0];
                bf_x1_i = dft12_ram_i[dft12_addr1];
                bf_x1_q = dft12_ram_q[dft12_addr1];
                bf_x2_i = dft12_ram_i[dft12_addr2];
                bf_x2_q = dft12_ram_q[dft12_addr2];
                bf_twiddle_re = FFT3_COEFF_RE;
                bf_twiddle_im = FFT3_COEFF_IM;
            end else begin
                bf_uop_in = UOP_RADIX2;
                bf_x0_i = dft12_ram_i[dft12_addr0];
                bf_x0_q = dft12_ram_q[dft12_addr0];

                if (dft12_phase == D12_PHASE_FINAL_ODD) begin
                    // The second final FFT4 butterfly uses W4^1=-j.
                    bf_x1_i = dft12_ram_i[dft12_addr1];
                    bf_x1_q = dft12_ram_q[dft12_addr1];
                    bf_twiddle_re = NEG_J_RE;
                    bf_twiddle_im = NEG_J_IM;
                end else begin
                    // Exact unity through the existing Q1.7 proxy.
                    bf_x1_i = negate16(dft12_ram_i[dft12_addr1]);
                    bf_x1_q = negate16(dft12_ram_q[dft12_addr1]);
                    bf_twiddle_re = UNITY_PROXY_RE;
                    bf_twiddle_im = UNITY_PROXY_IM;
                end
            end
        end else if (small_issue_active) begin
            bf_uop_in = fifo_radix3[fifo_read_pointer]
                ? UOP_RADIX3
                : UOP_RADIX2;
            bf_x0_i = fifo_x0_i[fifo_read_pointer];
            bf_x0_q = fifo_x0_q[fifo_read_pointer];
            bf_x1_i = fifo_x1_i[fifo_read_pointer];
            bf_x1_q = fifo_x1_q[fifo_read_pointer];
            bf_x2_i = fifo_x2_i[fifo_read_pointer];
            bf_x2_q = fifo_x2_q[fifo_read_pointer];

            if (fifo_radix3[fifo_read_pointer]) begin
                bf_twiddle_re = FFT3_COEFF_RE;
                bf_twiddle_im = FFT3_COEFF_IM;
            end else begin
                bf_twiddle_re = UNITY_PROXY_RE;
                bf_twiddle_im = UNITY_PROXY_IM;
            end
        end
    end

    //==========================================================================
    // Independent small-operation issue tracking
    //==========================================================================

    logic small_sent_uop;
    logic small_sent_x0_i;
    logic small_sent_x0_q;
    logic small_sent_x1_i;
    logic small_sent_x1_q;
    logic small_sent_x2_i;
    logic small_sent_x2_q;
    logic small_sent_twiddle_re;
    logic small_sent_twiddle_im;
    logic small_issue_done_now;

    assign small_issue_done_now =
        small_issue_active &&
        (small_sent_uop        || bf_uop_ready) &&
        (small_sent_x0_i       || bf_x0_i_ready) &&
        (small_sent_x0_q       || bf_x0_q_ready) &&
        (small_sent_x1_i       || bf_x1_i_ready) &&
        (small_sent_x1_q       || bf_x1_q_ready) &&
        (!fifo_radix3[fifo_read_pointer] ||
            small_sent_x2_i || bf_x2_i_ready) &&
        (!fifo_radix3[fifo_read_pointer] ||
            small_sent_x2_q || bf_x2_q_ready) &&
        (small_sent_twiddle_re || bf_twiddle_re_ready) &&
        (small_sent_twiddle_im || bf_twiddle_im_ready);

    assign fifo_pop = small_issue_done_now;

    //==========================================================================
    // Independent DFT12 issue tracking
    //==========================================================================

    logic dft12_sent_uop;
    logic dft12_sent_x0_i;
    logic dft12_sent_x0_q;
    logic dft12_sent_x1_i;
    logic dft12_sent_x1_q;
    logic dft12_sent_x2_i;
    logic dft12_sent_x2_q;
    logic dft12_sent_twiddle_re;
    logic dft12_sent_twiddle_im;
    logic dft12_issue_done_now;

    assign dft12_issue_done_now =
        dft12_issue_active &&
        (dft12_sent_uop        || bf_uop_ready) &&
        (dft12_sent_x0_i       || bf_x0_i_ready) &&
        (dft12_sent_x0_q       || bf_x0_q_ready) &&
        (dft12_sent_x1_i       || bf_x1_i_ready) &&
        (dft12_sent_x1_q       || bf_x1_q_ready) &&
        ((dft12_phase != D12_PHASE_RADIX3) ||
            dft12_sent_x2_i || bf_x2_i_ready) &&
        ((dft12_phase != D12_PHASE_RADIX3) ||
            dft12_sent_x2_q || bf_x2_q_ready) &&
        (dft12_sent_twiddle_re || bf_twiddle_re_ready) &&
        (dft12_sent_twiddle_im || bf_twiddle_im_ready);

    //==========================================================================
    // Independent FFT128 issue tracking
    //==========================================================================

    logic fft128_sent_uop;
    logic fft128_sent_x0_i;
    logic fft128_sent_x0_q;
    logic fft128_sent_x1_i;
    logic fft128_sent_x1_q;
    logic fft128_sent_twiddle_re;
    logic fft128_sent_twiddle_im;
    logic fft128_issue_done_now;

    assign fft128_start =
        (fft128_block_ready || ofdm_fft_block_ready ||
         tx_ifft_block_ready) &&
        !mod_done &&
        !fft128_active && !dft12_active &&
        fifo_empty &&
        (small_inflight_count == 0) &&
        result_meta_empty &&
        !bf_out_valid &&
        !small_sent_uop &&
        !small_sent_x0_i &&
        !small_sent_x0_q &&
        !small_sent_x1_i &&
        !small_sent_x1_q &&
        !small_sent_x2_i &&
        !small_sent_x2_q &&
        !small_sent_twiddle_re &&
        !small_sent_twiddle_im;

    // FFT128 has priority only in the impossible/error case where both block
    // ready flags are set simultaneously.
    assign dft12_start =
        (dft12_block_ready || tx_dft12_block_ready) &&
        !fft128_block_ready && !ofdm_fft_block_ready &&
        !tx_ifft_block_ready &&
        !dft12_active && !fft128_active &&
        fifo_empty &&
        (small_inflight_count == 0) &&
        result_meta_empty &&
        !bf_out_valid &&
        !small_sent_uop &&
        !small_sent_x0_i &&
        !small_sent_x0_q &&
        !small_sent_x1_i &&
        !small_sent_x1_q &&
        !small_sent_x2_i &&
        !small_sent_x2_q &&
        !small_sent_twiddle_re &&
        !small_sent_twiddle_im;

    assign fft128_issue_done_now =
        fft128_issue_active &&
        (fft128_sent_uop        || bf_uop_ready) &&
        (fft128_sent_x0_i       || bf_x0_i_ready) &&
        (fft128_sent_x0_q       || bf_x0_q_ready) &&
        (fft128_sent_x1_i       || bf_x1_i_ready) &&
        (fft128_sent_x1_q       || bf_x1_q_ready) &&
        (fft128_sent_twiddle_re || bf_twiddle_re_ready) &&
        (fft128_sent_twiddle_im || bf_twiddle_im_ready);

    assign bf_uop_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_uop
                : (small_issue_active && !small_sent_uop));
    assign bf_x0_i_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_x0_i
                : (small_issue_active && !small_sent_x0_i));
    assign bf_x0_q_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_x0_q
                : (small_issue_active && !small_sent_x0_q));
    assign bf_x1_i_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_x1_i
                : (small_issue_active && !small_sent_x1_i));
    assign bf_x1_q_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_x1_q
                : (small_issue_active && !small_sent_x1_q));
    assign bf_x2_i_valid =
        dft12_issue_active
            ? ((dft12_phase == D12_PHASE_RADIX3) && !dft12_sent_x2_i)
            : (small_issue_active &&
               fifo_radix3[fifo_read_pointer] &&
               !small_sent_x2_i);
    assign bf_x2_q_valid =
        dft12_issue_active
            ? ((dft12_phase == D12_PHASE_RADIX3) && !dft12_sent_x2_q)
            : (small_issue_active &&
               fifo_radix3[fifo_read_pointer] &&
               !small_sent_x2_q);
    assign bf_twiddle_re_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_twiddle_re
                : (small_issue_active && !small_sent_twiddle_re));
    assign bf_twiddle_im_valid =
        fft128_issue_active
            ? mod_issue_valid
            : (dft12_issue_active
                ? !dft12_sent_twiddle_im
                : (small_issue_active && !small_sent_twiddle_im));

    //==========================================================================
    // Output routing
    //==========================================================================

    logic signed [15:0] routed_X0_i;
    logic signed [15:0] routed_X0_q;
    logic signed [15:0] routed_X1_i;
    logic signed [15:0] routed_X1_q;
    logic signed [15:0] routed_X2_i;
    logic signed [15:0] routed_X2_q;

    assign routed_X0_i =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X0_i) >>> IFFT_NORMALIZE_SHIFT)
            : ((!fft128_active && !dft12_active && small_result_inverse)
                ? ($signed(bf_X0_i) >>> 1)
                : bf_X0_i);
    assign routed_X0_q =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X0_q) >>> IFFT_NORMALIZE_SHIFT)
            : ((!fft128_active && !dft12_active && small_result_inverse)
                ? ($signed(bf_X0_q) >>> 1)
                : bf_X0_q);
    assign routed_X1_i =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X1_i) >>> IFFT_NORMALIZE_SHIFT)
            : ((!fft128_active && !dft12_active && small_result_inverse)
                ? ($signed(bf_X1_i) >>> 1)
                : bf_X1_i);
    assign routed_X1_q =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X1_q) >>> IFFT_NORMALIZE_SHIFT)
            : ((!fft128_active && !dft12_active && small_result_inverse)
                ? ($signed(bf_X1_q) >>> 1)
                : bf_X1_q);
    assign routed_X2_i = bf_X2_i;
    assign routed_X2_q = bf_X2_q;

    assign X0_i_o = fft128_active ? mod_diag_X0_i : routed_X0_i;
    assign X0_q_o = fft128_active ? mod_diag_X0_q : routed_X0_q;
    assign X1_i_o = fft128_active ? mod_diag_X1_i : routed_X1_i;
    assign X1_q_o = fft128_active ? mod_diag_X1_q : routed_X1_q;
    assign X2_i_o = routed_X2_i;
    assign X2_q_o = routed_X2_q;

    assign result_valid_o =
        fft128_active
            ? mod_diag_valid
            : (bf_out_valid &&
                (dft12_active
                    ? ((dft12_state == D12_WAIT_RESULT) &&
                       dft12_final_operation && !dft12_tx_active)
                    : !result_meta_empty));

    assign result_addr0_o = fft128_active
        ? mod_diag_addr0
        : (dft12_active
            ? {3'd0, dft12_output_address(
                dft12_group,
                (dft12_phase == D12_PHASE_FINAL_EVEN) ? 2'd0 : 2'd1)}
            : 7'd0);
    assign result_addr1_o = fft128_active
        ? mod_diag_addr1
        : (dft12_active
            ? {3'd0, dft12_output_address(
                dft12_group,
                (dft12_phase == D12_PHASE_FINAL_EVEN) ? 2'd2 : 2'd3)}
            : 7'd1);
    assign result_addr2_o =
        (!fft128_active && !dft12_active && small_result_radix3)
            ? 7'd2 : 7'd0;
    assign result_radix_o =
        (!fft128_active && !dft12_active && small_result_radix3)
            ? 2'd3 : 2'd2;
    assign result_last_o = fft128_active
        ? mod_diag_last
        : (dft12_active ? dft12_last_operation : 1'b1);

    assign bf_out_ready =
        fft128_active
            ? mod_result_ready
            : (dft12_active
                ? ((dft12_state == D12_WAIT_RESULT)
                    ? (dft12_final_operation
                        ? (dft12_tx_active ? 1'b1 : result_ready_i)
                        : 1'b1)
                    : 1'b0)
                : (result_ready_i && !result_meta_empty));

    assign bf_result_fire = bf_out_valid && bf_out_ready;
    assign dft12_writeback_fire =
        dft12_active &&
        (dft12_state == D12_WAIT_RESULT) &&
        bf_out_valid &&
        (!dft12_final_operation || dft12_tx_active);
    assign small_result_fire =
        !fft128_active && !dft12_active && bf_result_fire;

    // Completion is defined at the second SRAM write, not at butterfly
    // result capture. This guarantees the final sample is physically stored
    // before an OFDM output adapter begins reading the memory.
    assign fft128_done = mod_done;

    assign ofdm_output_start =
        fft128_done && fft128_ofdm_active && !fft128_tx_active;

    assign tx_output_start =
        fft128_done && fft128_ofdm_active && fft128_tx_active;

    assign dft12_done =
        dft12_active &&
        (dft12_state == D12_WAIT_RESULT) &&
        bf_result_fire &&
        dft12_last_operation;

    //==========================================================================
    // GF180 synchronous single-port FFT scratch-memory arbitration
    //==========================================================================
    always @* begin
        fft_mem_req   = 1'b0;
        fft_mem_write = 1'b0;
        fft_mem_addr  = 7'd0;
        fft_mem_wdata = 32'd0;

        // FFT/IFFT execution uses the direct physical half-word port above.
        // This complex-word port serves only capture/map/diagnostic adapters;
        // retaining the superseded FFT transaction mux here needlessly placed
        // its result/metadata selection in the physical SRAM timing cone.
        if (ofdm_mem_req) begin
            fft_mem_req  = fft_mem_ready;
            fft_mem_addr = ofdm_mem_addr;
        end else if (ofdm_input_write) begin
            fft_mem_req   = fft_mem_ready;
            fft_mem_write = 1'b1;
            fft_mem_addr  = bit_reverse6(ofdm_sample_index);
            fft_mem_wdata = {ofdm_sample_q, ofdm_sample_i};
        end else if (tx_mapper_write_valid) begin
            fft_mem_req   = fft_mem_ready;
            fft_mem_write = 1'b1;
            fft_mem_addr  = tx_mapper_write_addr;
            fft_mem_wdata = {tx_mapper_write_q, tx_mapper_write_i};
        end else if (fft128_input_write) begin
            fft_mem_req   = fft_mem_ready;
            fft_mem_write = 1'b1;
            fft_mem_addr  = bit_reverse6(rx_fft128_index);
            fft_mem_wdata = {sign_extend_q17(din), rx_fft128_i};
        end
    end

    //==========================================================================
    // Input parser combinational control
    //==========================================================================

    always @* begin
        rx_next_state = rx_state;
        din_ready_o   = 1'b0;

        case (rx_state)
            RX_COMMAND: begin
                din_ready_o = 1'b1;
                if (din_fire) begin
                    case (din)
                        CMD_FFT2, CMD_IFFT2, CMD_FFT3:
                            rx_next_state = RX_SMALL_X0_I;
                        CMD_FFT64, CMD_IFFT64:
                            rx_next_state = RX_FFT128_I;
                        CMD_DFT12:
                            rx_next_state = RX_DFT12_I;
                        CMD_OFDM_RX_SHORT_NORMAL_CP,
                        CMD_OFDM_RX_LONG_NORMAL_CP:
                            rx_next_state = RX_OFDM_CAPTURE;
                        CMD_OFDM_TX_SHORT_NORMAL_CP,
                        CMD_OFDM_TX_LONG_NORMAL_CP:
                            rx_next_state = RX_TX_CAPTURE;
                        default:
                            rx_next_state = RX_COMMAND;
                    endcase
                end
            end

            RX_SMALL_X0_I: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_SMALL_X0_Q;
            end
            RX_SMALL_X0_Q: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_SMALL_X1_I;
            end
            RX_SMALL_X1_I: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_SMALL_X1_Q;
            end
            RX_SMALL_X1_Q: begin
                if (rx_small_radix3)
                    din_ready_o = 1'b1;
                else
                    din_ready_o = !fifo_full || fifo_pop;

                if (din_fire) begin
                    if (rx_small_radix3)
                        rx_next_state = RX_SMALL_X2_I;
                    else
                        rx_next_state = RX_COMMAND;
                end
            end
            RX_SMALL_X2_I: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_SMALL_X2_Q;
            end
            RX_SMALL_X2_Q: begin
                din_ready_o = !fifo_full || fifo_pop;
                if (din_fire) rx_next_state = RX_COMMAND;
            end

            RX_FFT128_I: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_FFT128_Q;
            end
            RX_FFT128_Q: begin
                din_ready_o = fft_mem_ready;
                if (din_fire) begin
                    if (rx_fft128_index == 7'd63)
                        rx_next_state = RX_FFT128_BLOCKED;
                    else
                        rx_next_state = RX_FFT128_I;
                end
            end
            RX_FFT128_BLOCKED: begin
                din_ready_o = 1'b0;
                if (!fft128_block_ready && !fft128_active)
                    rx_next_state = RX_COMMAND;
            end

            RX_DFT12_I: begin
                din_ready_o = 1'b1;
                if (din_fire) rx_next_state = RX_DFT12_Q;
            end
            RX_DFT12_Q: begin
                din_ready_o = 1'b1;
                if (din_fire) begin
                    if (rx_dft12_index == 4'd11)
                        rx_next_state = RX_DFT12_BLOCKED;
                    else
                        rx_next_state = RX_DFT12_I;
                end
            end
            RX_DFT12_BLOCKED: begin
                din_ready_o = 1'b0;
                if (!dft12_block_ready && !dft12_active)
                    rx_next_state = RX_COMMAND;
            end

            RX_OFDM_CAPTURE: begin
                din_ready_o = ofdm_din_ready;
                if (ofdm_capture_done)
                    rx_next_state = RX_OFDM_BLOCKED;
            end

            RX_OFDM_BLOCKED: begin
                din_ready_o = 1'b0;
                if (ofdm_output_done)
                    rx_next_state = RX_COMMAND;
            end

            RX_TX_CAPTURE: begin
                din_ready_o = tx_din_ready;
                if (tx_capture_done)
                    rx_next_state = RX_TX_BLOCKED;
            end

            RX_TX_BLOCKED: begin
                din_ready_o = 1'b0;
                if (tx_output_done)
                    rx_next_state = RX_COMMAND;
            end

            default: begin
                rx_next_state = RX_COMMAND;
                din_ready_o = 1'b0;
            end
        endcase
    end

    //==========================================================================
    // Input parser, small-operation FIFO, metadata, and block-ready state
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_COMMAND;
            rx_small_x0_i <= '0;
            rx_small_x0_q <= '0;
            rx_small_x1_i <= '0;
            rx_small_x1_q <= '0;
            rx_small_x2_i <= '0;
            rx_small_inverse <= 1'b0;
            rx_small_radix3 <= 1'b0;

            rx_fft128_i <= '0;
            rx_fft128_index <= '0;
            fft128_block_ready <= 1'b0;
            fft128_block_inverse <= 1'b0;

            rx_dft12_i <= '0;
            rx_dft12_index <= '0;
            dft12_block_ready <= 1'b0;

            ofdm_fft_block_ready <= 1'b0;

            tx_cp_length_reg      <= OFDM_SHORT_NORMAL_CP_LENGTH;
            tx_dft12_block_ready  <= 1'b0;
            tx_ifft_block_ready   <= 1'b0;

            fifo_write_pointer <= '0;
            fifo_read_pointer <= '0;
            fifo_count <= '0;
            small_inflight_count <= '0;

            result_meta_write_pointer <= '0;
            result_meta_read_pointer <= '0;
            result_meta_count <= '0;
        end else begin
            rx_state <= rx_next_state;

            if (rx_state == RX_COMMAND && din_fire) begin
                if ((din == CMD_FFT2) || (din == CMD_IFFT2) ||
                    (din == CMD_FFT3)) begin
                    rx_small_inverse <= (din == CMD_IFFT2);
                    rx_small_radix3 <= (din == CMD_FFT3);
                end

                if ((din == CMD_FFT64) || (din == CMD_IFFT64)) begin
                    rx_fft128_index <= 7'd0;
                    fft128_block_ready <= 1'b0;
                    fft128_block_inverse <= (din == CMD_IFFT64);
                end

                if (din == CMD_DFT12) begin
                    rx_dft12_index <= 4'd0;
                    dft12_block_ready <= 1'b0;
                end

                if ((din == CMD_OFDM_RX_SHORT_NORMAL_CP) ||
                    (din == CMD_OFDM_RX_LONG_NORMAL_CP)) begin
                    ofdm_fft_block_ready <= 1'b0;
                end

                if ((din == CMD_OFDM_TX_SHORT_NORMAL_CP) ||
                    (din == CMD_OFDM_TX_LONG_NORMAL_CP)) begin
                    tx_cp_length_reg <= tx_capture_cp_length;
                    tx_dft12_block_ready <= 1'b0;
                    tx_ifft_block_ready <= 1'b0;
                end
            end

            if (rx_state == RX_SMALL_X0_I && din_fire)
                rx_small_x0_i <= sign_extend_q17(din);
            if (rx_state == RX_SMALL_X0_Q && din_fire)
                rx_small_x0_q <= sign_extend_q17(din);

            if (rx_state == RX_SMALL_X1_I && din_fire) begin
                rx_small_x1_i <= rx_small_radix3
                    ? sign_extend_q17(din)
                    : negate_q17(din);
            end
            if (rx_state == RX_SMALL_X1_Q && din_fire) begin
                rx_small_x1_q <= rx_small_radix3
                    ? sign_extend_q17(din)
                    : negate_q17(din);
            end
            if (rx_state == RX_SMALL_X2_I && din_fire)
                rx_small_x2_i <= sign_extend_q17(din);

            if (rx_state == RX_FFT128_I && din_fire)
                rx_fft128_i <= sign_extend_q17(din);
            if (rx_state == RX_DFT12_I && din_fire)
                rx_dft12_i <= sign_extend_q17(din);

            if (fft128_input_write) begin
                if (rx_fft128_index == 7'd63) begin
                    fft128_block_ready <= 1'b1;
                end else begin
                    rx_fft128_index <= rx_fft128_index + 1'b1;
                end
            end
            if (fft128_done)
                fft128_block_ready <= 1'b0;

            if (dft12_input_write) begin
                if (rx_dft12_index == 4'd11)
                    dft12_block_ready <= 1'b1;
                else
                    rx_dft12_index <= rx_dft12_index + 1'b1;
            end
            if (dft12_done)
                dft12_block_ready <= 1'b0;

            if (ofdm_capture_done)
                ofdm_fft_block_ready <= 1'b1;
            if (fft128_done && fft128_ofdm_active && !fft128_tx_active)
                ofdm_fft_block_ready <= 1'b0;

            if (tx_capture_done)
                tx_dft12_block_ready <= 1'b1;

            if (dft12_done && dft12_tx_active)
                tx_dft12_block_ready <= 1'b0;

            if (tx_mapper_done)
                tx_ifft_block_ready <= 1'b1;

            if (fft128_done && fft128_ofdm_active && fft128_tx_active)
                tx_ifft_block_ready <= 1'b0;

            if (fifo_push) begin
                fifo_x0_i[fifo_write_pointer] <= rx_small_x0_i;
                fifo_x0_q[fifo_write_pointer] <= rx_small_x0_q;
                fifo_x1_i[fifo_write_pointer] <= rx_small_x1_i;
                fifo_x1_q[fifo_write_pointer] <= rx_small_radix3
                    ? rx_small_x1_q
                    : negate_q17(din);
                fifo_x2_i[fifo_write_pointer] <= rx_small_radix3
                    ? rx_small_x2_i
                    : 16'sd0;
                fifo_x2_q[fifo_write_pointer] <= rx_small_radix3
                    ? sign_extend_q17(din)
                    : 16'sd0;
                fifo_inverse[fifo_write_pointer] <= rx_small_inverse;
                fifo_radix3[fifo_write_pointer] <= rx_small_radix3;
                fifo_write_pointer <=
                    increment_fifo_pointer(fifo_write_pointer);
            end

            if (fifo_pop)
                fifo_read_pointer <=
                    increment_fifo_pointer(fifo_read_pointer);

            case ({fifo_push, fifo_pop})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase

            if (result_meta_push) begin
                result_meta_inverse[result_meta_write_pointer] <=
                    fifo_inverse[fifo_read_pointer];
                result_meta_radix3[result_meta_write_pointer] <=
                    fifo_radix3[fifo_read_pointer];
                result_meta_write_pointer <=
                    increment_result_meta_pointer(result_meta_write_pointer);
            end
            if (result_meta_pop)
                result_meta_read_pointer <=
                    increment_result_meta_pointer(result_meta_read_pointer);

            case ({result_meta_push, result_meta_pop})
                2'b10: result_meta_count <= result_meta_count + 1'b1;
                2'b01: result_meta_count <= result_meta_count - 1'b1;
                default: result_meta_count <= result_meta_count;
            endcase

            case ({fifo_pop, small_result_fire})
                2'b10: small_inflight_count <= small_inflight_count + 1'b1;
                2'b01: small_inflight_count <= small_inflight_count - 1'b1;
                default: small_inflight_count <= small_inflight_count;
            endcase
        end
    end

    //==========================================================================
    // Local register memories only. Large FFT scratch storage is handled by
    // the GF180 SRAM controller below.
    //==========================================================================

    always @(posedge clk) begin
        if (tx_input_write) begin
            dft12_ram_i[tx_sample_index] <= tx_sample_i;
            dft12_ram_q[tx_sample_index] <= tx_sample_q;
        end else if (dft12_input_write) begin
            dft12_ram_i[rx_dft12_index] <= rx_dft12_i;
            dft12_ram_q[rx_dft12_index] <= sign_extend_q17(din);
        end else if (dft12_writeback_fire) begin
            case (1'b1)
                dft12_phase_onehot[D12_PHASE_RADIX3]: begin
                    // Store B[k1,n2] at address 4*k1+n2.
                    dft12_ram_i[{2'd0, dft12_group}] <= bf_X0_i;
                    dft12_ram_q[{2'd0, dft12_group}] <= bf_X0_q;
                    dft12_ram_i[4'd4 + dft12_group] <= bf_X1_i;
                    dft12_ram_q[4'd4 + dft12_group] <= bf_X1_q;
                    dft12_ram_i[4'd8 + dft12_group] <= bf_X2_i;
                    dft12_ram_q[4'd8 + dft12_group] <= bf_X2_q;
                end
                dft12_phase_onehot[D12_PHASE_FFT4_EVEN]: begin
                    dft12_ram_i[dft12_base] <= bf_X0_i;
                    dft12_ram_q[dft12_base] <= bf_X0_q;
                    dft12_ram_i[dft12_base + 4'd2] <= bf_X1_i;
                    dft12_ram_q[dft12_base + 4'd2] <= bf_X1_q;
                end
                dft12_phase_onehot[D12_PHASE_FFT4_ODD]: begin
                    dft12_ram_i[dft12_base + 4'd1] <= bf_X0_i;
                    dft12_ram_q[dft12_base + 4'd1] <= bf_X0_q;
                    dft12_ram_i[dft12_base + 4'd3] <= bf_X1_i;
                    dft12_ram_q[dft12_base + 4'd3] <= bf_X1_q;
                end
                default: begin
                    // Standalone DFT12 sends these downstream. DFT-s-OFDM TX
                    // stores safe outputs in-place and retains only the three
                    // values whose natural addresses are still live inputs.
                    if (dft12_tx_active) begin
                        if (dft12_out_addr0 == 4'd6) begin
                            tx_dft12_hold_i[0] <= bf_X0_i;
                            tx_dft12_hold_q[0] <= bf_X0_q;
                        end else if (dft12_out_addr0 == 4'd9) begin
                            tx_dft12_hold_i[1] <= bf_X0_i;
                            tx_dft12_hold_q[1] <= bf_X0_q;
                        end else if (dft12_out_addr0 == 4'd10) begin
                            tx_dft12_hold_i[2] <= bf_X0_i;
                            tx_dft12_hold_q[2] <= bf_X0_q;
                        end else begin
                            dft12_ram_i[dft12_out_addr0] <= bf_X0_i;
                            dft12_ram_q[dft12_out_addr0] <= bf_X0_q;
                        end

                        if (dft12_out_addr1 == 4'd6) begin
                            tx_dft12_hold_i[0] <= bf_X1_i;
                            tx_dft12_hold_q[0] <= bf_X1_q;
                        end else if (dft12_out_addr1 == 4'd9) begin
                            tx_dft12_hold_i[1] <= bf_X1_i;
                            tx_dft12_hold_q[1] <= bf_X1_q;
                        end else if (dft12_out_addr1 == 4'd10) begin
                            tx_dft12_hold_i[2] <= bf_X1_i;
                            tx_dft12_hold_q[2] <= bf_X1_q;
                        end else begin
                            dft12_ram_i[dft12_out_addr1] <= bf_X1_i;
                            dft12_ram_q[dft12_out_addr1] <= bf_X1_q;
                        end
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // Small-operation issue-sent tracking
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            small_sent_uop <= 1'b0;
            small_sent_x0_i <= 1'b0;
            small_sent_x0_q <= 1'b0;
            small_sent_x1_i <= 1'b0;
            small_sent_x1_q <= 1'b0;
            small_sent_x2_i <= 1'b0;
            small_sent_x2_q <= 1'b0;
            small_sent_twiddle_re <= 1'b0;
            small_sent_twiddle_im <= 1'b0;
        end else if (fifo_pop) begin
            small_sent_uop <= 1'b0;
            small_sent_x0_i <= 1'b0;
            small_sent_x0_q <= 1'b0;
            small_sent_x1_i <= 1'b0;
            small_sent_x1_q <= 1'b0;
            small_sent_x2_i <= 1'b0;
            small_sent_x2_q <= 1'b0;
            small_sent_twiddle_re <= 1'b0;
            small_sent_twiddle_im <= 1'b0;
        end else if (small_issue_active) begin
            if (bf_uop_valid && bf_uop_ready)
                small_sent_uop <= 1'b1;
            if (bf_x0_i_valid && bf_x0_i_ready)
                small_sent_x0_i <= 1'b1;
            if (bf_x0_q_valid && bf_x0_q_ready)
                small_sent_x0_q <= 1'b1;
            if (bf_x1_i_valid && bf_x1_i_ready)
                small_sent_x1_i <= 1'b1;
            if (bf_x1_q_valid && bf_x1_q_ready)
                small_sent_x1_q <= 1'b1;
            if (bf_x2_i_valid && bf_x2_i_ready)
                small_sent_x2_i <= 1'b1;
            if (bf_x2_q_valid && bf_x2_q_ready)
                small_sent_x2_q <= 1'b1;
            if (bf_twiddle_re_valid && bf_twiddle_re_ready)
                small_sent_twiddle_re <= 1'b1;
            if (bf_twiddle_im_valid && bf_twiddle_im_ready)
                small_sent_twiddle_im <= 1'b1;
        end
    end

    //==========================================================================
    // DFT12 control and sent tracking
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dft12_active <= 1'b0;
            dft12_tx_active <= 1'b0;
            dft12_state <= D12_IDLE;
            dft12_phase <= D12_PHASE_RADIX3;
            dft12_phase_onehot <= 5'b00001;
            dft12_group <= 2'd0;

            dft12_sent_uop <= 1'b0;
            dft12_sent_x0_i <= 1'b0;
            dft12_sent_x0_q <= 1'b0;
            dft12_sent_x1_i <= 1'b0;
            dft12_sent_x1_q <= 1'b0;
            dft12_sent_x2_i <= 1'b0;
            dft12_sent_x2_q <= 1'b0;
            dft12_sent_twiddle_re <= 1'b0;
            dft12_sent_twiddle_im <= 1'b0;
        end else begin
            // The phase is constant for many multiplier cycles.  Register its
            // one-hot decode ahead of result writeback so the 12-word register
            // RAM write mux is not fed by a same-cycle equality-decode tree.
            dft12_phase_onehot <= 5'b00001 << dft12_phase;
            if (dft12_start) begin
                dft12_active <= 1'b1;
                dft12_tx_active <= tx_dft12_block_ready;
                dft12_state <= D12_PREPARE;
                dft12_phase <= D12_PHASE_RADIX3;
                dft12_group <= 2'd0;
            end else if (dft12_active) begin
                case (dft12_state)
                    D12_PREPARE: begin
                        dft12_sent_uop <= 1'b0;
                        dft12_sent_x0_i <= 1'b0;
                        dft12_sent_x0_q <= 1'b0;
                        dft12_sent_x1_i <= 1'b0;
                        dft12_sent_x1_q <= 1'b0;
                        dft12_sent_x2_i <= 1'b0;
                        dft12_sent_x2_q <= 1'b0;
                        dft12_sent_twiddle_re <= 1'b0;
                        dft12_sent_twiddle_im <= 1'b0;
                        dft12_state <= D12_ISSUE;
                    end

                    D12_ISSUE: begin
                        if (bf_uop_valid && bf_uop_ready)
                            dft12_sent_uop <= 1'b1;
                        if (bf_x0_i_valid && bf_x0_i_ready)
                            dft12_sent_x0_i <= 1'b1;
                        if (bf_x0_q_valid && bf_x0_q_ready)
                            dft12_sent_x0_q <= 1'b1;
                        if (bf_x1_i_valid && bf_x1_i_ready)
                            dft12_sent_x1_i <= 1'b1;
                        if (bf_x1_q_valid && bf_x1_q_ready)
                            dft12_sent_x1_q <= 1'b1;
                        if (bf_x2_i_valid && bf_x2_i_ready)
                            dft12_sent_x2_i <= 1'b1;
                        if (bf_x2_q_valid && bf_x2_q_ready)
                            dft12_sent_x2_q <= 1'b1;
                        if (bf_twiddle_re_valid && bf_twiddle_re_ready)
                            dft12_sent_twiddle_re <= 1'b1;
                        if (bf_twiddle_im_valid && bf_twiddle_im_ready)
                            dft12_sent_twiddle_im <= 1'b1;

                        if (dft12_issue_done_now)
                            dft12_state <= D12_WAIT_RESULT;
                    end

                    D12_WAIT_RESULT: begin
                        if (bf_result_fire) begin
                            if (dft12_last_operation) begin
                                dft12_active <= 1'b0;
                                dft12_tx_active <= 1'b0;
                                dft12_state <= D12_IDLE;
                            end else begin
                                case (dft12_phase)
                                    D12_PHASE_RADIX3: begin
                                        if (dft12_group == 2'd3) begin
                                            dft12_group <= 2'd0;
                                            dft12_phase <= D12_PHASE_FFT4_EVEN;
                                        end else begin
                                            dft12_group <= dft12_group + 1'b1;
                                        end
                                    end
                                    D12_PHASE_FFT4_EVEN:
                                        dft12_phase <= D12_PHASE_FFT4_ODD;
                                    D12_PHASE_FFT4_ODD:
                                        dft12_phase <= D12_PHASE_FINAL_EVEN;
                                    D12_PHASE_FINAL_EVEN:
                                        dft12_phase <= D12_PHASE_FINAL_ODD;
                                    default: begin
                                        dft12_group <= dft12_group + 1'b1;
                                        dft12_phase <= D12_PHASE_FFT4_EVEN;
                                    end
                                endcase
                                dft12_state <= D12_PREPARE;
                            end
                        end
                    end

                    default: begin
                        dft12_active <= 1'b0;
                        dft12_tx_active <= 1'b0;
                        dft12_state <= D12_IDLE;
                    end
                endcase
            end
        end
    end

    //==========================================================================
    // FFT128 control and sent tracking -- synchronous single-port SRAM version
    //==========================================================================

`ifdef LEGACY_FFT_CONTROLLER
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft128_active         <= 1'b0;
            fft128_inverse_active <= 1'b0;
            fft128_ofdm_active    <= 1'b0;
            fft128_tx_active      <= 1'b0;
            fft128_state          <= F128_IDLE;
            fft128_stage          <= 3'd0;
            fft128_group_base     <= 7'd0;
            fft128_j              <= 6'd0;
            fft_operand0_i        <= '0;
            fft_operand0_q        <= '0;
            fft_operand1_i        <= '0;
            fft_operand1_q        <= '0;
            fft_result0_i         <= '0;
            fft_result0_q         <= '0;
            fft_result1_i         <= '0;
            fft_result1_q         <= '0;

            fft128_sent_uop        <= 1'b0;
            fft128_sent_x0_i       <= 1'b0;
            fft128_sent_x0_q       <= 1'b0;
            fft128_sent_x1_i       <= 1'b0;
            fft128_sent_x1_q       <= 1'b0;
            fft128_sent_twiddle_re <= 1'b0;
            fft128_sent_twiddle_im <= 1'b0;
            fft128_prefetch_requests <= 2'd0;
            fft128_prefetch_responses <= 2'd0;
            fft128_prefetch0_i <= '0;
            fft128_prefetch0_q <= '0;
            fft128_prefetch1_i <= '0;
            fft128_prefetch1_q <= '0;
            fft128_next_issued <= 1'b0;
        end else begin
            if (fft128_start) begin
                fft128_active         <= 1'b1;
                fft128_ofdm_active    <=
                    ofdm_fft_block_ready || tx_ifft_block_ready;
                fft128_tx_active      <= tx_ifft_block_ready;
                fft128_inverse_active <= tx_ifft_block_ready
                    ? 1'b1
                    : (ofdm_fft_block_ready
                        ? 1'b0
                        : fft128_block_inverse);
                fft128_state      <= F128_READ0_REQ;
                fft128_stage      <= 3'd0;
                fft128_group_base <= 7'd0;
                fft128_j          <= 6'd0;
                fft128_next_issued <= 1'b0;
            end else if (fft128_active) begin
                case (fft128_state)
                    F128_READ0_REQ: begin
                        // The SRAM accepts one request per cycle.  Request x1
                        // next cycle rather than leaving its port idle while
                        // the registered x0 response is returned.
                        if (fft_mem_ready)
                            fft128_state <= F128_READ1_REQ;
                    end

                    F128_READ1_REQ: begin
                        if (fft_mem_ready)
                            fft128_state <= F128_READ0_WAIT;
                    end

                    F128_READ0_WAIT: begin
                        if (fft_mem_rvalid) begin
                            fft_operand0_i <= $signed(fft_mem_rdata[15:0]);
                            fft_operand0_q <= $signed(fft_mem_rdata[31:16]);
                            fft128_state <= F128_READ1_WAIT;
                        end
                    end

                    F128_READ1_WAIT: begin
                        if (fft_mem_rvalid) begin
                            fft_operand1_i <= $signed(fft_mem_rdata[15:0]);
                            fft_operand1_q <= $signed(fft_mem_rdata[31:16]);
                            fft128_sent_uop        <= 1'b0;
                            fft128_sent_x0_i       <= 1'b0;
                            fft128_sent_x0_q       <= 1'b0;
                            fft128_sent_x1_i       <= 1'b0;
                            fft128_sent_x1_q       <= 1'b0;
                            fft128_sent_twiddle_re <= 1'b0;
                            fft128_sent_twiddle_im <= 1'b0;
                            fft128_state <= F128_ISSUE;
                        end
                    end

                    F128_ISSUE: begin
                        if (bf_uop_valid && bf_uop_ready)
                            fft128_sent_uop <= 1'b1;
                        if (bf_x0_i_valid && bf_x0_i_ready)
                            fft128_sent_x0_i <= 1'b1;
                        if (bf_x0_q_valid && bf_x0_q_ready)
                            fft128_sent_x0_q <= 1'b1;
                        if (bf_x1_i_valid && bf_x1_i_ready)
                            fft128_sent_x1_i <= 1'b1;
                        if (bf_x1_q_valid && bf_x1_q_ready)
                            fft128_sent_x1_q <= 1'b1;
                        if (bf_twiddle_re_valid && bf_twiddle_re_ready)
                            fft128_sent_twiddle_re <= 1'b1;
                        if (bf_twiddle_im_valid && bf_twiddle_im_ready)
                            fft128_sent_twiddle_im <= 1'b1;

                        if (fft128_issue_done_now)
                        begin
                            // The accepted transaction now lives in the
                            // butterfly. Reuse these channel trackers for the
                            // prefetched successor while this result computes.
                            fft128_sent_uop        <= 1'b0;
                            fft128_sent_x0_i       <= 1'b0;
                            fft128_sent_x0_q       <= 1'b0;
                            fft128_sent_x1_i       <= 1'b0;
                            fft128_sent_x1_q       <= 1'b0;
                            fft128_sent_twiddle_re <= 1'b0;
                            fft128_sent_twiddle_im <= 1'b0;
                            fft128_prefetch_requests <= 2'd0;
                            fft128_prefetch_responses <= 2'd0;
                            fft128_state <= F128_WAIT_RESULT;
                        end
                    end

                    F128_WAIT_RESULT: begin
                        if (!fft128_last_butterfly &&
                            (fft128_prefetch_requests < 2'd2) &&
                            fft_mem_ready)
                            fft128_prefetch_requests <=
                                fft128_prefetch_requests + 1'b1;

                        if (!fft128_last_butterfly && fft_mem_rvalid) begin
                            if (fft128_prefetch_responses == 2'd0) begin
                                fft128_prefetch0_i <=
                                    $signed(fft_mem_rdata[15:0]);
                                fft128_prefetch0_q <=
                                    $signed(fft_mem_rdata[31:16]);
                            end else begin
                                fft128_prefetch1_i <=
                                    $signed(fft_mem_rdata[15:0]);
                                fft128_prefetch1_q <=
                                    $signed(fft_mem_rdata[31:16]);
                            end
                            fft128_prefetch_responses <=
                                fft128_prefetch_responses + 1'b1;
                        end

                        if (fft128_overlap_issue) begin
                            if (bf_uop_valid && bf_uop_ready)
                                fft128_sent_uop <= 1'b1;
                            if (bf_x0_i_valid && bf_x0_i_ready)
                                fft128_sent_x0_i <= 1'b1;
                            if (bf_x0_q_valid && bf_x0_q_ready)
                                fft128_sent_x0_q <= 1'b1;
                            if (bf_x1_i_valid && bf_x1_i_ready)
                                fft128_sent_x1_i <= 1'b1;
                            if (bf_x1_q_valid && bf_x1_q_ready)
                                fft128_sent_x1_q <= 1'b1;
                            if (bf_twiddle_re_valid && bf_twiddle_re_ready)
                                fft128_sent_twiddle_re <= 1'b1;
                            if (bf_twiddle_im_valid && bf_twiddle_im_ready)
                                fft128_sent_twiddle_im <= 1'b1;
                            if (fft128_issue_done_now)
                                fft128_next_issued <= 1'b1;
                        end

                        if (bf_result_fire) begin
                            // Apply the already-established IFFT final-stage
                            // normalization before the values enter SRAM.
                            fft_result0_i <= routed_X0_i;
                            fft_result0_q <= routed_X0_q;
                            fft_result1_i <= routed_X1_i;
                            fft_result1_q <= routed_X1_q;
                            fft128_sent_uop        <= 1'b0;
                            fft128_sent_x0_i       <= 1'b0;
                            fft128_sent_x0_q       <= 1'b0;
                            fft128_sent_x1_i       <= 1'b0;
                            fft128_sent_x1_q       <= 1'b0;
                            fft128_sent_twiddle_re <= 1'b0;
                            fft128_sent_twiddle_im <= 1'b0;
                            fft128_state <= F128_WRITE1;
                        end
                    end

                    F128_WRITE1: begin
                        if (fft_mem_ready) begin
                        // Second result word writes on this edge. Standalone
                        // final-stage results are then held for serialization.
                        if (fft128_final_stage && !fft128_ofdm_active) begin
                            fft128_state <= F128_OUTPUT_WAIT;
                        end else if (fft128_last_butterfly) begin
                            fft128_active         <= 1'b0;
                            fft128_inverse_active <= 1'b0;
                            fft128_ofdm_active    <= 1'b0;
                            fft128_tx_active      <= 1'b0;
                            fft128_state          <= F128_IDLE;
                        end else begin
                            if (fft128_j == fft128_half_size - 1'b1) begin
                                fft128_j <= 6'd0;
                                if (
                                    fft128_group_base +
                                    fft128_group_size >= FFT_N
                                ) begin
                                    fft128_group_base <= 7'd0;
                                    fft128_stage <= fft128_stage + 1'b1;
                                end else begin
                                    fft128_group_base <=
                                        fft128_group_base +
                                        fft128_group_size[6:0];
                                end
                            end else begin
                                fft128_j <= fft128_j + 1'b1;
                            end
                            if (fft128_next_issued) begin
                                fft_operand0_i <= fft128_prefetch0_i;
                                fft_operand0_q <= fft128_prefetch0_q;
                                fft_operand1_i <= fft128_prefetch1_i;
                                fft_operand1_q <= fft128_prefetch1_q;
                                fft128_sent_uop        <= 1'b0;
                                fft128_sent_x0_i       <= 1'b0;
                                fft128_sent_x0_q       <= 1'b0;
                                fft128_sent_x1_i       <= 1'b0;
                                fft128_sent_x1_q       <= 1'b0;
                                fft128_sent_twiddle_re <= 1'b0;
                                fft128_sent_twiddle_im <= 1'b0;
                                fft128_prefetch_requests <= 2'd0;
                                fft128_prefetch_responses <= 2'd0;
                                fft128_next_issued <= 1'b0;
                                fft128_state <= F128_WAIT_RESULT;
                            end else begin
                                fft128_state <= F128_READ0_REQ;
                            end
                        end
                        end
                    end

                    F128_OUTPUT_WAIT: begin
                        if (result_valid_o && result_ready_i) begin
                            if (fft128_last_butterfly) begin
                                fft128_active         <= 1'b0;
                                fft128_inverse_active <= 1'b0;
                                fft128_ofdm_active    <= 1'b0;
                                fft128_tx_active      <= 1'b0;
                                fft128_state          <= F128_IDLE;
                            end else begin
                                if (fft128_j == fft128_half_size - 1'b1) begin
                                    fft128_j <= 6'd0;
                                    if (
                                        fft128_group_base +
                                        fft128_group_size >= FFT_N
                                    ) begin
                                        fft128_group_base <= 7'd0;
                                        fft128_stage <= fft128_stage + 1'b1;
                                    end else begin
                                        fft128_group_base <=
                                            fft128_group_base +
                                            fft128_group_size[6:0];
                                    end
                                end else begin
                                    fft128_j <= fft128_j + 1'b1;
                                end
                                if (fft128_prefetch_complete) begin
                                    fft_operand0_i <= fft128_prefetch0_i;
                                    fft_operand0_q <= fft128_prefetch0_q;
                                    fft_operand1_i <= fft128_prefetch1_i;
                                    fft_operand1_q <= fft128_prefetch1_q;
                                    fft128_sent_uop        <= 1'b0;
                                    fft128_sent_x0_i       <= 1'b0;
                                    fft128_sent_x0_q       <= 1'b0;
                                    fft128_sent_x1_i       <= 1'b0;
                                    fft128_sent_x1_q       <= 1'b0;
                                    fft128_sent_twiddle_re <= 1'b0;
                                    fft128_sent_twiddle_im <= 1'b0;
                                    fft128_state <= F128_ISSUE;
                                end else begin
                                    fft128_state <= F128_READ0_REQ;
                                end
                            end
                        end
                    end

                    default: begin
                        fft128_active         <= 1'b0;
                        fft128_inverse_active <= 1'b0;
                        fft128_ofdm_active    <= 1'b0;
                        fft128_tx_active      <= 1'b0;
                        fft128_state          <= F128_IDLE;
                    end
                endcase
            end
        end
    end
`endif

    //==========================================================================
    // OFDM_RX stream adapters
    //==========================================================================

    tdiq_input_cp_remove u_tdiq_input_cp_remove (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_i        (ofdm_capture_start),
        .cp_length_i    (ofdm_capture_cp_length),
        .din            (din),
        .din_valid_i    (
            (rx_state == RX_OFDM_CAPTURE) ? din_valid_i : 1'b0
        ),
        .din_ready_o    (ofdm_din_ready),
        .sample_i_o     (ofdm_sample_i),
        .sample_q_o     (ofdm_sample_q),
        .sample_index_o (ofdm_sample_index),
        .sample_valid_o (ofdm_sample_valid),
        .sample_ready_i (ofdm_sample_ready),
        .busy_o         (ofdm_capture_busy),
        .done_o         (ofdm_capture_done)
    );

    // Production RX needs natural bins 1..12 only. Standalone FFT64 uses
    // the independent result serializer and retains its complete 64-bin
    // diagnostic stream.
    fdiq_output_adapter_sram #(
        .START_SAMPLE(7'd1),
        .SAMPLE_COUNT(8'd12)
    ) u_fdiq_output_adapter (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_i      (ofdm_output_start),
        .mem_req_o    (ofdm_mem_req),
        .mem_addr_o   (ofdm_mem_addr),
        .mem_ready_i  (fft_mem_ready),
        .mem_rdata_i  (fft_mem_rdata),
        .mem_rvalid_i (fft_mem_rvalid),
        .dout          (ofdm_rx_dout),
        .dout_valid_o  (ofdm_rx_dout_valid),
        .busy_o        (ofdm_output_busy),
        .done_o        (ofdm_output_done)
    );

    subcarrier_mapper #(
        .SC_START_BIN(7'd1)
    ) u_subcarrier_mapper (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_i        (tx_mapper_start),
        .source_addr_o  (tx_mapper_source_addr),
        .source_i_i     (
            (tx_mapper_source_addr == 4'd6) ? tx_dft12_hold_i[0] :
            (tx_mapper_source_addr == 4'd9) ? tx_dft12_hold_i[1] :
            (tx_mapper_source_addr == 4'd10) ? tx_dft12_hold_i[2] :
            dft12_ram_i[tx_mapper_source_addr]
        ),
        .source_q_i     (
            (tx_mapper_source_addr == 4'd6) ? tx_dft12_hold_q[0] :
            (tx_mapper_source_addr == 4'd9) ? tx_dft12_hold_q[1] :
            (tx_mapper_source_addr == 4'd10) ? tx_dft12_hold_q[2] :
            dft12_ram_q[tx_mapper_source_addr]
        ),
        .write_valid_o  (tx_mapper_write_valid),
        .write_addr_o   (tx_mapper_write_addr),
        .write_i_o      (tx_mapper_write_i),
        .write_q_o      (tx_mapper_write_q),
        .write_ready_i  (fft_mem_ready),
        .busy_o         (tx_mapper_busy),
        .done_o         (tx_mapper_done)
    );

    fdiq_input_adapter u_fdiq_input_adapter (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_i        (tx_capture_start),
        .din            (din),
        .din_valid_i    (
            (rx_state == RX_TX_CAPTURE) ? din_valid_i : 1'b0
        ),
        .din_ready_o    (tx_din_ready),
        .sample_i_o     (tx_sample_i),
        .sample_q_o     (tx_sample_q),
        .sample_index_o (tx_sample_index),
        .sample_valid_o (tx_sample_valid),
        .sample_ready_i (tx_sample_ready),
        .busy_o         (tx_capture_busy),
        .done_o         (tx_capture_done)
    );

    tdiq_output_cp_insert_sram #(
        .BYTE_INTERVAL(TX_BYTE_INTERVAL)
    ) u_tdiq_output_cp_insert (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_i      (tx_output_start),
        .cp_length_i  (tx_cp_length_reg),
        .mem_req_o    (tx_mem_req),
        .mem_addr_o   (tx_mem_addr),
        .mem_ready_i  (mod_half_ready),
        .mem_rdata_i  (mod_half_rdata),
        .mem_rvalid_i (mod_half_rvalid),
        .dout          (tx_dout),
        .dout_valid_o  (tx_dout_valid),
        .busy_o        (tx_output_busy),
        .done_o        (tx_output_done)
    );

    assign dout = tx_dout_valid ? tx_dout : ofdm_rx_dout;
    assign dout_valid_o = tx_dout_valid || ofdm_rx_dout_valid;

    //==========================================================================
    // Mixed-radix butterfly instance
    //==========================================================================

    assign mod_issue_ready = bf_uop_ready && bf_x0_i_ready && bf_x0_q_ready &&
        bf_x1_i_ready && bf_x1_q_ready && bf_twiddle_re_ready &&
        bf_twiddle_im_ready;
    assign mod_diag_ready = result_ready_i;

    fft128_modulo_controller u_fft128_modulo_controller (
        .clk(clk),.rst_n(rst_n),.start_i(fft128_start),
        .inverse_i(tx_ifft_block_ready ? 1'b1 :
            (ofdm_fft_block_ready ? 1'b0 : fft128_block_inverse)),
        .ofdm_i(ofdm_fft_block_ready || tx_ifft_block_ready),
        .tx_i(tx_ifft_block_ready),
        .active_o(mod_active),.done_o(mod_done),.inverse_o(mod_inverse),
        .ofdm_o(mod_ofdm),.tx_o(mod_tx),
        .half_req_o(mod_half_req),.half_write_o(mod_half_write),
        .half_addr_o(mod_half_addr),.half_wdata_o(mod_half_wdata),
        .half_ready_i(mod_half_ready),.half_rdata_i(mod_half_rdata),
        .half_rvalid_i(mod_half_rvalid),
        .issue_valid_o(mod_issue_valid),.issue_ready_i(mod_issue_ready),
        .x0_i_o(mod_x0_i),.x0_q_o(mod_x0_q),
        .x1_i_o(mod_x1_i),.x1_q_o(mod_x1_q),
        .twiddle_re_o(mod_tw_re),.twiddle_im_o(mod_tw_im),
        .result_valid_i(bf_out_valid),.result_ready_o(mod_result_ready),
        .X0_i_i(bf_X0_i),.X0_q_i(bf_X0_q),
        .X1_i_i(bf_X1_i),.X1_q_i(bf_X1_q),
        .diag_valid_o(mod_diag_valid),.diag_ready_i(mod_diag_ready),
        .diag_X0_i_o(mod_diag_X0_i),.diag_X0_q_o(mod_diag_X0_q),
        .diag_X1_i_o(mod_diag_X1_i),.diag_X1_q_o(mod_diag_X1_q),
        .diag_addr0_o(mod_diag_addr0),.diag_addr1_o(mod_diag_addr1),
        .diag_last_o(mod_diag_last)
    );

    mixed_radix_butterfly #(
        .FRAC_BITS(7)
    ) u_mixed_radix_butterfly (
        .clk                (clk),
        .rst_n              (rst_n),
        .uop_in             (bf_uop_in),
        .uop_valid          (bf_uop_valid),
        .uop_ready          (bf_uop_ready),
        .x0_i               (bf_x0_i),
        .x0_i_valid         (bf_x0_i_valid),
        .x0_i_ready         (bf_x0_i_ready),
        .x0_q               (bf_x0_q),
        .x0_q_valid         (bf_x0_q_valid),
        .x0_q_ready         (bf_x0_q_ready),
        .x1_i               (bf_x1_i),
        .x1_i_valid         (bf_x1_i_valid),
        .x1_i_ready         (bf_x1_i_ready),
        .x1_q               (bf_x1_q),
        .x1_q_valid         (bf_x1_q_valid),
        .x1_q_ready         (bf_x1_q_ready),
        .x2_i               (bf_x2_i),
        .x2_i_valid         (bf_x2_i_valid),
        .x2_i_ready         (bf_x2_i_ready),
        .x2_q               (bf_x2_q),
        .x2_q_valid         (bf_x2_q_valid),
        .x2_q_ready         (bf_x2_q_ready),
        .twiddle_re         (bf_twiddle_re),
        .twiddle_re_valid   (bf_twiddle_re_valid),
        .twiddle_re_ready   (bf_twiddle_re_ready),
        .twiddle_im         (bf_twiddle_im),
        .twiddle_im_valid   (bf_twiddle_im_valid),
        .twiddle_im_ready   (bf_twiddle_im_ready),
        .X0_i               (bf_X0_i),
        .X0_q               (bf_X0_q),
        .X1_i               (bf_X1_i),
        .X1_q               (bf_X1_q),
        .X2_i               (bf_X2_i),
        .X2_q               (bf_X2_q),
        .out_valid          (bf_out_valid),
        .out_ready          (bf_out_ready)
    );

endmodule

`default_nettype wire
