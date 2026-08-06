`timescale 1ns/1ps
`default_nettype none

module mixed_radix_butterfly #(
    parameter integer FRAC_BITS = 7
) (
    input logic clk,
    input logic rst_n,

    // Operation selector.
    // 2'b01: radix-2 butterfly
    // 2'b10: radix-3 butterfly
    input  logic [1:0] uop_in,
    input  logic       uop_valid,
    output logic       uop_ready,

    input  logic signed [15:0] x0_i,
    input  logic               x0_i_valid,
    output logic               x0_i_ready,

    input  logic signed [15:0] x0_q,
    input  logic               x0_q_valid,
    output logic               x0_q_ready,

    input  logic signed [15:0] x1_i,
    input  logic               x1_i_valid,
    output logic               x1_i_ready,

    input  logic signed [15:0] x1_q,
    input  logic               x1_q_valid,
    output logic               x1_q_ready,

    // Used only by the radix-3 operation.
    input  logic signed [15:0] x2_i,
    input  logic               x2_i_valid,
    output logic               x2_i_ready,

    input  logic signed [15:0] x2_q,
    input  logic               x2_q_valid,
    output logic               x2_q_ready,

    // Radix-2: W*x1 coefficient.
    // Radix-3: K*(x1-x2), where K=-j*sqrt(3)/2 for FFT3.
    input  logic signed [7:0] twiddle_re,
    input  logic              twiddle_re_valid,
    output logic              twiddle_re_ready,

    input  logic signed [7:0] twiddle_im,
    input  logic              twiddle_im_valid,
    output logic              twiddle_im_ready,

    // Atomic result transaction. X2 is meaningful only for radix-3.
    output logic signed [15:0] X0_i,
    output logic signed [15:0] X0_q,
    output logic signed [15:0] X1_i,
    output logic signed [15:0] X1_q,
    output logic signed [15:0] X2_i,
    output logic signed [15:0] X2_q,
    output logic               out_valid,
    input  logic               out_ready
);

    localparam logic [1:0] UOP_RADIX2 = 2'b01;
    localparam logic [1:0] UOP_RADIX3 = 2'b10;

    //==========================================================================
    // Independent one-entry input buffers
    //==========================================================================

    logic       uop_full;
    logic [1:0] uop_reg;

    logic               x0_i_full;
    logic signed [15:0] x0_i_reg;
    logic               x0_q_full;
    logic signed [15:0] x0_q_reg;

    logic               x1_i_full;
    logic signed [15:0] x1_i_reg;
    logic               x1_q_full;
    logic signed [15:0] x1_q_reg;

    logic               x2_i_full;
    logic signed [15:0] x2_i_reg;
    logic               x2_q_full;
    logic signed [15:0] x2_q_reg;

    logic              twiddle_re_full;
    logic signed [7:0] twiddle_re_reg;
    logic              twiddle_im_full;
    logic signed [7:0] twiddle_im_reg;

    //==========================================================================
    // Atomic output register
    //==========================================================================

    logic out_full;

    logic signed [15:0] X0_i_reg;
    logic signed [15:0] X0_q_reg;
    logic signed [15:0] X1_i_reg;
    logic signed [15:0] X1_q_reg;
    logic signed [15:0] X2_i_reg;
    logic signed [15:0] X2_q_reg;

    assign out_valid = out_full;
    assign X0_i = X0_i_reg;
    assign X0_q = X0_q_reg;
    assign X1_i = X1_i_reg;
    assign X1_q = X1_q_reg;
    assign X2_i = X2_i_reg;
    assign X2_q = X2_q_reg;

    //==========================================================================
    // Mode-aware latency-insensitive handshakes
    //==========================================================================

    logic [1:0] selected_uop;
    logic       selected_uop_valid;
    logic       selected_radix2;
    logic       selected_radix3;

    logic radix2_inputs_full;
    logic radix3_inputs_full;
    logic output_available;
    logic compute_fire;
    logic consume_x2;

    logic take_uop;
    logic take_x0_i;
    logic take_x0_q;
    logic take_x1_i;
    logic take_x1_q;
    logic take_x2_i;
    logic take_x2_q;
    logic take_twiddle_re;
    logic take_twiddle_im;

    // When the uop buffer is empty, the current uop input may directly select
    // which operand channels are required. This permits uop and operands to be
    // accepted in the same cycle while still preventing radix-2 operations
    // from consuming stray x2 tokens.
    assign selected_uop = uop_full ? uop_reg : uop_in;
    assign selected_uop_valid = uop_full || uop_valid;
    assign selected_radix2 =
        selected_uop_valid && (selected_uop == UOP_RADIX2);
    assign selected_radix3 =
        selected_uop_valid && (selected_uop == UOP_RADIX3);

    assign output_available = !out_full || out_ready;

    assign radix2_inputs_full =
        uop_full &&
        (uop_reg == UOP_RADIX2) &&
        x0_i_full && x0_q_full &&
        x1_i_full && x1_q_full &&
        twiddle_re_full && twiddle_im_full;

    assign radix3_inputs_full =
        uop_full &&
        (uop_reg == UOP_RADIX3) &&
        x0_i_full && x0_q_full &&
        x1_i_full && x1_q_full &&
        x2_i_full && x2_q_full &&
        twiddle_re_full && twiddle_im_full;

    assign compute_fire =
        output_available &&
        (radix2_inputs_full || radix3_inputs_full);

    assign consume_x2 =
        compute_fire && (uop_reg == UOP_RADIX3);

    assign uop_ready = !uop_full || compute_fire;

    assign x0_i_ready =
        (selected_radix2 || selected_radix3) &&
        (!x0_i_full || compute_fire);
    assign x0_q_ready =
        (selected_radix2 || selected_radix3) &&
        (!x0_q_full || compute_fire);

    assign x1_i_ready =
        (selected_radix2 || selected_radix3) &&
        (!x1_i_full || compute_fire);
    assign x1_q_ready =
        (selected_radix2 || selected_radix3) &&
        (!x1_q_full || compute_fire);

    assign x2_i_ready =
        selected_radix3 &&
        (!x2_i_full || consume_x2);
    assign x2_q_ready =
        selected_radix3 &&
        (!x2_q_full || consume_x2);

    assign twiddle_re_ready =
        (selected_radix2 || selected_radix3) &&
        (!twiddle_re_full || compute_fire);
    assign twiddle_im_ready =
        (selected_radix2 || selected_radix3) &&
        (!twiddle_im_full || compute_fire);

    assign take_uop        = uop_valid        && uop_ready;
    assign take_x0_i       = x0_i_valid       && x0_i_ready;
    assign take_x0_q       = x0_q_valid       && x0_q_ready;
    assign take_x1_i       = x1_i_valid       && x1_i_ready;
    assign take_x1_q       = x1_q_valid       && x1_q_ready;
    assign take_x2_i       = x2_i_valid       && x2_i_ready;
    assign take_x2_q       = x2_q_valid       && x2_q_ready;
    assign take_twiddle_re = twiddle_re_valid && twiddle_re_ready;
    assign take_twiddle_im = twiddle_im_valid && twiddle_im_ready;

    //==========================================================================
    // Shared arithmetic
    //
    // Radix-2:
    //     t  = W*x1
    //     X0 = x0 + t
    //     X1 = x0 - t
    //
    // Radix-3:
    //     s    = x1 + x2
    //     d    = x1 - x2
    //     t    = (-j*sqrt(3)/2)*d
    //     base = x0 - s/2
    //     X0   = x0 + s
    //     X1   = base + t
    //     X2   = base - t
    //
    // The same complex multiplier is used for W*x1 and K*d.
    //==========================================================================

    logic signed [16:0] x1_i_ext;
    logic signed [16:0] x1_q_ext;
    logic signed [16:0] x2_i_ext;
    logic signed [16:0] x2_q_ext;

    logic signed [16:0] radix3_sum_i;
    logic signed [16:0] radix3_sum_q;
    logic signed [16:0] radix3_diff_i;
    logic signed [16:0] radix3_diff_q;
    logic signed [16:0] radix3_half_sum_i;
    logic signed [16:0] radix3_half_sum_q;

    logic signed [16:0] multiplier_input_i;
    logic signed [16:0] multiplier_input_q;

    // 8-bit coefficient times 17-bit data = 25-bit product.
    logic signed [24:0] product_rr;
    logic signed [24:0] product_iq;
    logic signed [24:0] product_rq;
    logic signed [24:0] product_ii;

    // Addition/subtraction of two 25-bit products requires 26 bits.
    logic signed [25:0] product_re_wide;
    logic signed [25:0] product_im_wide;
    logic signed [25:0] product_re_scaled;
    logic signed [25:0] product_im_scaled;

    logic signed [26:0] x0_i_ext;
    logic signed [26:0] x0_q_ext;
    logic signed [26:0] sum_i_ext;
    logic signed [26:0] sum_q_ext;
    logic signed [26:0] half_sum_i_ext;
    logic signed [26:0] half_sum_q_ext;
    logic signed [26:0] product_re_ext;
    logic signed [26:0] product_im_ext;

    logic signed [26:0] radix3_base_i;
    logic signed [26:0] radix3_base_q;

    logic signed [26:0] next_X0_i_wide;
    logic signed [26:0] next_X0_q_wide;
    logic signed [26:0] next_X1_i_wide;
    logic signed [26:0] next_X1_q_wide;
    logic signed [26:0] next_X2_i_wide;
    logic signed [26:0] next_X2_q_wide;

    always @* begin
        x1_i_ext = {x1_i_reg[15], x1_i_reg};
        x1_q_ext = {x1_q_reg[15], x1_q_reg};
        x2_i_ext = {x2_i_reg[15], x2_i_reg};
        x2_q_ext = {x2_q_reg[15], x2_q_reg};

        radix3_sum_i  = x1_i_ext + x2_i_ext;
        radix3_sum_q  = x1_q_ext + x2_q_ext;
        radix3_diff_i = x1_i_ext - x2_i_ext;
        radix3_diff_q = x1_q_ext - x2_q_ext;

        // This /2 is part of the radix-3 identity, not transform
        // normalization. Arithmetic shifting matches the bit-accurate model.
        radix3_half_sum_i = radix3_sum_i >>> 1;
        radix3_half_sum_q = radix3_sum_q >>> 1;

        if (uop_reg == UOP_RADIX3) begin
            multiplier_input_i = radix3_diff_i;
            multiplier_input_q = radix3_diff_q;
        end else begin
            multiplier_input_i = x1_i_ext;
            multiplier_input_q = x1_q_ext;
        end

        product_rr =
            $signed(twiddle_re_reg) * $signed(multiplier_input_i);
        product_iq =
            $signed(twiddle_im_reg) * $signed(multiplier_input_q);
        product_rq =
            $signed(twiddle_re_reg) * $signed(multiplier_input_q);
        product_ii =
            $signed(twiddle_im_reg) * $signed(multiplier_input_i);

        product_re_wide =
            $signed({product_rr[24], product_rr}) -
            $signed({product_iq[24], product_iq});
        product_im_wide =
            $signed({product_rq[24], product_rq}) +
            $signed({product_ii[24], product_ii});

        // Restore seven fractional bits after multiplication.
        product_re_scaled = product_re_wide >>> FRAC_BITS;
        product_im_scaled = product_im_wide >>> FRAC_BITS;

        x0_i_ext = {{11{x0_i_reg[15]}}, x0_i_reg};
        x0_q_ext = {{11{x0_q_reg[15]}}, x0_q_reg};
        sum_i_ext = {{10{radix3_sum_i[16]}}, radix3_sum_i};
        sum_q_ext = {{10{radix3_sum_q[16]}}, radix3_sum_q};
        half_sum_i_ext =
            {{10{radix3_half_sum_i[16]}}, radix3_half_sum_i};
        half_sum_q_ext =
            {{10{radix3_half_sum_q[16]}}, radix3_half_sum_q};
        product_re_ext = {product_re_scaled[25], product_re_scaled};
        product_im_ext = {product_im_scaled[25], product_im_scaled};

        radix3_base_i = x0_i_ext - half_sum_i_ext;
        radix3_base_q = x0_q_ext - half_sum_q_ext;

        if (uop_reg == UOP_RADIX3) begin
            next_X0_i_wide = x0_i_ext + sum_i_ext;
            next_X0_q_wide = x0_q_ext + sum_q_ext;

            next_X1_i_wide = radix3_base_i + product_re_ext;
            next_X1_q_wide = radix3_base_q + product_im_ext;

            next_X2_i_wide = radix3_base_i - product_re_ext;
            next_X2_q_wide = radix3_base_q - product_im_ext;
        end else begin
            next_X0_i_wide = x0_i_ext + product_re_ext;
            next_X0_q_wide = x0_q_ext + product_im_ext;

            next_X1_i_wide = x0_i_ext - product_re_ext;
            next_X1_q_wide = x0_q_ext - product_im_ext;

            next_X2_i_wide = '0;
            next_X2_q_wide = '0;
        end
    end

    //==========================================================================
    // Sequential storage
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uop_full <= 1'b0;
            x0_i_full <= 1'b0;
            x0_q_full <= 1'b0;
            x1_i_full <= 1'b0;
            x1_q_full <= 1'b0;
            x2_i_full <= 1'b0;
            x2_q_full <= 1'b0;
            twiddle_re_full <= 1'b0;
            twiddle_im_full <= 1'b0;

            uop_reg <= '0;
            x0_i_reg <= '0;
            x0_q_reg <= '0;
            x1_i_reg <= '0;
            x1_q_reg <= '0;
            x2_i_reg <= '0;
            x2_q_reg <= '0;
            twiddle_re_reg <= '0;
            twiddle_im_reg <= '0;

            out_full <= 1'b0;
            X0_i_reg <= '0;
            X0_q_reg <= '0;
            X1_i_reg <= '0;
            X1_q_reg <= '0;
            X2_i_reg <= '0;
            X2_q_reg <= '0;
        end else begin
            if (take_uop)
                uop_reg <= uop_in;
            if (take_x0_i)
                x0_i_reg <= x0_i;
            if (take_x0_q)
                x0_q_reg <= x0_q;
            if (take_x1_i)
                x1_i_reg <= x1_i;
            if (take_x1_q)
                x1_q_reg <= x1_q;
            if (take_x2_i)
                x2_i_reg <= x2_i;
            if (take_x2_q)
                x2_q_reg <= x2_q;
            if (take_twiddle_re)
                twiddle_re_reg <= twiddle_re;
            if (take_twiddle_im)
                twiddle_im_reg <= twiddle_im;

            case ({compute_fire, take_uop})
                2'b01, 2'b11: uop_full <= 1'b1;
                2'b10:        uop_full <= 1'b0;
                default:      uop_full <= uop_full;
            endcase

            case ({compute_fire, take_x0_i})
                2'b01, 2'b11: x0_i_full <= 1'b1;
                2'b10:        x0_i_full <= 1'b0;
                default:      x0_i_full <= x0_i_full;
            endcase

            case ({compute_fire, take_x0_q})
                2'b01, 2'b11: x0_q_full <= 1'b1;
                2'b10:        x0_q_full <= 1'b0;
                default:      x0_q_full <= x0_q_full;
            endcase

            case ({compute_fire, take_x1_i})
                2'b01, 2'b11: x1_i_full <= 1'b1;
                2'b10:        x1_i_full <= 1'b0;
                default:      x1_i_full <= x1_i_full;
            endcase

            case ({compute_fire, take_x1_q})
                2'b01, 2'b11: x1_q_full <= 1'b1;
                2'b10:        x1_q_full <= 1'b0;
                default:      x1_q_full <= x1_q_full;
            endcase

            // x2 is consumed only by radix-3. It is never accepted for a
            // radix-2 operation, so no unrelated token can be discarded.
            case ({consume_x2, take_x2_i})
                2'b01, 2'b11: x2_i_full <= 1'b1;
                2'b10:        x2_i_full <= 1'b0;
                default:      x2_i_full <= x2_i_full;
            endcase

            case ({consume_x2, take_x2_q})
                2'b01, 2'b11: x2_q_full <= 1'b1;
                2'b10:        x2_q_full <= 1'b0;
                default:      x2_q_full <= x2_q_full;
            endcase

            case ({compute_fire, take_twiddle_re})
                2'b01, 2'b11: twiddle_re_full <= 1'b1;
                2'b10:        twiddle_re_full <= 1'b0;
                default:      twiddle_re_full <= twiddle_re_full;
            endcase

            case ({compute_fire, take_twiddle_im})
                2'b01, 2'b11: twiddle_im_full <= 1'b1;
                2'b10:        twiddle_im_full <= 1'b0;
                default:      twiddle_im_full <= twiddle_im_full;
            endcase

            if (compute_fire) begin
                X0_i_reg <= next_X0_i_wide[15:0];
                X0_q_reg <= next_X0_q_wide[15:0];
                X1_i_reg <= next_X1_i_wide[15:0];
                X1_q_reg <= next_X1_q_wide[15:0];
                X2_i_reg <= next_X2_i_wide[15:0];
                X2_q_reg <= next_X2_q_wide[15:0];
                out_full <= 1'b1;
            end else if (out_full && out_ready) begin
                out_full <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
