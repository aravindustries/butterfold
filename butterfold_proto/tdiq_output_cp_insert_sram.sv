`timescale 1ns/1ps
`default_nettype none

// SRAM-aware time-domain output adapter with 9/10-sample normal CP insertion.
module tdiq_output_cp_insert_sram (
    input  logic clk,
    input  logic rst_n,
    input  logic start_i,
    input  logic [3:0] cp_length_i,

    output logic        mem_req_o,
    output logic [6:0]  mem_addr_o,
    input  logic [31:0] mem_rdata_i,
    input  logic        mem_rvalid_i,

    output logic [7:0] dout,
    output logic       dout_valid_o,
    output logic busy_o,
    output logic done_o
);
    typedef enum logic [2:0] {IDLE, READ_REQ, READ_WAIT, OUT_I, OUT_Q} state_t;
    state_t state;
    logic in_cp;
    logic [6:0] sample_index;
    logic signed [15:0] sample_i_reg, sample_q_reg;

    function automatic logic [7:0] saturate_q17_to_byte(input logic signed [15:0] value);
        begin
            if (value > 16'sd127) saturate_q17_to_byte = 8'h7f;
            else if (value < -16'sd128) saturate_q17_to_byte = 8'h80;
            else saturate_q17_to_byte = value[7:0];
        end
    endfunction

    always @* begin
        mem_req_o = (state == READ_REQ);
        mem_addr_o = sample_index;
        dout_valid_o = (state == OUT_I) || (state == OUT_Q);
        dout = (state == OUT_Q)
            ? saturate_q17_to_byte(sample_q_reg)
            : saturate_q17_to_byte(sample_i_reg);
        busy_o = (state != IDLE);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            in_cp <= 1'b0;
            sample_index <= 7'd0;
            sample_i_reg <= '0;
            sample_q_reg <= '0;
            done_o <= 1'b0;
        end else begin
            done_o <= 1'b0;
            case (state)
                IDLE: if (start_i) begin
                    in_cp <= 1'b1;
                    sample_index <= 8'd128 - {4'd0, cp_length_i};
                    state <= READ_REQ;
                end
                READ_REQ: state <= READ_WAIT;
                READ_WAIT: if (mem_rvalid_i) begin
                    sample_i_reg <= $signed(mem_rdata_i[15:0]);
                    sample_q_reg <= $signed(mem_rdata_i[31:16]);
                    state <= OUT_I;
                end
                OUT_I: state <= OUT_Q;
                OUT_Q: begin
                    if (in_cp) begin
                        if (sample_index == 7'd127) begin
                            in_cp <= 1'b0;
                            sample_index <= 7'd0;
                        end else sample_index <= sample_index + 1'b1;
                        state <= READ_REQ;
                    end else if (sample_index == 7'd127) begin
                        state <= IDLE;
                        done_o <= 1'b1;
                    end else begin
                        sample_index <= sample_index + 1'b1;
                        state <= READ_REQ;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
