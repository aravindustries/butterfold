`timescale 1ns/1ps
`default_nettype wire

module scheduler (
    input  logic       clk,
    input  logic       rst_n,

    // Input byte stream
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_i,

    // Output byte stream
    output logic [7:0] dout,
    output logic       dout_valid_o,
    input  logic       dout_ready_i
);

    //==========================================================================
    // Commands
    //==========================================================================

    localparam logic [7:0] CMD_FFT2 = 8'h40;

    /*
     * FFT2 requires W_2^0 = +1 + j0.
     *
     * Signed Q1.7 cannot represent +1 exactly, but it can represent -1
     * exactly as 8'sh80.
     *
     * Therefore, this scheduler sends:
     *
     *     twiddle = -1
     *     butterfly x1 input = -original_x1
     *
     * so that:
     *
     *     (-1) * (-original_x1) = original_x1
     *
     * This produces an exact FFT2 using the existing Q1.7 twiddle interface.
     */
    localparam logic signed [7:0] FFT2_TWIDDLE_RE = 8'sh80;
    localparam logic signed [7:0] FFT2_TWIDDLE_IM = 8'sh00;

    //==========================================================================
    // Scheduler states
    //==========================================================================

    typedef enum logic [3:0] {
        ST_COMMAND,
        ST_RX_X0_I,
        ST_RX_X0_Q,
        ST_RX_X1_I,
        ST_RX_X1_Q,
        ST_ISSUE,
        ST_WAIT_RESULT,
        ST_TX_RESULT
    } state_t;

    state_t current_state;
    state_t next_state;

    //==========================================================================
    // Captured FFT2 operands
    //
    // All stored values are signed 16-bit values with seven fractional bits.
    //==========================================================================

    logic signed [15:0] x0_i_operand;
    logic signed [15:0] x0_q_operand;
    logic signed [15:0] x1_i_operand;
    logic signed [15:0] x1_q_operand;

    //==========================================================================
    // Butterfly input interface
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

    //==========================================================================
    // Butterfly output interface
    //==========================================================================

    logic signed [15:0] bf_X0_i;
    logic signed [15:0] bf_X0_q;
    logic signed [15:0] bf_X1_i;
    logic signed [15:0] bf_X1_q;

    logic bf_out_valid;
    logic bf_out_ready;

    //==========================================================================
    // Per-input pending flags
    //
    // The two_point_dft inputs are independent latency-insensitive channels.
    // Each valid signal must remain asserted until its own handshake occurs.
    //==========================================================================

    logic uop_pending;

    logic x0_i_pending;
    logic x0_q_pending;
    logic x1_i_pending;
    logic x1_q_pending;

    logic twiddle_re_pending;
    logic twiddle_im_pending;

    logic issue_complete_now;

    //==========================================================================
    // Captured output transaction
    //==========================================================================

    logic signed [15:0] X0_i_result;
    logic signed [15:0] X0_q_result;
    logic signed [15:0] X1_i_result;
    logic signed [15:0] X1_q_result;

    /*
     * Four 16-bit components produce eight output bytes.
     */
    logic [2:0] tx_byte_index;

    //==========================================================================
    // Stream handshakes
    //==========================================================================

    logic din_fire;
    logic dout_fire;
    logic bf_result_fire;

    assign din_fire =
        din_valid_i && din_ready_i;

    assign dout_fire =
        dout_valid_o && dout_ready_i;

    assign bf_result_fire =
        bf_out_valid && bf_out_ready;

    //==========================================================================
    // Fixed-point conversion functions
    //==========================================================================

    /*
     * Convert one signed 8-bit Q1.7 input byte into a signed 16-bit value
     * while keeping seven fractional bits.
     */
    function automatic logic signed [15:0] sign_extend_q17 (
        input logic [7:0] value
    );
        begin
            sign_extend_q17 = $signed({
                {8{value[7]}},
                value
            });
        end
    endfunction

    /*
     * Sign-extend and negate an input byte.
     *
     * FFT2 uses this for x1 because the scheduler drives an exact -1
     * twiddle instead of an unrepresentable +1 twiddle.
     */
    function automatic logic signed [15:0] negate_q17 (
        input logic [7:0] value
    );
        logic signed [15:0] extended_value;

        begin
            extended_value = $signed({
                {8{value[7]}},
                value
            });

            negate_q17 = -extended_value;
        end
    endfunction

    //==========================================================================
    // Drive butterfly operand values
    //==========================================================================

    /*
     * uop == 1 selects the currently implemented radix-2 butterfly.
     */
    assign bf_uop_in = 1'b1;

    assign bf_x0_i = x0_i_operand;
    assign bf_x0_q = x0_q_operand;

    /*
     * These registers contain the negated original x1 components.
     */
    assign bf_x1_i = x1_i_operand;
    assign bf_x1_q = x1_q_operand;

    assign bf_twiddle_re = FFT2_TWIDDLE_RE;
    assign bf_twiddle_im = FFT2_TWIDDLE_IM;

    //==========================================================================
    // Detect completion of all independent butterfly-input handshakes
    //==========================================================================

    /*
     * In ST_ISSUE, every butterfly valid is equal to its pending flag.
     *
     * A channel is finished after this cycle when either:
     *
     * 1. It was accepted previously, so pending == 0, or
     * 2. It is pending and ready is asserted this cycle.
     */
    always_comb begin
        issue_complete_now =
            (!uop_pending       || bf_uop_ready)       &&
            (!x0_i_pending      || bf_x0_i_ready)      &&
            (!x0_q_pending      || bf_x0_q_ready)      &&
            (!x1_i_pending      || bf_x1_i_ready)      &&
            (!x1_q_pending      || bf_x1_q_ready)      &&
            (!twiddle_re_pending || bf_twiddle_re_ready) &&
            (!twiddle_im_pending || bf_twiddle_im_ready);
    end

    //==========================================================================
    // Next-state and output logic
    //==========================================================================

    always_comb begin
        //----------------------------------------------------------------------
        // Defaults
        //----------------------------------------------------------------------

        next_state = current_state;

        din_ready_i = 1'b0;

        dout         = 8'h00;
        dout_valid_o = 1'b0;

        bf_uop_valid        = 1'b0;
        bf_x0_i_valid       = 1'b0;
        bf_x0_q_valid       = 1'b0;
        bf_x1_i_valid       = 1'b0;
        bf_x1_q_valid       = 1'b0;
        bf_twiddle_re_valid = 1'b0;
        bf_twiddle_im_valid = 1'b0;

        bf_out_ready = 1'b0;

        //----------------------------------------------------------------------
        // Scheduler FSM
        //----------------------------------------------------------------------

        case (current_state)

            //------------------------------------------------------------------
            // Wait for a command byte
            //------------------------------------------------------------------

            ST_COMMAND: begin
                din_ready_i = 1'b1;

                if (din_fire) begin
                    if (din == CMD_FFT2) begin
                        next_state = ST_RX_X0_I;
                    end else begin
                        /*
                         * Unsupported commands are consumed and ignored.
                         */
                        next_state = ST_COMMAND;
                    end
                end
            end

            //------------------------------------------------------------------
            // Receive x0 = x0_i + j*x0_q
            //------------------------------------------------------------------

            ST_RX_X0_I: begin
                din_ready_i = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X0_Q;
                end
            end

            ST_RX_X0_Q: begin
                din_ready_i = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X1_I;
                end
            end

            //------------------------------------------------------------------
            // Receive x1 = x1_i + j*x1_q
            //------------------------------------------------------------------

            ST_RX_X1_I: begin
                din_ready_i = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X1_Q;
                end
            end

            ST_RX_X1_Q: begin
                din_ready_i = 1'b1;

                if (din_fire) begin
                    next_state = ST_ISSUE;
                end
            end

            //------------------------------------------------------------------
            // Send all independent operands to two_point_dft
            //------------------------------------------------------------------

            ST_ISSUE: begin
                /*
                 * Each valid remains asserted until that specific channel
                 * completes its valid/ready handshake.
                 */
                bf_uop_valid        = uop_pending;
                bf_x0_i_valid       = x0_i_pending;
                bf_x0_q_valid       = x0_q_pending;
                bf_x1_i_valid       = x1_i_pending;
                bf_x1_q_valid       = x1_q_pending;
                bf_twiddle_re_valid = twiddle_re_pending;
                bf_twiddle_im_valid = twiddle_im_pending;

                /*
                 * All remaining channels either completed previously or will
                 * handshake during the current cycle.
                 */
                if (issue_complete_now) begin
                    next_state = ST_WAIT_RESULT;
                end
            end

            //------------------------------------------------------------------
            // Wait for and capture one atomic butterfly result
            //------------------------------------------------------------------

            ST_WAIT_RESULT: begin
                /*
                 * The scheduler has an empty result buffer in this state, so
                 * it can accept the butterfly result.
                 */
                bf_out_ready = 1'b1;

                if (bf_result_fire) begin
                    next_state = ST_TX_RESULT;
                end
            end

            //------------------------------------------------------------------
            // Serialize the four 16-bit complex components
            //------------------------------------------------------------------

            ST_TX_RESULT: begin
                dout_valid_o = 1'b1;

                /*
                 * Little-endian output order:
                 *
                 * byte 0: X0_i[7:0]
                 * byte 1: X0_i[15:8]
                 * byte 2: X0_q[7:0]
                 * byte 3: X0_q[15:8]
                 * byte 4: X1_i[7:0]
                 * byte 5: X1_i[15:8]
                 * byte 6: X1_q[7:0]
                 * byte 7: X1_q[15:8]
                 */
                case (tx_byte_index)
                    3'd0: dout = X0_i_result[7:0];
                    3'd1: dout = X0_i_result[15:8];

                    3'd2: dout = X0_q_result[7:0];
                    3'd3: dout = X0_q_result[15:8];

                    3'd4: dout = X1_i_result[7:0];
                    3'd5: dout = X1_i_result[15:8];

                    3'd6: dout = X1_q_result[7:0];
                    3'd7: dout = X1_q_result[15:8];

                    default: dout = 8'h00;
                endcase

                if (dout_fire && tx_byte_index == 3'd7) begin
                    next_state = ST_COMMAND;
                end
            end

            default: begin
                next_state = ST_COMMAND;
            end

        endcase
    end

    //==========================================================================
    // Sequential state and storage
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_COMMAND;

            x0_i_operand <= '0;
            x0_q_operand <= '0;
            x1_i_operand <= '0;
            x1_q_operand <= '0;

            uop_pending        <= 1'b0;
            x0_i_pending       <= 1'b0;
            x0_q_pending       <= 1'b0;
            x1_i_pending       <= 1'b0;
            x1_q_pending       <= 1'b0;
            twiddle_re_pending <= 1'b0;
            twiddle_im_pending <= 1'b0;

            X0_i_result <= '0;
            X0_q_result <= '0;
            X1_i_result <= '0;
            X1_q_result <= '0;

            tx_byte_index <= 3'd0;
        end else begin
            current_state <= next_state;

            //------------------------------------------------------------------
            // Capture the interleaved input components
            //------------------------------------------------------------------

            if (current_state == ST_RX_X0_I && din_fire) begin
                x0_i_operand <= sign_extend_q17(din);
            end

            if (current_state == ST_RX_X0_Q && din_fire) begin
                x0_q_operand <= sign_extend_q17(din);
            end

            /*
             * Store negative x1 so that an exact Q1.7 twiddle of -1 produces
             * the required FFT2 multiplication by +1.
             */
            if (current_state == ST_RX_X1_I && din_fire) begin
                x1_i_operand <= negate_q17(din);
            end

            if (current_state == ST_RX_X1_Q && din_fire) begin
                x1_q_operand <= negate_q17(din);

                /*
                 * The final input byte has arrived. Mark all seven butterfly
                 * input channels as pending.
                 */
                uop_pending        <= 1'b1;
                x0_i_pending       <= 1'b1;
                x0_q_pending       <= 1'b1;
                x1_i_pending       <= 1'b1;
                x1_q_pending       <= 1'b1;
                twiddle_re_pending <= 1'b1;
                twiddle_im_pending <= 1'b1;
            end

            //------------------------------------------------------------------
            // Clear each pending bit only after its own handshake
            //------------------------------------------------------------------

            if (current_state == ST_ISSUE) begin
                if (uop_pending && bf_uop_ready) begin
                    uop_pending <= 1'b0;
                end

                if (x0_i_pending && bf_x0_i_ready) begin
                    x0_i_pending <= 1'b0;
                end

                if (x0_q_pending && bf_x0_q_ready) begin
                    x0_q_pending <= 1'b0;
                end

                if (x1_i_pending && bf_x1_i_ready) begin
                    x1_i_pending <= 1'b0;
                end

                if (x1_q_pending && bf_x1_q_ready) begin
                    x1_q_pending <= 1'b0;
                end

                if (twiddle_re_pending && bf_twiddle_re_ready) begin
                    twiddle_re_pending <= 1'b0;
                end

                if (twiddle_im_pending && bf_twiddle_im_ready) begin
                    twiddle_im_pending <= 1'b0;
                end
            end

            //------------------------------------------------------------------
            // Capture all four outputs atomically
            //------------------------------------------------------------------

            if (current_state == ST_WAIT_RESULT && bf_result_fire) begin
                X0_i_result <= bf_X0_i;
                X0_q_result <= bf_X0_q;
                X1_i_result <= bf_X1_i;
                X1_q_result <= bf_X1_q;

                tx_byte_index <= 3'd0;
            end

            //------------------------------------------------------------------
            // Advance output serializer only after valid/ready handshake
            //------------------------------------------------------------------

            if (current_state == ST_TX_RESULT && dout_fire) begin
                if (tx_byte_index == 3'd7) begin
                    tx_byte_index <= 3'd0;
                end else begin
                    tx_byte_index <= tx_byte_index + 3'd1;
                end
            end
        end
    end

    //==========================================================================
    // Radix-2 butterfly instance
    //==========================================================================

    two_point_dft u_two_point_dft (
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

