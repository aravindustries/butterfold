`timescale 1ns/1ps
`default_nettype none

// Reads 128 natural-order time-domain samples and emits a continuous
// interleaved I/Q burst with a 9- or 10-sample cyclic prefix. There is no
// external ready input: the downstream must accept each valid byte.
module tdiq_output_cp_insert (
    input  logic clk,
    input  logic rst_n,

    input  logic       start_i,
    input  logic [3:0] cp_length_i,

    output logic [6:0] sample_addr_o,
    input  logic signed [15:0] sample_i_i,
    input  logic signed [15:0] sample_q_i,

    output logic [7:0] dout,
    output logic       dout_valid_o,

    output logic busy_o,
    output logic done_o
);

    logic       in_cp;
    logic       output_q;
    logic [6:0] sample_index;

    function automatic logic [7:0] saturate_q17_to_byte (
        input logic signed [15:0] value
    );
        begin
            if (value > 16'sd127)
                saturate_q17_to_byte = 8'h7f;
            else if (value < -16'sd128)
                saturate_q17_to_byte = 8'h80;
            else
                saturate_q17_to_byte = value[7:0];
        end
    endfunction

    assign sample_addr_o = sample_index;
    assign dout_valid_o  = busy_o;
    assign dout = output_q
        ? saturate_q17_to_byte(sample_q_i)
        : saturate_q17_to_byte(sample_i_i);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_cp          <= 1'b0;
            output_q       <= 1'b0;
            sample_index   <= 7'd0;
            busy_o         <= 1'b0;
            done_o         <= 1'b0;
        end else begin
            done_o <= 1'b0;

            if (start_i && !busy_o) begin
                in_cp        <= 1'b1;
                output_q     <= 1'b0;
                sample_index <= 8'd128 - {4'd0, cp_length_i};
                busy_o       <= 1'b1;
            end else if (busy_o) begin
                if (!output_q) begin
                    output_q <= 1'b1;
                end else begin
                    output_q <= 1'b0;

                    if (in_cp) begin
                        if (sample_index == 7'd127) begin
                            in_cp        <= 1'b0;
                            sample_index <= 7'd0;
                        end else begin
                            sample_index <= sample_index + 1'b1;
                        end
                    end else begin
                        if (sample_index == 7'd127) begin
                            busy_o <= 1'b0;
                            done_o <= 1'b1;
                        end else begin
                            sample_index <= sample_index + 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
