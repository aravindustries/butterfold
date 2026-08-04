`timescale 1ns/1ps
`default_nettype none

module two_point_dft #(
    /*
     * All samples and twiddles have seven fractional bits.
     *
     * Input samples begin as Q1.7 values sign-extended into 16 bits.
     * As the FFT progresses, the upper bits become guard/integer bits.
     */
    parameter int FRAC_BITS = 7
) (
    input logic clk,
    input logic rst_n,

    // Operation input.
    // Currently, uop_in == 1 selects a radix-2 butterfly.
    input  logic uop_in,
    input  logic uop_valid,
    output logic uop_ready,

    // x0 real
    input  logic signed [15:0] x0_i,
    input  logic               x0_i_valid,
    output logic               x0_i_ready,

    // x0 imaginary
    input  logic signed [15:0] x0_q,
    input  logic               x0_q_valid,
    output logic               x0_q_ready,

    // x1 real
    input  logic signed [15:0] x1_i,
    input  logic               x1_i_valid,
    output logic               x1_i_ready,

    // x1 imaginary
    input  logic signed [15:0] x1_q,
    input  logic               x1_q_valid,
    output logic               x1_q_ready,

    // Twiddle real: signed 8-bit with seven fractional bits
    input  logic signed [7:0] twiddle_re,
    input  logic              twiddle_re_valid,
    output logic              twiddle_re_ready,

    // Twiddle imaginary: signed 8-bit with seven fractional bits
    input  logic signed [7:0] twiddle_im,
    input  logic              twiddle_im_valid,
    output logic              twiddle_im_ready,

    // Atomic butterfly output
    output logic signed [15:0] X0_i,
    output logic signed [15:0] X0_q,
    output logic signed [15:0] X1_i,
    output logic signed [15:0] X1_q,
    output logic               out_valid,
    input  logic               out_ready);

    //==========================================================================
    // Independent input buffers
    //==========================================================================

    logic uop_full;
    logic uop_reg;

    logic               x0_i_full;
    logic signed [15:0] x0_i_reg;

    logic               x0_q_full;
    logic signed [15:0] x0_q_reg;

    logic               x1_i_full;
    logic signed [15:0] x1_i_reg;

    logic               x1_q_full;
    logic signed [15:0] x1_q_reg;

    logic              twiddle_re_full;
    logic signed [7:0] twiddle_re_reg;

    logic              twiddle_im_full;
    logic signed [7:0] twiddle_im_reg;

    //==========================================================================
    // Atomic output buffer
    //==========================================================================

    logic out_full;

    logic signed [15:0] X0_i_reg;
    logic signed [15:0] X0_q_reg;
    logic signed [15:0] X1_i_reg;
    logic signed [15:0] X1_q_reg;

    assign out_valid = out_full;

    assign X0_i = X0_i_reg;
    assign X0_q = X0_q_reg;
    assign X1_i = X1_i_reg;
    assign X1_q = X1_q_reg;

    //==========================================================================
    // Handshake control
    //==========================================================================

    logic take_uop;
    logic take_x0_i;
    logic take_x0_q;
    logic take_x1_i;
    logic take_x1_q;
    logic take_twiddle_re;
    logic take_twiddle_im;

    logic all_inputs_full;
    logic output_available;
    logic compute_fire;

    /*
     * An input can be accepted when:
     *
     * 1. Its buffer is empty, or
     * 2. Its current token is being consumed by compute_fire.
     *
     * The second condition permits consume-and-replace operation.
     */
    assign uop_ready        = !uop_full        || compute_fire;
    assign x0_i_ready       = !x0_i_full       || compute_fire;
    assign x0_q_ready       = !x0_q_full       || compute_fire;
    assign x1_i_ready       = !x1_i_full       || compute_fire;
    assign x1_q_ready       = !x1_q_full       || compute_fire;
    assign twiddle_re_ready = !twiddle_re_full || compute_fire;
    assign twiddle_im_ready = !twiddle_im_full || compute_fire;

    assign take_uop =
        uop_valid && uop_ready;

    assign take_x0_i =
        x0_i_valid && x0_i_ready;

    assign take_x0_q =
        x0_q_valid && x0_q_ready;

    assign take_x1_i =
        x1_i_valid && x1_i_ready;

    assign take_x1_q =
        x1_q_valid && x1_q_ready;

    assign take_twiddle_re =
        twiddle_re_valid && twiddle_re_ready;

    assign take_twiddle_im =
        twiddle_im_valid && twiddle_im_ready;

    /*
     * The first buffered token from every stream forms one butterfly
     * transaction.
     */
    assign all_inputs_full =
        uop_full        &&
        x0_i_full       &&
        x0_q_full       &&
        x1_i_full       &&
        x1_q_full       &&
        twiddle_re_full &&
        twiddle_im_full;

    /*
     * A new result can be produced when the output register is empty or the
     * current output will be consumed this cycle.
     */
    assign output_available =
        !out_full || out_ready;

    /*
     * Only uop == 1 is currently supported.
     */
    assign compute_fire =
        all_inputs_full &&
        uop_reg         &&
        output_available;

    //==========================================================================
    // Complex multiplication
    //
    // W  = twiddle_re + j*twiddle_im
    // x1 = x1_i       + j*x1_q
    //
    // t = W*x1
    //
    // t_re = twiddle_re*x1_i - twiddle_im*x1_q
    // t_im = twiddle_re*x1_q + twiddle_im*x1_i
    //==========================================================================

    /*
     * 16-bit data with 7 fractional bits multiplied by an 8-bit twiddle with
     * 7 fractional bits produces a 24-bit product with 14 fractional bits.
     */
    logic signed [23:0] product_rr;
    logic signed [23:0] product_iq;
    logic signed [23:0] product_rq;
    logic signed [23:0] product_ii;

    /*
     * Adding or subtracting two 24-bit products requires 25 bits.
     */
    logic signed [24:0] tw_x1_re_wide;
    logic signed [24:0] tw_x1_im_wide;

    /*
     * These still use 25-bit storage, but after shifting they once again have
     * seven fractional bits.
     */
    logic signed [24:0] tw_x1_re_scaled;
    logic signed [24:0] tw_x1_im_scaled;

    always_comb begin
        product_rr =
            $signed(twiddle_re_reg) * $signed(x1_i_reg);

        product_iq =
            $signed(twiddle_im_reg) * $signed(x1_q_reg);

        product_rq =
            $signed(twiddle_re_reg) * $signed(x1_q_reg);

        product_ii =
            $signed(twiddle_im_reg) * $signed(x1_i_reg);

        /*
         * Both operands are explicitly sign-extended to 25 bits before the
         * addition or subtraction.
         */
        tw_x1_re_wide =
            $signed({product_rr[23], product_rr}) -
            $signed({product_iq[23], product_iq});

        tw_x1_im_wide =
            $signed({product_rq[23], product_rq}) +
            $signed({product_ii[23], product_ii});

        /*
         * Required binary-point realignment:
         *
         * 14 fractional bits -> 7 fractional bits
         *
         * This is not FFT stage scaling. It only compensates for the
         * fractional-bit growth caused by multiplication.
         */
        tw_x1_re_scaled =
            tw_x1_re_wide >>> FRAC_BITS;

        tw_x1_im_scaled =
            tw_x1_im_wide >>> FRAC_BITS;
    end

    //==========================================================================
    // Radix-2 butterfly arithmetic
    //
    // X0 = x0 + W*x1
    // X1 = x0 - W*x1
    //==========================================================================

    /*
     * A 25-bit complex-product component plus a 25-bit operand can require
     * 26 bits. These temporary values prevent premature overflow or
     * truncation.
     */
    logic signed [25:0] x0_i_ext;
    logic signed [25:0] x0_q_ext;

    logic signed [25:0] tw_x1_re_ext;
    logic signed [25:0] tw_x1_im_ext;

    logic signed [25:0] next_X0_i_wide;
    logic signed [25:0] next_X0_q_wide;
    logic signed [25:0] next_X1_i_wide;
    logic signed [25:0] next_X1_q_wide;

    always_comb begin
        x0_i_ext = {
            {10{x0_i_reg[15]}},
            x0_i_reg
        };

        x0_q_ext = {
            {10{x0_q_reg[15]}},
            x0_q_reg
        };

        tw_x1_re_ext = {
            tw_x1_re_scaled[24],
            tw_x1_re_scaled
        };

        tw_x1_im_ext = {
            tw_x1_im_scaled[24],
            tw_x1_im_scaled
        };

        /*
         * No divide-by-two scaling is applied here.
         */
        next_X0_i_wide = x0_i_ext + tw_x1_re_ext;
        next_X0_q_wide = x0_q_ext + tw_x1_im_ext;

        next_X1_i_wide = x0_i_ext - tw_x1_re_ext;
        next_X1_q_wide = x0_q_ext - tw_x1_im_ext;
    end

    //==========================================================================
    // Sequential storage
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uop_full        <= 1'b0;
            x0_i_full       <= 1'b0;
            x0_q_full       <= 1'b0;
            x1_i_full       <= 1'b0;
            x1_q_full       <= 1'b0;
            twiddle_re_full <= 1'b0;
            twiddle_im_full <= 1'b0;

            uop_reg        <= 1'b0;
            x0_i_reg       <= '0;
            x0_q_reg       <= '0;
            x1_i_reg       <= '0;
            x1_q_reg       <= '0;
            twiddle_re_reg <= '0;
            twiddle_im_reg <= '0;

            out_full <= 1'b0;

            X0_i_reg <= '0;
            X0_q_reg <= '0;
            X1_i_reg <= '0;
            X1_q_reg <= '0;
        end else begin

            //------------------------------------------------------------------
            // Capture input values
            //------------------------------------------------------------------

            if (take_uop) begin
                uop_reg <= uop_in;
            end

            if (take_x0_i) begin
                x0_i_reg <= x0_i;
            end

            if (take_x0_q) begin
                x0_q_reg <= x0_q;
            end

            if (take_x1_i) begin
                x1_i_reg <= x1_i;
            end

            if (take_x1_q) begin
                x1_q_reg <= x1_q;
            end

            if (take_twiddle_re) begin
                twiddle_re_reg <= twiddle_re;
            end

            if (take_twiddle_im) begin
                twiddle_im_reg <= twiddle_im;
            end

            //------------------------------------------------------------------
            // Update input-buffer occupancy
            //
            // compute_fire take_input  Result
            //      0          0        Hold
            //      0          1        Fill
            //      1          0        Empty
            //      1          1        Consume and replace
            //------------------------------------------------------------------

            case ({compute_fire, take_uop})
                2'b01,
                2'b11: uop_full <= 1'b1;

                2'b10: uop_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_x0_i})
                2'b01,
                2'b11: x0_i_full <= 1'b1;

                2'b10: x0_i_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_x0_q})
                2'b01,
                2'b11: x0_q_full <= 1'b1;

                2'b10: x0_q_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_x1_i})
                2'b01,
                2'b11: x1_i_full <= 1'b1;

                2'b10: x1_i_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_x1_q})
                2'b01,
                2'b11: x1_q_full <= 1'b1;

                2'b10: x1_q_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_twiddle_re})
                2'b01,
                2'b11: twiddle_re_full <= 1'b1;

                2'b10: twiddle_re_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            case ({compute_fire, take_twiddle_im})
                2'b01,
                2'b11: twiddle_im_full <= 1'b1;

                2'b10: twiddle_im_full <= 1'b0;

                default: begin
                    // Hold
                end
            endcase

            //------------------------------------------------------------------
            // Output register
            //------------------------------------------------------------------

            if (compute_fire) begin

