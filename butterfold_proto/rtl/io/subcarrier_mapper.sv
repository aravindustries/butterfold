`timescale 1ns/1ps
`default_nettype none

// Builds a 128-bin bit-reversed IFFT input grid from 12 natural-order DFT
// outputs. The first implementation maps D[0:11] to natural bins 1:12,
// leaving DC bin zero unused. It first clears all 128 physical RAM locations,
// then performs the 12 nonzero writes.
module subcarrier_mapper #(
    parameter logic [6:0] SC_START_BIN = 7'd1
) (
    input  logic clk,
    input  logic rst_n,

    input  logic start_i,

    output logic [3:0] source_addr_o,
    input  logic signed [15:0] source_i_i,
    input  logic signed [15:0] source_q_i,

    output logic       write_valid_o,
    output logic [6:0] write_addr_o,
    output logic signed [15:0] write_i_o,
    output logic signed [15:0] write_q_o,
    input  logic       write_ready_i,

    output logic busy_o,
    output logic done_o
);

    logic clear_phase;
    logic [6:0] clear_index;
    logic [3:0] map_index;

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

    assign source_addr_o = map_index;
    assign write_valid_o = busy_o;

    always @* begin
        if (clear_phase) begin
            write_addr_o = clear_index;
            write_i_o = 16'sd0;
            write_q_o = 16'sd0;
        end else begin
            write_addr_o = bit_reverse7(SC_START_BIN + map_index);
            write_i_o = source_i_i;
            write_q_o = source_q_i;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_phase <= 1'b1;
            clear_index <= 7'd0;
            map_index   <= 4'd0;
            busy_o      <= 1'b0;
            done_o      <= 1'b0;
        end else begin
            done_o <= 1'b0;

            if (start_i && !busy_o) begin
                clear_phase <= 1'b1;
                clear_index <= 7'd0;
                map_index   <= 4'd0;
                busy_o      <= 1'b1;
            end else if (busy_o && write_ready_i) begin
                if (clear_phase) begin
                    if (clear_index == 7'd127) begin
                        clear_phase <= 1'b0;
                        map_index <= 4'd0;
                    end else begin
                        clear_index <= clear_index + 1'b1;
                    end
                end else begin
                    if (map_index == 4'd11) begin
                        busy_o <= 1'b0;
                        done_o <= 1'b1;
                    end else begin
                        map_index <= map_index + 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
