`timescale 1ns/1ps
`default_nettype none

module scheduler (
    input logic clk,
    input logic rst_n,

    // Byte-stream input:
    // command, x0_i, x0_q, x1_i, x1_q
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,

    // Parallel butterfly result
    output logic signed [15:0] X0_i_o,
    output logic signed [15:0] X0_q_o,
    output logic signed [15:0] X1_i_o,
    output logic signed [15:0] X1_q_o,

    output logic result_valid_o,
    input  logic result_ready_i
);

    //==========================================================================
    // Commands
    //==========================================================================

    localparam logic [7:0] CMD_FFT2 = 8'h40;

    /*
     * FFT2 requires W_2^0 = +1 + j0.
     *
     * Since signed Q1.7 cannot represent +1 exactly, the scheduler sends:
     *
     *     W  = -1
     *     x1 = -original_x1
     *
     * Therefore:
     *
     *     W*x1 = (-1)*(-original_x1) = original_x1
     */
    localparam logic signed [7:0] FFT2_TWIDDLE_RE = 8'sh80;
    localparam logic signed [7:0] FFT2_TWIDDLE_IM = 8'sh00;

    //==========================================================================
    // Scheduler states
    //==========================================================================

    typedef enum logic [2:0] {
        ST_COMMAND,
        ST_RX_X0_I,
        ST_RX_X0_Q,
        ST_RX_X1_I,
        ST_RX_X1_Q,
        ST_ISSUE,
        ST_WAIT_RESULT
    } state_t;

    state_t current_state;
    state_t next_state;

    //==========================================================================
    // Captured input operands
    //
    // These are signed 16-bit values with seven fractional bits.
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
    // Pending flags for independent butterfly inputs
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
    // Handshake events
    //==========================================================================

    logic din_fire;
    logic result_fire;

    assign din_fire =
        din_valid_i && din_ready_o;

    assign result_fire =
        result_valid_o && result_ready_i;

    //==========================================================================
    // Fixed-point conversion functions
    //==========================================================================

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
    // Drive fixed butterfly operand values
    //==========================================================================

    /*
     * uop == 1 selects the radix-2 operation.
     */
    assign bf_uop_in = 1'b1;

    assign bf_x0_i = x0_i_operand;
    assign bf_x0_q = x0_q_operand;

    /*
     * These operands contain -original_x1.
     */
    assign bf_x1_i = x1_i_operand;
    assign bf_x1_q = x1_q_operand;

    assign bf_twiddle_re = FFT2_TWIDDLE_RE;
    assign bf_twiddle_im = FFT2_TWIDDLE_IM;

    //==========================================================================
    // Parallel output connection
    //==========================================================================

    /*
     * The butterfly itself already contains an output buffer. Therefore the
     * scheduler does not need another set of result registers.
     *
     * All four values are one atomic transaction.
     */
    assign X0_i_o = bf_X0_i;
    assign X0_q_o = bf_X0_q;
    assign X1_i_o = bf_X1_i;
    assign X1_q_o = bf_X1_q;

    /*
     * Only expose the butterfly result while the scheduler is waiting for it.
     */
    assign result_valid_o =
        (current_state == ST_WAIT_RESULT) &&
        bf_out_valid;

    /*
     * Downstream backpressure is passed directly into the butterfly output
     * buffer.
     */
    assign bf_out_ready =
        (current_state == ST_WAIT_RESULT) &&
        result_ready_i;

    //==========================================================================
    // Detect completion of independent input handshakes
    //==========================================================================

    /*
     * A channel is complete after the current cycle when:
     *
     * 1. Its pending bit was already cleared, or
     * 2. Its ready signal is asserted and it will handshake this cycle.
     */
    assign issue_complete_now =
        (!uop_pending         || bf_uop_ready)        &&
        (!x0_i_pending        || bf_x0_i_ready)       &&
        (!x0_q_pending        || bf_x0_q_ready)       &&
        (!x1_i_pending        || bf_x1_i_ready)       &&
        (!x1_q_pending        || bf_x1_q_ready)       &&
        (!twiddle_re_pending  || bf_twiddle_re_ready) &&
        (!twiddle_im_pending  || bf_twiddle_im_ready);

    //==========================================================================
    // Combinational scheduler control
    //
    // always @* is used instead of always_comb for better Icarus support.
    //==========================================================================

    always @* begin
        //----------------------------------------------------------------------
        // Defaults
        //----------------------------------------------------------------------

        next_state = current_state;

        din_ready_o = 1'b0;

        bf_uop_valid        = 1'b0;
        bf_x0_i_valid       = 1'b0;
        bf_x0_q_valid       = 1'b0;
        bf_x1_i_valid       = 1'b0;
        bf_x1_q_valid       = 1'b0;
        bf_twiddle_re_valid = 1'b0;
        bf_twiddle_im_valid = 1'b0;

        case (current_state)

            //------------------------------------------------------------------
            // Accept command byte
            //------------------------------------------------------------------

            ST_COMMAND: begin
                din_ready_o = 1'b1;

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
            // Capture interleaved FFT2 input
            //------------------------------------------------------------------

            ST_RX_X0_I: begin
                din_ready_o = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X0_Q;
                end
            end

            ST_RX_X0_Q: begin
                din_ready_o = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X1_I;
                end
            end

            ST_RX_X1_I: begin
                din_ready_o = 1'b1;

                if (din_fire) begin
                    next_state = ST_RX_X1_Q;
                end
            end

            ST_RX_X1_Q: begin
                din_ready_o = 1'b1;

                if (din_fire) begin
                    next_state = ST_ISSUE;
                end
            end

            //------------------------------------------------------------------
            // Issue all independently handshaken butterfly inputs
            //------------------------------------------------------------------

            ST_ISSUE: begin
                bf_uop_valid        = uop_pending;
                bf_x0_i_valid       = x0_i_pending;
                bf_x0_q_valid       = x0_q_pending;
                bf_x1_i_valid       = x1_i_pending;
                bf_x1_q_valid       = x1_q_pending;
                bf_twiddle_re_valid = twiddle_re_pending;
                bf_twiddle_im_valid = twiddle_im_pending;

                if (issue_complete_now) begin
                    next_state = ST_WAIT_RESULT;
                end
            end

            //------------------------------------------------------------------
            // Wait until downstream accepts the complete parallel result
            //------------------------------------------------------------------

            ST_WAIT_RESULT: begin
                /*
                 * result_valid_o and bf_out_ready are driven by continuous
                 * assignments above.
                 */
                if (result_fire) begin
                    next_state = ST_COMMAND;
                end
            end

            default: begin
                next_state = ST_COMMAND;
            end

        endcase
    end

    //==========================================================================
    // Sequential state and operand storage
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
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
        end else begin
            current_state <= next_state;

            //------------------------------------------------------------------
            // Capture input samples
            //------------------------------------------------------------------

            if (
                current_state == ST_RX_X0_I &&
                din_fire
            ) begin
                x0_i_operand <= sign_extend_q17(din);
            end

            if (
                current_state == ST_RX_X0_Q &&
                din_fire
            ) begin
                x0_q_operand <= sign_extend_q17(din);
            end

            /*
             * Negate x1 so that the exact -1 twiddle produces multiplication
             * by +1 for FFT2.
             */
            if (
                current_state == ST_RX_X1_I &&
                din_fire
            ) begin
                x1_i_operand <= negate_q17(din);
            end

            if (
                current_state == ST_RX_X1_Q &&
                din_fire
            ) begin
                x1_q_operand <= negate_q17(din);

                /*
                 * The complete input transaction has been received.
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
            // Clear each pending flag after its individual handshake
            //------------------------------------------------------------------

            if (current_state == ST_ISSUE) begin
                if (
                    uop_pending &&
                    bf_uop_ready
                ) begin
                    uop_pending <= 1'b0;
                end

                if (
                    x0_i_pending &&
                    bf_x0_i_ready
                ) begin
                    x0_i_pending <= 1'b0;
                end

                if (
                    x0_q_pending &&
                    bf_x0_q_ready
                ) begin
                    x0_q_pending <= 1'b0;
                end

                if (
                    x1_i_pending &&
                    bf_x1_i_ready
                ) begin
                    x1_i_pending <= 1'b0;
                end

                if (
                    x1_q_pending &&
                    bf_x1_q_ready
                ) begin
                    x1_q_pending <= 1'b0;
                end

                if (
                    twiddle_re_pending &&
                    bf_twiddle_re_ready
                ) begin
                    twiddle_re_pending <= 1'b0;
                end

                if (
                    twiddle_im_pending &&
                    bf_twiddle_im_ready
                ) begin
                    twiddle_im_pending <= 1'b0;
                end
            end
        end
    end

    //==========================================================================
    // Radix-2 butterfly
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
