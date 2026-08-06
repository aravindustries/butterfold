`timescale 1ns/1ps
`default_nettype none

module scheduler #(
    parameter integer TRANSACTION_FIFO_DEPTH = 4
) (
    input logic clk,
    input logic rst_n,

    // Input byte stream.
    // FFT2:   command, x0_i, x0_q, x1_i, x1_q
    // FFT128:  command, x[0].i, x[0].q, ... x[127].i, x[127].q
    // IFFT128: command, X[0].i, X[0].q, ... X[127].i, X[127].q
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,

    // One complete radix-2 butterfly result transaction.
    output logic signed [15:0] X0_i_o,
    output logic signed [15:0] X0_q_o,
    output logic signed [15:0] X1_i_o,
    output logic signed [15:0] X1_q_o,

    // Destination indices for the two complex outputs.
    output logic [6:0] result_addr0_o,
    output logic [6:0] result_addr1_o,
    output logic       result_last_o,

    output logic result_valid_o,
    input  logic result_ready_i
);

    //==========================================================================
    // Commands and constants
    //==========================================================================

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT128  = 8'h41;
    localparam logic [7:0] CMD_IFFT128 = 8'h42;

    // Q1.7 encodes -1 exactly but cannot encode +1 exactly. For unity
    // twiddles, the scheduler negates x1 and sends W=-1, so W*(-x1)=x1.
    localparam logic signed [7:0] UNITY_PROXY_RE = 8'sh80;
    localparam logic signed [7:0] UNITY_PROXY_IM = 8'sh00;

    localparam integer FIFO_POINTER_WIDTH =
        (TRANSACTION_FIFO_DEPTH <= 1)
            ? 1
            : $clog2(TRANSACTION_FIFO_DEPTH);

    localparam integer FIFO_COUNT_WIDTH =
        $clog2(TRANSACTION_FIFO_DEPTH + 1);

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

    function automatic logic [6:0] bit_reverse7 (
        input logic [6:0] value
    );
        begin
            bit_reverse7 = {
                value[0], value[1], value[2], value[3],
                value[4], value[5], value[6]
            };
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

    //==========================================================================
    // Input parser
    //==========================================================================

    typedef enum logic [3:0] {
        RX_COMMAND,
        RX_FFT2_X0_I,
        RX_FFT2_X0_Q,
        RX_FFT2_X1_I,
        RX_FFT2_X1_Q,
        RX_FFT128_I,
        RX_FFT128_Q,
        RX_FFT128_BLOCKED
    } rx_state_t;

    rx_state_t rx_state;
    rx_state_t rx_next_state;

    logic signed [15:0] rx_fft2_x0_i;
    logic signed [15:0] rx_fft2_x0_q;
    logic signed [15:0] rx_fft2_x1_i;

    logic signed [15:0] rx_fft128_i;
    logic        [6:0]  rx_fft128_index;

    logic din_fire;
    logic fft128_input_write;
    logic fft128_block_ready;
    logic fft128_block_inverse;

    assign din_fire = din_valid_i && din_ready_o;

    assign fft128_input_write =
        (rx_state == RX_FFT128_Q) && din_fire;

    //==========================================================================
    // FFT2 transaction FIFO
    //==========================================================================

    logic signed [15:0] fifo_x0_i [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x0_q [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x1_i [0:TRANSACTION_FIFO_DEPTH-1];
    logic signed [15:0] fifo_x1_q [0:TRANSACTION_FIFO_DEPTH-1];

    logic [FIFO_POINTER_WIDTH-1:0] fifo_write_pointer;
    logic [FIFO_POINTER_WIDTH-1:0] fifo_read_pointer;
    logic [FIFO_COUNT_WIDTH-1:0]   fifo_count;

    logic fifo_empty;
    logic fifo_full;
    logic fifo_push;
    logic fifo_pop;

    // Number of FFT2 transactions accepted by the butterfly but not yet
    // accepted at the result interface. The elastic butterfly can hold an
    // output transaction and a following input transaction simultaneously.
    logic [2:0] fft2_inflight_count;
    logic       fft2_result_fire;

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count == TRANSACTION_FIFO_DEPTH);

    assign fifo_push =
        (rx_state == RX_FFT2_X1_Q) && din_fire;

    //==========================================================================
    // FFT128/IFFT128 scratch RAM
    //
    // Natural-order input sample n is stored at bit_reverse7(n). The iterative
    // radix-2 DIT stages then produce natural-order output bins.
    //==========================================================================

    logic signed [15:0] fft_ram_i [0:127];
    logic signed [15:0] fft_ram_q [0:127];

    //==========================================================================
    // FFT128/IFFT128 twiddle ROM
    //
    // Entries contain the forward twiddles
    //     W_128^k = exp(-j*2*pi*k/128), k=0..63, in Q1.7.
    // FFT128 uses these values directly. IFFT128 conjugates them by negating
    // the imaginary component. Index zero and inverse index 32 need exact
    // proxy handling because signed Q1.7 cannot encode +1.0.
    //==========================================================================

    logic signed [7:0] twiddle_re_rom [0:63];
    logic signed [7:0] twiddle_im_rom [0:63];

    initial begin
        $readmemh("vectors/fft128_twiddle_re.hex", twiddle_re_rom);
        $readmemh("vectors/fft128_twiddle_im.hex", twiddle_im_rom);
    end

    //==========================================================================
    // Shared FFT128/IFFT128 folded scheduling state
    //==========================================================================

    typedef enum logic [1:0] {
        F128_IDLE,
        F128_PREPARE,
        F128_ISSUE,
        F128_WAIT_RESULT
    } fft128_state_t;

    fft128_state_t fft128_state;

    logic       fft128_active;
    logic       fft128_start;
    logic       fft128_done;
    logic       fft128_inverse_active;
    logic [2:0] fft128_stage;
    logic [6:0] fft128_group_base;
    logic [5:0] fft128_j;

    logic [6:0] fft128_half_size;
    logic [7:0] fft128_group_size;
    logic [6:0] fft128_addr0;
    logic [6:0] fft128_addr1;
    logic [5:0] fft128_twiddle_index;

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

    assign fft128_final_stage =
        (fft128_stage == 3'd6);

    assign fft128_last_butterfly =
        fft128_final_stage &&
        (fft128_group_base == 7'd0) &&
        (fft128_j == 6'd63);

    //==========================================================================
    // Shared butterfly interface
    //==========================================================================

    logic               bf_uop_in;
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

    logic bf_out_valid;
    logic bf_out_ready;
    logic bf_result_fire;

    logic fft2_issue_active;
    logic fft128_issue_active;

    assign fft2_issue_active =
        !fft128_active && !fifo_empty;

    assign fft128_issue_active =
        fft128_active &&
        (fft128_state == F128_ISSUE);

    assign bf_uop_in = 1'b1;

    // Data mux between queued FFT2 operations and the current FFT128 butterfly.
    always @* begin
        bf_x0_i = '0;
        bf_x0_q = '0;
        bf_x1_i = '0;
        bf_x1_q = '0;
        bf_twiddle_re = '0;
        bf_twiddle_im = '0;

        if (fft128_issue_active) begin
            bf_x0_i = fft_ram_i[fft128_addr0];
            bf_x0_q = fft_ram_q[fft128_addr0];

            if (fft128_twiddle_index == 0) begin
                // Both FFT and IFFT need W=+1 at k=0. Q1.7 cannot encode
                // +1, so send W=-1 and negate x1.
                bf_x1_i = negate16(fft_ram_i[fft128_addr1]);
                bf_x1_q = negate16(fft_ram_q[fft128_addr1]);
                bf_twiddle_re = UNITY_PROXY_RE;
                bf_twiddle_im = UNITY_PROXY_IM;
            end else if (
                fft128_inverse_active &&
                (twiddle_im_rom[fft128_twiddle_index] == 8'sh80)
            ) begin
                // Forward k=32 is -j. Its inverse conjugate is +j, whose +1
                // imaginary component is not representable in Q1.7. Use
                // (-j)*(-x1) = (+j)*x1 instead.
                bf_x1_i = negate16(fft_ram_i[fft128_addr1]);
                bf_x1_q = negate16(fft_ram_q[fft128_addr1]);
                bf_twiddle_re =
                    twiddle_re_rom[fft128_twiddle_index];
                bf_twiddle_im =
                    twiddle_im_rom[fft128_twiddle_index];
            end else begin
                bf_x1_i = fft_ram_i[fft128_addr1];
                bf_x1_q = fft_ram_q[fft128_addr1];
                bf_twiddle_re =
                    twiddle_re_rom[fft128_twiddle_index];
                bf_twiddle_im = fft128_inverse_active
                    ? negate8(twiddle_im_rom[fft128_twiddle_index])
                    : twiddle_im_rom[fft128_twiddle_index];
            end
        end else if (fft2_issue_active) begin
            bf_x0_i = fifo_x0_i[fifo_read_pointer];
            bf_x0_q = fifo_x0_q[fifo_read_pointer];
            bf_x1_i = fifo_x1_i[fifo_read_pointer];
            bf_x1_q = fifo_x1_q[fifo_read_pointer];
            bf_twiddle_re = UNITY_PROXY_RE;
            bf_twiddle_im = UNITY_PROXY_IM;
        end
    end

    //==========================================================================
    // Independent FFT2 issue tracking
    //==========================================================================

    logic fft2_sent_uop;
    logic fft2_sent_x0_i;
    logic fft2_sent_x0_q;
    logic fft2_sent_x1_i;
    logic fft2_sent_x1_q;
    logic fft2_sent_twiddle_re;
    logic fft2_sent_twiddle_im;

    logic fft2_issue_done_now;

    assign fft2_issue_done_now =
        fft2_issue_active &&
        (fft2_sent_uop        || bf_uop_ready) &&
        (fft2_sent_x0_i       || bf_x0_i_ready) &&
        (fft2_sent_x0_q       || bf_x0_q_ready) &&
        (fft2_sent_x1_i       || bf_x1_i_ready) &&
        (fft2_sent_x1_q       || bf_x1_q_ready) &&
        (fft2_sent_twiddle_re || bf_twiddle_re_ready) &&
        (fft2_sent_twiddle_im || bf_twiddle_im_ready);

    assign fifo_pop = fft2_issue_done_now;

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

    // Start only after all queued FFT2 work and any pending FFT2 output have
    // drained from the shared butterfly.
    assign fft128_start =
        fft128_block_ready &&
        !fft128_active &&
        fifo_empty &&
        (fft2_inflight_count == 0) &&
        !bf_out_valid &&
        !fft2_sent_uop &&
        !fft2_sent_x0_i &&
        !fft2_sent_x0_q &&
        !fft2_sent_x1_i &&
        !fft2_sent_x1_q &&
        !fft2_sent_twiddle_re &&
        !fft2_sent_twiddle_im;

    assign fft128_issue_done_now =
        fft128_issue_active &&
        (fft128_sent_uop        || bf_uop_ready) &&
        (fft128_sent_x0_i       || bf_x0_i_ready) &&
        (fft128_sent_x0_q       || bf_x0_q_ready) &&
        (fft128_sent_x1_i       || bf_x1_i_ready) &&
        (fft128_sent_x1_q       || bf_x1_q_ready) &&
        (fft128_sent_twiddle_re || bf_twiddle_re_ready) &&
        (fft128_sent_twiddle_im || bf_twiddle_im_ready);

    // Valid mux. Each channel remains valid until its own handshake completes.
    assign bf_uop_valid =
        fft128_issue_active
            ? !fft128_sent_uop
            : (fft2_issue_active && !fft2_sent_uop);

    assign bf_x0_i_valid =
        fft128_issue_active
            ? !fft128_sent_x0_i
            : (fft2_issue_active && !fft2_sent_x0_i);

    assign bf_x0_q_valid =
        fft128_issue_active
            ? !fft128_sent_x0_q
            : (fft2_issue_active && !fft2_sent_x0_q);

    assign bf_x1_i_valid =
        fft128_issue_active
            ? !fft128_sent_x1_i
            : (fft2_issue_active && !fft2_sent_x1_i);

    assign bf_x1_q_valid =
        fft128_issue_active
            ? !fft128_sent_x1_q
            : (fft2_issue_active && !fft2_sent_x1_q);

    assign bf_twiddle_re_valid =
        fft128_issue_active
            ? !fft128_sent_twiddle_re
            : (fft2_issue_active && !fft2_sent_twiddle_re);

    assign bf_twiddle_im_valid =
        fft128_issue_active
            ? !fft128_sent_twiddle_im
            : (fft2_issue_active && !fft2_sent_twiddle_im);

    //==========================================================================
    // Output routing
    //==========================================================================

    logic signed [15:0] routed_X0_i;
    logic signed [15:0] routed_X0_q;
    logic signed [15:0] routed_X1_i;
    logic signed [15:0] routed_X1_q;

    // The conventional IFFT includes a 1/N normalization. N=128, so the
    // final-stage IFFT results are arithmetically shifted right by seven.
    // FFT2 and FFT128 remain unscaled.
    assign routed_X0_i =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X0_i) >>> 7)
            : bf_X0_i;

    assign routed_X0_q =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X0_q) >>> 7)
            : bf_X0_q;

    assign routed_X1_i =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X1_i) >>> 7)
            : bf_X1_i;

    assign routed_X1_q =
        (fft128_active && fft128_inverse_active && fft128_final_stage)
            ? ($signed(bf_X1_q) >>> 7)
            : bf_X1_q;

    assign X0_i_o = routed_X0_i;
    assign X0_q_o = routed_X0_q;
    assign X1_i_o = routed_X1_i;
    assign X1_q_o = routed_X1_q;

    // FFT2 results are always visible. During FFT128, only final-stage results
    // are visible; intermediate stages are consumed internally and written RAM.
    assign result_valid_o =
        bf_out_valid &&
        (!fft128_active ||
         ((fft128_state == F128_WAIT_RESULT) && fft128_final_stage));

    assign result_addr0_o =
        fft128_active ? fft128_addr0 : 7'd0;

    assign result_addr1_o =
        fft128_active ? fft128_addr1 : 7'd1;

    assign result_last_o =
        fft128_active ? fft128_last_butterfly : 1'b1;

    // Intermediate FFT128 results are always accepted internally. Final-stage
    // FFT128 results and FFT2 results obey downstream backpressure.
    assign bf_out_ready =
        fft128_active
            ? ((fft128_state == F128_WAIT_RESULT)
                ? (fft128_final_stage ? result_ready_i : 1'b1)
                : 1'b0)
            : result_ready_i;

    assign bf_result_fire =
        bf_out_valid && bf_out_ready;

    assign fft2_result_fire =
        !fft128_active && bf_result_fire;

    assign fft128_done =
        fft128_active &&
        (fft128_state == F128_WAIT_RESULT) &&
        bf_result_fire &&
        fft128_last_butterfly;

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
                        CMD_FFT2:
                            rx_next_state = RX_FFT2_X0_I;

                        CMD_FFT128,
                        CMD_IFFT128:
                            rx_next_state = RX_FFT128_I;

                        default:
                            rx_next_state = RX_COMMAND;
                    endcase
                end
            end

            RX_FFT2_X0_I: begin
                din_ready_o = 1'b1;
                if (din_fire)
                    rx_next_state = RX_FFT2_X0_Q;
            end

            RX_FFT2_X0_Q: begin
                din_ready_o = 1'b1;
                if (din_fire)
                    rx_next_state = RX_FFT2_X1_I;
            end

            RX_FFT2_X1_I: begin
                din_ready_o = 1'b1;
                if (din_fire)
                    rx_next_state = RX_FFT2_X1_Q;
            end

            RX_FFT2_X1_Q: begin
                din_ready_o = !fifo_full || fifo_pop;
                if (din_fire)
                    rx_next_state = RX_COMMAND;
            end

            RX_FFT128_I: begin
                din_ready_o = 1'b1;
                if (din_fire)
                    rx_next_state = RX_FFT128_Q;
            end

            RX_FFT128_Q: begin
                din_ready_o = 1'b1;
                if (din_fire) begin
                    if (rx_fft128_index == 7'd127)
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

            default: begin
                rx_next_state = RX_COMMAND;
                din_ready_o   = 1'b0;
            end
        endcase
    end

    //==========================================================================
    // Input parser, FFT2 FIFO, and FFT128 block-ready flag
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_COMMAND;

            rx_fft2_x0_i <= '0;
            rx_fft2_x0_q <= '0;
            rx_fft2_x1_i <= '0;

            rx_fft128_i     <= '0;
            rx_fft128_index <= '0;
            fft128_block_ready   <= 1'b0;
            fft128_block_inverse <= 1'b0;

            fifo_write_pointer <= '0;
            fifo_read_pointer  <= '0;
            fifo_count         <= '0;
            fft2_inflight_count <= '0;
        end else begin
            rx_state <= rx_next_state;

            if (
                rx_state == RX_COMMAND &&
                din_fire &&
                ((din == CMD_FFT128) || (din == CMD_IFFT128))
            ) begin
                rx_fft128_index    <= 7'd0;
                fft128_block_ready <= 1'b0;
                fft128_block_inverse <= (din == CMD_IFFT128);
            end

            if (rx_state == RX_FFT2_X0_I && din_fire)
                rx_fft2_x0_i <= sign_extend_q17(din);

            if (rx_state == RX_FFT2_X0_Q && din_fire)
                rx_fft2_x0_q <= sign_extend_q17(din);

            // FFT2 unity proxy: store -x1 and send W=-1.
            if (rx_state == RX_FFT2_X1_I && din_fire)
                rx_fft2_x1_i <= negate_q17(din);

            if (rx_state == RX_FFT128_I && din_fire)
                rx_fft128_i <= sign_extend_q17(din);

            if (fft128_input_write) begin
                if (rx_fft128_index == 7'd127) begin
                    fft128_block_ready <= 1'b1;
                end else begin
                    rx_fft128_index <= rx_fft128_index + 1'b1;
                end
            end

            if (fft128_done)
                fft128_block_ready <= 1'b0;

            if (fifo_push) begin
                fifo_x0_i[fifo_write_pointer] <= rx_fft2_x0_i;
                fifo_x0_q[fifo_write_pointer] <= rx_fft2_x0_q;
                fifo_x1_i[fifo_write_pointer] <= rx_fft2_x1_i;
                fifo_x1_q[fifo_write_pointer] <= negate_q17(din);
                fifo_write_pointer <=
                    increment_fifo_pointer(fifo_write_pointer);
            end

            if (fifo_pop) begin
                fifo_read_pointer <=
                    increment_fifo_pointer(fifo_read_pointer);
            end

            case ({fifo_push, fifo_pop})
                2'b10:
                    fifo_count <= fifo_count + 1'b1;

                2'b01:
                    fifo_count <= fifo_count - 1'b1;

                default:
                    fifo_count <= fifo_count;
            endcase

            // Track issued-but-not-yet-consumed FFT2 operations so FFT128
            // cannot take ownership of the butterfly while an FFT2 operation
            // is still in its input or output elastic buffer.
            case ({fifo_pop, fft2_result_fire})
                2'b10:
                    fft2_inflight_count <= fft2_inflight_count + 1'b1;

                2'b01:
                    fft2_inflight_count <= fft2_inflight_count - 1'b1;

                default:
                    fft2_inflight_count <= fft2_inflight_count;
            endcase
        end
    end

    //==========================================================================
    // Single-port behavioral scratch-RAM writes
    //==========================================================================

    always @(posedge clk) begin
        if (fft128_input_write) begin
            fft_ram_i[bit_reverse7(rx_fft128_index)] <= rx_fft128_i;
            fft_ram_q[bit_reverse7(rx_fft128_index)] <=
                sign_extend_q17(din);
        end else if (
            fft128_active &&
            (fft128_state == F128_WAIT_RESULT) &&
            bf_result_fire
        ) begin
            fft_ram_i[fft128_addr0] <= routed_X0_i;
            fft_ram_q[fft128_addr0] <= routed_X0_q;
            fft_ram_i[fft128_addr1] <= routed_X1_i;
            fft_ram_q[fft128_addr1] <= routed_X1_q;
        end
    end

    //==========================================================================
    // FFT2 issue-sent tracking
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft2_sent_uop        <= 1'b0;
            fft2_sent_x0_i       <= 1'b0;
            fft2_sent_x0_q       <= 1'b0;
            fft2_sent_x1_i       <= 1'b0;
            fft2_sent_x1_q       <= 1'b0;
            fft2_sent_twiddle_re <= 1'b0;
            fft2_sent_twiddle_im <= 1'b0;
        end else if (fifo_pop) begin
            fft2_sent_uop        <= 1'b0;
            fft2_sent_x0_i       <= 1'b0;
            fft2_sent_x0_q       <= 1'b0;
            fft2_sent_x1_i       <= 1'b0;
            fft2_sent_x1_q       <= 1'b0;
            fft2_sent_twiddle_re <= 1'b0;
            fft2_sent_twiddle_im <= 1'b0;
        end else if (fft2_issue_active) begin
            if (bf_uop_valid && bf_uop_ready)
                fft2_sent_uop <= 1'b1;
            if (bf_x0_i_valid && bf_x0_i_ready)
                fft2_sent_x0_i <= 1'b1;
            if (bf_x0_q_valid && bf_x0_q_ready)
                fft2_sent_x0_q <= 1'b1;
            if (bf_x1_i_valid && bf_x1_i_ready)
                fft2_sent_x1_i <= 1'b1;
            if (bf_x1_q_valid && bf_x1_q_ready)
                fft2_sent_x1_q <= 1'b1;
            if (bf_twiddle_re_valid && bf_twiddle_re_ready)
                fft2_sent_twiddle_re <= 1'b1;
            if (bf_twiddle_im_valid && bf_twiddle_im_ready)
                fft2_sent_twiddle_im <= 1'b1;
        end
    end

    //==========================================================================
    // FFT128 control and sent tracking
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft128_active         <= 1'b0;
            fft128_inverse_active <= 1'b0;
            fft128_state          <= F128_IDLE;
            fft128_stage      <= 3'd0;
            fft128_group_base <= 7'd0;
            fft128_j          <= 6'd0;

            fft128_sent_uop        <= 1'b0;
            fft128_sent_x0_i       <= 1'b0;
            fft128_sent_x0_q       <= 1'b0;
            fft128_sent_x1_i       <= 1'b0;
            fft128_sent_x1_q       <= 1'b0;
            fft128_sent_twiddle_re <= 1'b0;
            fft128_sent_twiddle_im <= 1'b0;
        end else begin
            if (fft128_start) begin
                fft128_active         <= 1'b1;
                fft128_inverse_active <= fft128_block_inverse;
                fft128_state          <= F128_PREPARE;
                fft128_stage      <= 3'd0;
                fft128_group_base <= 7'd0;
                fft128_j          <= 6'd0;
            end else if (fft128_active) begin
                case (fft128_state)
                    F128_PREPARE: begin
                        fft128_sent_uop        <= 1'b0;
                        fft128_sent_x0_i       <= 1'b0;
                        fft128_sent_x0_q       <= 1'b0;
                        fft128_sent_x1_i       <= 1'b0;
                        fft128_sent_x1_q       <= 1'b0;
                        fft128_sent_twiddle_re <= 1'b0;
                        fft128_sent_twiddle_im <= 1'b0;
                        fft128_state <= F128_ISSUE;
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
                            fft128_state <= F128_WAIT_RESULT;
                    end

                    F128_WAIT_RESULT: begin
                        if (bf_result_fire) begin
                            if (fft128_last_butterfly) begin
                                fft128_active         <= 1'b0;
                                fft128_inverse_active <= 1'b0;
                                fft128_state          <= F128_IDLE;
                            end else begin
                                if (fft128_j == fft128_half_size - 1'b1) begin
                                    fft128_j <= 6'd0;

                                    if (
                                        fft128_group_base +
                                        fft128_group_size >= 8'd128
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

                                fft128_state <= F128_PREPARE;
                            end
                        end
                    end

                    default: begin
                        fft128_active         <= 1'b0;
                        fft128_inverse_active <= 1'b0;
                        fft128_state          <= F128_IDLE;
                    end
                endcase
            end
        end
    end

    //==========================================================================
    // Butterfly instance
    //==========================================================================

    two_point_dft #(
        .FRAC_BITS(7)
    ) u_two_point_dft (
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

        .out_valid          (bf_out_valid),
        .out_ready          (bf_out_ready)
    );

endmodule

`default_nettype wire