`ifndef SYNTHESIS
                /*
                 * Verify that each wide butterfly result fits in the signed
                 * 16-bit datapath before truncation.
                 *
                 * To fit in 16 bits, every bit above bit 15 must equal the
                 * result's sign bit.
                 */
                assert (
                    next_X0_i_wide[25:16] ==
                    {10{next_X0_i_wide[15]}}
                ) else begin
                    $error(
                        "two_point_dft: X0_i overflow: %0d",
                        next_X0_i_wide
                    );
                end

                assert (
                    next_X0_q_wide[25:16] ==
                    {10{next_X0_q_wide[15]}}
                ) else begin
                    $error(
                        "two_point_dft: X0_q overflow: %0d",
                        next_X0_q_wide
                    );
                end

                assert (
                    next_X1_i_wide[25:16] ==
                    {10{next_X1_i_wide[15]}}
                ) else begin
                    $error(
                        "two_point_dft: X1_i overflow: %0d",
                        next_X1_i_wide
                    );
                end

                assert (
                    next_X1_q_wide[25:16] ==
                    {10{next_X1_q_wide[15]}}
                ) else begin
                    $error(
                        "two_point_dft: X1_q overflow: %0d",
                        next_X1_q_wide
                    );
                end
`endif

                /*
                 * The assertions verify that these slices do not discard
                 * meaningful upper bits under the expected FFT input range.
                 */
                X0_i_reg <= next_X0_i_wide[15:0];
                X0_q_reg <= next_X0_q_wide[15:0];
                X1_i_reg <= next_X1_i_wide[15:0];
                X1_q_reg <= next_X1_q_wide[15:0];

                out_full <= 1'b1;
            end else if (out_full && out_ready) begin
                /*
                 * Current output was accepted without being replaced.
                 */
                out_full <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Simulation-only protocol assertions
    //==========================================================================

`ifndef SYNTHESIS

    /*
     * Only uop == 1 may currently be presented. An unsupported operation
     * would otherwise remain buffered waiting for future implementation.
     */
    property p_supported_uop;
        @(posedge clk)
        disable iff (!rst_n)
        (uop_valid && uop_ready) |-> uop_in;
    endproperty

    assert_supported_uop:
        assert property (p_supported_uop)
        else begin
            $error(
                "two_point_dft: only uop_in == 1 is currently supported"
            );
        end

    /*
     * The output transaction must remain stable while the downstream block
     * applies backpressure.
     */
    property p_output_stable;
        @(posedge clk)
        disable iff (!rst_n)
        (out_valid && !out_ready) |=>
            out_valid &&
            $stable({
                X0_i,
                X0_q,
                X1_i,
                X1_q
            });
    endproperty

    assert_output_stable:
        assert property (p_output_stable)
        else begin
            $error(
                "two_point_dft: output changed while stalled"
            );
        end

`endif

endmodule

`default_nettype wire
