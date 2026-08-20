`default_nettype none

// Converts exactly 12 interleaved 8-bit signed Q1.7 frequency-domain samples
// into a latency-insensitive 16-bit complex-sample stream. The binary point is
// unchanged: the 8-bit components are sign-extended to the internal F=7 format.
module fdiq_input_adapter (
    input  logic clk,
    input  logic rst_n,

    input  logic start_i,

    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,

    output logic signed [15:0] sample_i_o,
    output logic signed [15:0] sample_q_o,
    output logic        [3:0]  sample_index_o,
    output logic               sample_valid_o,
    input  logic               sample_ready_i,

    output logic busy_o,
    output logic done_o
);

    logic expect_q;
    logic signed [15:0] held_i;
    logic [3:0] input_sample_index;

    logic sample_full;
    logic signed [15:0] sample_i_reg;
    logic signed [15:0] sample_q_reg;
    logic [3:0] sample_index_reg;

    logic final_sample_pending;
    logic byte_fire;
    logic sample_fire;
    logic output_slot_available;
    logic produce_sample;

    function automatic logic signed [15:0] sign_extend_q17 (
        input logic [7:0] value
    );
        begin
            sign_extend_q17 = $signed({{8{value[7]}}, value});
        end
    endfunction

    assign sample_i_o     = sample_i_reg;
    assign sample_q_o     = sample_q_reg;
    assign sample_index_o = sample_index_reg;
    assign sample_valid_o = sample_full;

    assign sample_fire = sample_full && sample_ready_i;
    assign output_slot_available = !sample_full || sample_ready_i;

    // I bytes only fill held_i. Q bytes complete an output token and therefore
    // require a free output slot.
    always @* begin
        din_ready_o = 1'b0;
        if (busy_o) begin
            if (!expect_q)
                din_ready_o = 1'b1;
            else
                din_ready_o = output_slot_available;
        end
    end

    assign byte_fire = din_valid_i && din_ready_o;
    assign produce_sample = byte_fire && expect_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expect_q            <= 1'b0;
            held_i              <= 16'sd0;
            input_sample_index  <= 4'd0;

            sample_full         <= 1'b0;
            sample_i_reg        <= 16'sd0;
            sample_q_reg        <= 16'sd0;
            sample_index_reg    <= 4'd0;

            final_sample_pending <= 1'b0;
            busy_o               <= 1'b0;
            done_o               <= 1'b0;
        end else begin
            done_o <= 1'b0;

            if (start_i && !busy_o && !final_sample_pending) begin
                expect_q             <= 1'b0;
                held_i               <= 16'sd0;
                input_sample_index   <= 4'd0;
                sample_full          <= 1'b0;
                final_sample_pending <= 1'b0;
                busy_o               <= 1'b1;
            end else begin
                case ({sample_fire, produce_sample})
                    2'b10: sample_full <= 1'b0;
                    2'b01,
                    2'b11: sample_full <= 1'b1;
                    default: sample_full <= sample_full;
                endcase

                if (produce_sample) begin
                    sample_i_reg     <= held_i;
                    sample_q_reg     <= sign_extend_q17(din);
                    sample_index_reg <= input_sample_index;
                end

                if (byte_fire) begin
                    if (!expect_q) begin
                        held_i   <= sign_extend_q17(din);
                        expect_q <= 1'b1;
                    end else begin
                        expect_q <= 1'b0;
                        if (input_sample_index == 4'd11) begin
                            busy_o <= 1'b0;
                            final_sample_pending <= 1'b1;
                        end else begin
                            input_sample_index <= input_sample_index + 1'b1;
                        end
                    end
                end

                if (
                    final_sample_pending &&
                    sample_fire &&
                    !produce_sample
                ) begin
                    final_sample_pending <= 1'b0;
                    done_o <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
