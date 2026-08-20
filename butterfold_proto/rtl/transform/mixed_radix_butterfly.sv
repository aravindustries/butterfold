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
    logic combine_stage_valid;
    logic combine_stage_fire;
    logic combine_stage_available;
    logic [2:0] multiply_phase;
    logic multiply_product_fire;
    logic final_scalar_pending;
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

    logic out_full;
    logic signed [15:0] X0_i_reg, X0_q_reg, X1_i_reg, X1_q_reg, X2_i_reg, X2_q_reg;
    assign out_valid = out_full;
    assign X0_i=X0_i_reg; assign X0_q=X0_q_reg;
    assign X1_i=X1_i_reg; assign X1_q=X1_q_reg;
    assign X2_i=X2_i_reg; assign X2_q=X2_q_reg;

    assign output_available = !out_full || out_ready;

    assign radix2_inputs_full =
        uop_full && (uop_reg == UOP_RADIX2) &&
        x0_i_full && x0_q_full && x1_i_full && x1_q_full &&
        twiddle_re_full && twiddle_im_full;

    assign radix3_inputs_full =
        uop_full && (uop_reg == UOP_RADIX3) &&
        x0_i_full && x0_q_full && x1_i_full && x1_q_full &&
        x2_i_full && x2_q_full && twiddle_re_full && twiddle_im_full;

    assign combine_stage_fire = combine_stage_valid && output_available;
    assign combine_stage_available = !combine_stage_valid || combine_stage_fire;
    assign arithmetic_stage_fire =
        arithmetic_stage_valid && combine_stage_available;
    assign arithmetic_stage_available =
        !arithmetic_stage_valid || arithmetic_stage_fire;

    assign multiply_product_fire = premultiply_stage_valid &&
        (multiply_phase == 3'd7) && arithmetic_stage_available;
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
        (selected_radix2 || selected_radix3) && (!x0_i_full || compute_fire);
    assign x0_q_ready =
        (selected_radix2 || selected_radix3) && (!x0_q_full || compute_fire);

    assign x1_i_ready =
        (selected_radix2 || selected_radix3) && (!x1_i_full || compute_fire);
    assign x1_q_ready =
        (selected_radix2 || selected_radix3) && (!x1_q_full || compute_fire);

    assign x2_i_ready =
        selected_radix3 && (!x2_i_full || consume_x2);
    assign x2_q_ready =
        selected_radix3 && (!x2_q_full || consume_x2);

    assign twiddle_re_ready =
        (selected_radix2 || selected_radix3) && (!twiddle_re_full || compute_fire);
    assign twiddle_im_ready =
        (selected_radix2 || selected_radix3) && (!twiddle_im_full || compute_fire);

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

    // One 8x10 scalar multiplier implements all eight partial products of the
    // complex multiply. A signed 17-bit operand is decomposed exactly as
    // high*512 + unsigned(low); phases 0..3 evaluate the low chunks and phases
    // 4..7 evaluate the signed high chunks. This preserves the original four-
    // product arithmetic and every truncation point while removing three
    // simultaneous scalar multipliers.
    logic signed [9:0] multiplier_chunk_i;
    logic signed [9:0] multiplier_chunk_q;
    logic signed [7:0] scalar_coefficient;
    logic signed [9:0] scalar_operand;
    logic signed [9:0] scalar_operand_reg;
    logic signed [17:0] scalar_partial;
    logic signed [17:0] final_scalar_product_reg;
    logic signed [7:0] scalar_coefficient_reg;
    logic signed [9:0] next_scalar_operand;
    logic signed [7:0] next_scalar_coefficient;
    logic signed [17:0] low_rr_reg;
    logic signed [17:0] low_iq_reg;
    logic signed [17:0] low_rq_reg;
    logic signed [17:0] low_ii_reg;
    logic signed [17:0] high_rr_reg;
    logic signed [17:0] high_iq_reg;
    logic signed [17:0] high_rq_reg;
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
    logic signed [26:0] premultiply_x0_i_reg, premultiply_x0_q_reg;
    logic signed [26:0] premultiply_sum_i_reg, premultiply_sum_q_reg;
    logic signed [26:0] premultiply_half_sum_i_reg, premultiply_half_sum_q_reg;


    // Pipeline cut after the four shared complex-multiply partial products.
    // These registers preserve every pre-existing width/truncation point.
    logic [1:0] arithmetic_uop_reg;
    logic signed [24:0] product_rr_reg;
    logic signed [24:0] product_iq_reg;
    logic signed [24:0] product_rq_reg;
    logic signed [24:0] product_ii_reg;
    logic signed [26:0] arithmetic_x0_i_reg, arithmetic_x0_q_reg;
    logic signed [26:0] arithmetic_sum_i_reg, arithmetic_sum_q_reg;
    logic signed [26:0] arithmetic_half_sum_i_reg, arithmetic_half_sum_q_reg;

    // Retiming cut between product reconstruction/scaling and the final
    // radix add/subtract.  This adds latency but not throughput: the stage is
    // elastic and accepts one completed complex product every eight cycles.
    logic [1:0] combine_uop_reg;
    logic signed [26:0] combine_product_re_reg, combine_product_im_reg;
    logic signed [26:0] combine_x0_i_reg, combine_x0_q_reg;
    logic signed [26:0] combine_sum_i_reg, combine_sum_q_reg;
    logic signed [26:0] combine_half_sum_i_reg, combine_half_sum_q_reg;

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

        if (multiply_phase >= 3'd4) begin
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

        // The phase schedule is deterministic.  Register the operands for the
        // following product while the current 8x10 multiply is in flight, so
        // phase/radix selection is not in the multiplier's same-cycle cone.
        case (multiply_phase + 3'd1)
            3'd1: begin next_scalar_coefficient = premultiply_twiddle_im_reg;
                next_scalar_operand = {1'b0, premultiply_input_q_reg[8:0]}; end
            3'd2: begin next_scalar_coefficient = premultiply_twiddle_re_reg;
                next_scalar_operand = {1'b0, premultiply_input_q_reg[8:0]}; end
            3'd3: begin next_scalar_coefficient = premultiply_twiddle_im_reg;
                next_scalar_operand = {1'b0, premultiply_input_i_reg[8:0]}; end
            3'd4: begin next_scalar_coefficient = premultiply_twiddle_re_reg;
                next_scalar_operand = {{2{premultiply_input_i_reg[16]}},
                    premultiply_input_i_reg[16:9]}; end
            3'd5: begin next_scalar_coefficient = premultiply_twiddle_im_reg;
                next_scalar_operand = {{2{premultiply_input_q_reg[16]}},
                    premultiply_input_q_reg[16:9]}; end
            3'd6: begin next_scalar_coefficient = premultiply_twiddle_re_reg;
                next_scalar_operand = {{2{premultiply_input_q_reg[16]}},
                    premultiply_input_q_reg[16:9]}; end
            default: begin next_scalar_coefficient = premultiply_twiddle_im_reg;
                next_scalar_operand = {{2{premultiply_input_i_reg[16]}},
                    premultiply_input_i_reg[16:9]}; end
        endcase
        scalar_coefficient = scalar_coefficient_reg;
        scalar_operand = scalar_operand_reg;
        scalar_partial = $signed(scalar_coefficient_reg) *
            $signed(scalar_operand_reg);

        product_rr = ($signed({{8{high_rr_reg[17]}}, high_rr_reg}) <<< 9) +
            $signed({{8{low_rr_reg[17]}}, low_rr_reg});
        product_iq = ($signed({{8{high_iq_reg[17]}}, high_iq_reg}) <<< 9) +
            $signed({{8{low_iq_reg[17]}}, low_iq_reg});
        product_rq = ($signed({{8{high_rq_reg[17]}}, high_rq_reg}) <<< 9) +
            $signed({{8{low_rq_reg[17]}}, low_rq_reg});
        product_ii = ($signed({{8{final_scalar_product_reg[17]}}, final_scalar_product_reg}) <<< 9) +
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

        radix3_base_i = combine_x0_i_reg - combine_half_sum_i_reg;
        radix3_base_q = combine_x0_q_reg - combine_half_sum_q_reg;

        if (combine_uop_reg == UOP_RADIX3) begin
            next_X0_i_wide = combine_x0_i_reg + combine_sum_i_reg;
            next_X0_q_wide = combine_x0_q_reg + combine_sum_q_reg;

            next_X1_i_wide = radix3_base_i + combine_product_re_reg;
            next_X1_q_wide = radix3_base_q + combine_product_im_reg;

            next_X2_i_wide = radix3_base_i - combine_product_re_reg;
            next_X2_q_wide = radix3_base_q - combine_product_im_reg;
        end else begin
            next_X0_i_wide = combine_x0_i_reg + combine_product_re_reg;
            next_X0_q_wide = combine_x0_q_reg + combine_product_im_reg;

            next_X1_i_wide = combine_x0_i_reg - combine_product_re_reg;
            next_X1_q_wide = combine_x0_q_reg - combine_product_im_reg;

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
            multiply_phase <= 3'd0;
            low_rr_reg <= '0;
            low_iq_reg <= '0;
            low_rq_reg <= '0;
            low_ii_reg <= '0;
            high_rr_reg <= '0;
            high_iq_reg <= '0;
            high_rq_reg <= '0;
            scalar_coefficient_reg <= '0;
            scalar_operand_reg <= '0;
            final_scalar_product_reg <= '0;
            final_scalar_pending <= 1'b0;
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

            combine_stage_valid <= 1'b0;
            combine_uop_reg <= '0;
            combine_product_re_reg <= '0;
            combine_product_im_reg <= '0;
            combine_x0_i_reg <= '0;
            combine_x0_q_reg <= '0;
            combine_sum_i_reg <= '0;
            combine_sum_q_reg <= '0;
            combine_half_sum_i_reg <= '0;
            combine_half_sum_q_reg <= '0;

            out_full <= 1'b0;
            X0_i_reg <= '0; X0_q_reg <= '0;
            X1_i_reg <= '0; X1_q_reg <= '0;
            X2_i_reg <= '0; X2_q_reg <= '0;

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

            if (premultiply_stage_valid) begin
                case (multiply_phase)
                    3'd0: low_rr_reg  <= scalar_partial;
                    3'd1: low_iq_reg  <= scalar_partial;
                    3'd2: low_rq_reg  <= scalar_partial;
                    3'd3: low_ii_reg  <= scalar_partial;
                    3'd4: high_rr_reg <= scalar_partial;
                    3'd5: high_iq_reg <= scalar_partial;
                    3'd6: high_rq_reg <= scalar_partial;
                    default: final_scalar_product_reg <= scalar_partial;
                endcase
                if (multiply_product_fire)
                    multiply_phase <= 3'd0;
                else
                    multiply_phase <= multiply_phase + 1'b1;
                if (!multiply_product_fire) begin
                    scalar_coefficient_reg <= next_scalar_coefficient;
                    scalar_operand_reg <= next_scalar_operand;
                end
            end else begin
                multiply_phase <= 3'd0;
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
                // Product phase 0 is selected directly from the accepting
                // operands.  This avoids a pipeline-fill cycle, including
                // the back-to-back phase-7/phase-0 boundary.
                scalar_coefficient_reg <= twiddle_re_reg;
                scalar_operand_reg <= {1'b0, multiplier_input_i[8:0]};
            end

            if (multiply_product_fire)
                final_scalar_pending <= 1'b1;
            else if (final_scalar_pending)
                final_scalar_pending <= 1'b0;

            case ({arithmetic_stage_fire, final_scalar_pending})
                2'b01, 2'b11: arithmetic_stage_valid <= 1'b1;
                2'b10:        arithmetic_stage_valid <= 1'b0;
                default:      arithmetic_stage_valid <= arithmetic_stage_valid;
            endcase

            if (multiply_product_fire) begin
                arithmetic_uop_reg <= premultiply_uop_reg;
                product_rr_reg <= product_rr[24:0];
                product_iq_reg <= product_iq[24:0];
                product_rq_reg <= product_rq[24:0];
                arithmetic_x0_i_reg <= premultiply_x0_i_reg;
                arithmetic_x0_q_reg <= premultiply_x0_q_reg;
                arithmetic_sum_i_reg <= premultiply_sum_i_reg;
                arithmetic_sum_q_reg <= premultiply_sum_q_reg;
                arithmetic_half_sum_i_reg <= premultiply_half_sum_i_reg;
                arithmetic_half_sum_q_reg <= premultiply_half_sum_q_reg;
            end

            if (final_scalar_pending)
                product_ii_reg <= product_ii[24:0];

            case ({combine_stage_fire, arithmetic_stage_fire})
                2'b01, 2'b11: combine_stage_valid <= 1'b1;
                2'b10:        combine_stage_valid <= 1'b0;
                default:      combine_stage_valid <= combine_stage_valid;
            endcase

            if (arithmetic_stage_fire) begin
                combine_uop_reg <= arithmetic_uop_reg;
                combine_product_re_reg <= product_re_ext;
                combine_product_im_reg <= product_im_ext;
                combine_x0_i_reg <= arithmetic_x0_i_reg;
                combine_x0_q_reg <= arithmetic_x0_q_reg;
                combine_sum_i_reg <= arithmetic_sum_i_reg;
                combine_sum_q_reg <= arithmetic_sum_q_reg;
                combine_half_sum_i_reg <= arithmetic_half_sum_i_reg;
                combine_half_sum_q_reg <= arithmetic_half_sum_q_reg;
            end

            if (combine_stage_fire) begin
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
