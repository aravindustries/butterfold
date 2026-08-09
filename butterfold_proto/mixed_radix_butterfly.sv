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
    logic premultiply_stage_valid;
    logic premultiply_stage_fire;
    logic premultiply_stage_available;
    logic arithmetic_stage_valid;
    logic arithmetic_stage_fire;
    logic arithmetic_stage_available;
    logic multiply_low_valid;
    logic multiply_high_valid;
    logic multiply_low_fire;
    logic multiply_high_fire;
    logic multiply_product_fire;
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

    assign arithmetic_stage_fire =
        arithmetic_stage_valid && output_available;
    assign arithmetic_stage_available =
        !arithmetic_stage_valid || arithmetic_stage_fire;

    assign multiply_low_fire = premultiply_stage_valid &&
        !multiply_low_valid && !multiply_high_valid;
    assign multiply_high_fire = multiply_low_valid;
    assign multiply_product_fire = multiply_high_valid &&
        arithmetic_stage_available;
    assign premultiply_stage_fire = multiply_product_fire;
    assign premultiply_stage_available =
        !premultiply_stage_valid || premultiply_stage_fire;

    assign compute_fire =
        premultiply_stage_available &&
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

    // One time-folded 8x10 scalar-multiply layer implements the four partial
    // products of the existing complex multiplier.  A signed 17-bit operand
    // is decomposed exactly as high*512 + unsigned(low).  Low and high halves
    // use the same four multiply operators on consecutive cycles.
    logic signed [9:0] multiplier_chunk_i;
    logic signed [9:0] multiplier_chunk_q;
    logic signed [17:0] partial_rr;
    logic signed [17:0] partial_iq;
    logic signed [17:0] partial_rq;
    logic signed [17:0] partial_ii;
    logic signed [17:0] low_rr_reg;
    logic signed [17:0] low_iq_reg;
    logic signed [17:0] low_rq_reg;
    logic signed [17:0] low_ii_reg;
    logic signed [17:0] high_rr_reg;
    logic signed [17:0] high_iq_reg;
    logic signed [17:0] high_rq_reg;
    logic signed [17:0] high_ii_reg;
    logic signed [25:0] product_rr;
    logic signed [25:0] product_iq;
    logic signed [25:0] product_rq;
    logic signed [25:0] product_ii;

    // The first cut isolates radix selection/pre-addition from the multiplier.
    // Data and mode remain aligned through the elastic pipeline.
    logic [1:0] premultiply_uop_reg;
    logic signed [16:0] premultiply_input_i_reg;
    logic signed [16:0] premultiply_input_q_reg;
    logic signed [7:0] premultiply_twiddle_re_reg;
    logic signed [7:0] premultiply_twiddle_im_reg;
    logic signed [26:0] premultiply_x0_i_reg;
    logic signed [26:0] premultiply_x0_q_reg;
    logic signed [26:0] premultiply_sum_i_reg;
    logic signed [26:0] premultiply_sum_q_reg;
    logic signed [26:0] premultiply_half_sum_i_reg;
    logic signed [26:0] premultiply_half_sum_q_reg;

    // Pipeline cut after the four shared complex-multiply partial products.
    // These registers preserve every pre-existing width/truncation point.
    logic [1:0] arithmetic_uop_reg;
    logic signed [24:0] product_rr_reg;
    logic signed [24:0] product_iq_reg;
    logic signed [24:0] product_rq_reg;
    logic signed [24:0] product_ii_reg;
    logic signed [26:0] arithmetic_x0_i_reg;
    logic signed [26:0] arithmetic_x0_q_reg;
    logic signed [26:0] arithmetic_sum_i_reg;
    logic signed [26:0] arithmetic_sum_q_reg;
    logic signed [26:0] arithmetic_half_sum_i_reg;
    logic signed [26:0] arithmetic_half_sum_q_reg;

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

        if (multiply_low_valid) begin
            multiplier_chunk_i =
                {{2{premultiply_input_i_reg[16]}},
                 premultiply_input_i_reg[16:9]};
            multiplier_chunk_q =
                {{2{premultiply_input_q_reg[16]}},
                 premultiply_input_q_reg[16:9]};
        end else begin
            multiplier_chunk_i =
                {1'b0, premultiply_input_i_reg[8:0]};
            multiplier_chunk_q =
                {1'b0, premultiply_input_q_reg[8:0]};
        end

        partial_rr = $signed(premultiply_twiddle_re_reg) *
            $signed(multiplier_chunk_i);
        partial_iq = $signed(premultiply_twiddle_im_reg) *
            $signed(multiplier_chunk_q);
        partial_rq = $signed(premultiply_twiddle_re_reg) *
            $signed(multiplier_chunk_q);
        partial_ii = $signed(premultiply_twiddle_im_reg) *
            $signed(multiplier_chunk_i);

        product_rr = ($signed({{8{high_rr_reg[17]}}, high_rr_reg}) <<< 9) +
            $signed({{8{low_rr_reg[17]}}, low_rr_reg});
        product_iq = ($signed({{8{high_iq_reg[17]}}, high_iq_reg}) <<< 9) +
            $signed({{8{low_iq_reg[17]}}, low_iq_reg});
        product_rq = ($signed({{8{high_rq_reg[17]}}, high_rq_reg}) <<< 9) +
            $signed({{8{low_rq_reg[17]}}, low_rq_reg});
        product_ii = ($signed({{8{high_ii_reg[17]}}, high_ii_reg}) <<< 9) +
            $signed({{8{low_ii_reg[17]}}, low_ii_reg});

        product_re_wide =
            $signed({product_rr_reg[24], product_rr_reg}) -
            $signed({product_iq_reg[24], product_iq_reg});
        product_im_wide =
            $signed({product_rq_reg[24], product_rq_reg}) +
            $signed({product_ii_reg[24], product_ii_reg});

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

        radix3_base_i = arithmetic_x0_i_reg - arithmetic_half_sum_i_reg;
        radix3_base_q = arithmetic_x0_q_reg - arithmetic_half_sum_q_reg;

        if (arithmetic_uop_reg == UOP_RADIX3) begin
            next_X0_i_wide = arithmetic_x0_i_reg + arithmetic_sum_i_reg;
            next_X0_q_wide = arithmetic_x0_q_reg + arithmetic_sum_q_reg;

            next_X1_i_wide = radix3_base_i + product_re_ext;
            next_X1_q_wide = radix3_base_q + product_im_ext;

            next_X2_i_wide = radix3_base_i - product_re_ext;
            next_X2_q_wide = radix3_base_q - product_im_ext;
        end else begin
            next_X0_i_wide = arithmetic_x0_i_reg + product_re_ext;
            next_X0_q_wide = arithmetic_x0_q_reg + product_im_ext;

            next_X1_i_wide = arithmetic_x0_i_reg - product_re_ext;
            next_X1_q_wide = arithmetic_x0_q_reg - product_im_ext;

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

            premultiply_stage_valid <= 1'b0;
            multiply_low_valid <= 1'b0;
            multiply_high_valid <= 1'b0;
            low_rr_reg <= '0;
            low_iq_reg <= '0;
            low_rq_reg <= '0;
            low_ii_reg <= '0;
            high_rr_reg <= '0;
            high_iq_reg <= '0;
            high_rq_reg <= '0;
            high_ii_reg <= '0;
            premultiply_uop_reg <= '0;
            premultiply_input_i_reg <= '0;
            premultiply_input_q_reg <= '0;
            premultiply_twiddle_re_reg <= '0;
            premultiply_twiddle_im_reg <= '0;
            premultiply_x0_i_reg <= '0;
            premultiply_x0_q_reg <= '0;
            premultiply_sum_i_reg <= '0;
            premultiply_sum_q_reg <= '0;
            premultiply_half_sum_i_reg <= '0;
            premultiply_half_sum_q_reg <= '0;

            arithmetic_stage_valid <= 1'b0;
            arithmetic_uop_reg <= '0;
            product_rr_reg <= '0;
            product_iq_reg <= '0;
            product_rq_reg <= '0;
            product_ii_reg <= '0;
            arithmetic_x0_i_reg <= '0;
            arithmetic_x0_q_reg <= '0;
            arithmetic_sum_i_reg <= '0;
            arithmetic_sum_q_reg <= '0;
            arithmetic_half_sum_i_reg <= '0;
            arithmetic_half_sum_q_reg <= '0;

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

            case ({premultiply_stage_fire, compute_fire})
                2'b01, 2'b11: premultiply_stage_valid <= 1'b1;
                2'b10:        premultiply_stage_valid <= 1'b0;
                default:      premultiply_stage_valid <= premultiply_stage_valid;
            endcase

            if (multiply_low_fire) begin
                low_rr_reg <= partial_rr;
                low_iq_reg <= partial_iq;
                low_rq_reg <= partial_rq;
                low_ii_reg <= partial_ii;
                multiply_low_valid <= 1'b1;
            end else if (multiply_high_fire) begin
                multiply_low_valid <= 1'b0;
                high_rr_reg <= partial_rr;
                high_iq_reg <= partial_iq;
                high_rq_reg <= partial_rq;
                high_ii_reg <= partial_ii;
                multiply_high_valid <= 1'b1;
            end

            if (multiply_product_fire) begin
                multiply_high_valid <= 1'b0;
            end

            if (compute_fire) begin
                premultiply_uop_reg <= uop_reg;
                premultiply_input_i_reg <= multiplier_input_i;
                premultiply_input_q_reg <= multiplier_input_q;
                premultiply_twiddle_re_reg <= twiddle_re_reg;
                premultiply_twiddle_im_reg <= twiddle_im_reg;
                premultiply_x0_i_reg <= x0_i_ext;
                premultiply_x0_q_reg <= x0_q_ext;
                premultiply_sum_i_reg <= sum_i_ext;
                premultiply_sum_q_reg <= sum_q_ext;
                premultiply_half_sum_i_reg <= half_sum_i_ext;
                premultiply_half_sum_q_reg <= half_sum_q_ext;
            end

            case ({arithmetic_stage_fire, multiply_product_fire})
                2'b01, 2'b11: arithmetic_stage_valid <= 1'b1;
                2'b10:        arithmetic_stage_valid <= 1'b0;
                default:      arithmetic_stage_valid <= arithmetic_stage_valid;
            endcase

            if (multiply_product_fire) begin
                arithmetic_uop_reg <= premultiply_uop_reg;
                product_rr_reg <= product_rr[24:0];
                product_iq_reg <= product_iq[24:0];
                product_rq_reg <= product_rq[24:0];
                product_ii_reg <= product_ii[24:0];
                arithmetic_x0_i_reg <= premultiply_x0_i_reg;
                arithmetic_x0_q_reg <= premultiply_x0_q_reg;
                arithmetic_sum_i_reg <= premultiply_sum_i_reg;
                arithmetic_sum_q_reg <= premultiply_sum_q_reg;
                arithmetic_half_sum_i_reg <= premultiply_half_sum_i_reg;
                arithmetic_half_sum_q_reg <= premultiply_half_sum_q_reg;
            end

            if (arithmetic_stage_fire) begin
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
