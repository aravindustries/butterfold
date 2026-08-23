`timescale 1ns/1ps
`default_nettype none

// Stream-side one-RB extractor for the OFDM_RX path.
//
// The transform scheduler emits all 64 FFT bins as an interleaved byte stream.
// This block forwards only SC_COUNT consecutive bins beginning at SC_START_BIN.
// There is intentionally no output backpressure; the downstream scheduler
// captures every selected byte when selected_valid_o is asserted.
module subcarrier_extractor #(
    parameter integer SC_START_BIN = 1,
    parameter integer SC_COUNT     = 12,
    parameter integer INPUT_BIN_COUNT = 64
) (
    input  logic clk,
    input  logic rst_n,

    input  logic start_i,
    input  logic [7:0] din_i,
    input  logic       din_valid_i,

    output logic [7:0] selected_data_o,
    output logic       selected_valid_o,
    output logic       busy_o,
    output logic       done_o
);

    logic [7:0] byte_index;
    logic [6:0] bin_index;
    logic       selected_bin;

    assign bin_index = byte_index[7:1];
    assign selected_bin =
        (bin_index >= SC_START_BIN) &&
        (bin_index < (SC_START_BIN + SC_COUNT));

    assign selected_data_o  = din_i;
    assign selected_valid_o = busy_o && din_valid_i && selected_bin;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_index <= 8'd0;
            busy_o     <= 1'b0;
            done_o     <= 1'b0;
        end else begin
            done_o <= 1'b0;

            if (start_i && !busy_o) begin
                byte_index <= 8'd0;
                busy_o     <= 1'b1;
            end else if (busy_o && din_valid_i) begin
                if (byte_index == (2 * INPUT_BIN_COUNT) - 1) begin
                    byte_index <= 8'd0;
                    busy_o     <= 1'b0;
                    done_o     <= 1'b1;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
