`timescale 1ns/1ps
`default_nettype none

// AREA STUDY ONLY -- NOT AUTHORITATIVE RTL.
// Two-SRAM top: OFDM samples enter/leave the transform scratch directly.
module butterfold_top #(
    parameter integer TRANSACTION_FIFO_DEPTH = 1,
    parameter integer TX_BYTE_INTERVAL = 1
) (
    input logic rst_n, input logic clk,
    input logic [7:0] din, input logic din_valid_i,
    output logic din_ready_o, output logic [7:0] dout,
    output logic dout_valid_o
);
    localparam logic [7:0] CMD_FFT2=8'h40, CMD_FFT128=8'h41,
        CMD_IFFT128=8'h42, CMD_IFFT2=8'h43, CMD_FFT3=8'h44,
        CMD_DFT12=8'h45, CMD_RX_SHORT=8'h46, CMD_RX_LONG=8'h47,
        CMD_TX_SHORT=8'h48, CMD_TX_LONG=8'h49;

    function automatic logic is_standalone(input logic [7:0] c);
        is_standalone = (c>=CMD_FFT2 && c<=CMD_DFT12);
    endfunction
    function automatic logic is_ofdm(input logic [7:0] c);
        is_ofdm = (c>=CMD_RX_SHORT && c<=CMD_TX_LONG);
    endfunction
    function automatic logic is_rx(input logic [7:0] c);
        is_rx = (c==CMD_RX_SHORT || c==CMD_RX_LONG);
    endfunction
    function automatic [8:0] input_bytes(input logic [7:0] c);
        case(c)
          CMD_RX_SHORT: input_bytes=9'd274;
          CMD_RX_LONG:  input_bytes=9'd276;
          CMD_TX_SHORT,CMD_TX_LONG: input_bytes=9'd24;
          default: input_bytes=0;
        endcase
    endfunction
    function automatic [8:0] output_bytes(input logic [7:0] c);
        case(c)
          CMD_RX_SHORT,CMD_RX_LONG: output_bytes=9'd24;
          CMD_TX_SHORT: output_bytes=9'd274;
          CMD_TX_LONG:  output_bytes=9'd276;
          default: output_bytes=0;
        endcase
    endfunction

    logic signed [15:0] core_X0_i,core_X0_q,core_X1_i,core_X1_q,core_X2_i,core_X2_q;
    logic [6:0] core_addr0,core_addr1,core_addr2;
    logic [1:0] core_radix;
    logic core_last,core_result_valid,core_result_ready;
    logic [7:0] core_dout;
    logic core_dout_valid,core_din_ready;

    logic standalone_active, ofdm_active;
    logic [7:0] active_command;
    logic [8:0] input_left, output_left;
    logic serializer_ready,serializer_valid,serializer_busy,serializer_done,serializer_job_done;
    logic [7:0] serializer_dout;

    // Compatibility/measurement names intentionally retained for the existing
    // immutable regression bench.
    logic [2:0] ext_state;
    logic external_fire, feeder_start, job_push;
    logic [7:0] job_head_command;
    logic core_ofdm_active, drain_active;
    logic core_rx_selected_complete,core_rx_complete,core_tx_complete;

    assign external_fire = din_valid_i && din_ready_o;
    assign feeder_start = external_fire && !ofdm_active && !standalone_active && is_ofdm(din);
    assign job_head_command = active_command;
    assign core_ofdm_active = ofdm_active;
    assign drain_active = ofdm_active && (input_left==0);
    assign ext_state = (ofdm_active && input_left!=0) ? 3'd1 :
                       ((ofdm_active || standalone_active) ? 3'd3 : 3'd0);
    assign din_ready_o = (!ofdm_active || standalone_active) ? core_din_ready :
                         ((input_left!=0) ? core_din_ready : 1'b0);

    transform_scheduler_core #(
        .TRANSACTION_FIFO_DEPTH(TRANSACTION_FIFO_DEPTH),
        .TX_BYTE_INTERVAL(TX_BYTE_INTERVAL)
    )
      u_transform_scheduler_core (
        .clk(clk),.rst_n(rst_n),.din(din),.din_valid_i(din_valid_i && din_ready_o),
        .din_ready_o(core_din_ready),
        .X0_i_o(core_X0_i),.X0_q_o(core_X0_q),.X1_i_o(core_X1_i),.X1_q_o(core_X1_q),
        .X2_i_o(core_X2_i),.X2_q_o(core_X2_q),
        .result_addr0_o(core_addr0),.result_addr1_o(core_addr1),.result_addr2_o(core_addr2),
        .result_radix_o(core_radix),.result_last_o(core_last),
        .result_valid_o(core_result_valid),.result_ready_i(core_result_ready),
        .dout(core_dout),.dout_valid_o(core_dout_valid),
        .debug_mode_i(1'b0),.debug_req_i(1'b0),.debug_write_i(1'b0),
        .debug_addr_i(8'd0),.debug_wdata_i(16'd0),.debug_ready_o(),
        .debug_rdata_o(),.debug_rvalid_o());

    standalone_result_serializer u_serializer (
        .clk(clk),.rst_n(rst_n),.enable_i(standalone_active),
        .X0_i_i(core_X0_i),.X0_q_i(core_X0_q),.X1_i_i(core_X1_i),.X1_q_i(core_X1_q),
        .X2_i_i(core_X2_i),.X2_q_i(core_X2_q),
        .result_addr0_i(core_addr0),.result_addr1_i(core_addr1),.result_addr2_i(core_addr2),
        .result_radix_i(core_radix),.result_last_i(core_last),
        .result_valid_i(core_result_valid),.result_ready_o(serializer_ready),
        .dout_o(serializer_dout),.dout_valid_o(serializer_valid),.busy_o(serializer_busy),
        .transaction_done_o(serializer_done),.job_done_o(serializer_job_done));

    assign core_result_ready = standalone_active ? serializer_ready : 1'b1;
    assign dout = serializer_valid ? serializer_dout : core_dout;
    assign dout_valid_o = serializer_valid || core_dout_valid;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            standalone_active<=0; ofdm_active<=0; active_command<=0;
            input_left<=0; output_left<=0; job_push<=0;
            core_rx_selected_complete<=0; core_rx_complete<=0; core_tx_complete<=0;
        end else begin
            job_push<=0; core_rx_selected_complete<=0; core_rx_complete<=0; core_tx_complete<=0;
            if(external_fire && !ofdm_active && !standalone_active) begin
                if(is_standalone(din)) begin standalone_active<=1; active_command<=din; end
                else if(is_ofdm(din)) begin
                    ofdm_active<=1; active_command<=din;
                    input_left<=input_bytes(din); output_left<=output_bytes(din);
                end
            end else if(external_fire && ofdm_active && input_left!=0) begin
                input_left<=input_left-1'b1;
                if(input_left==1) job_push<=1;
            end
            if(serializer_job_done) standalone_active<=0;
            if(core_dout_valid && ofdm_active) begin
                output_left<=output_left-1'b1;
                if(output_left==1) begin
                    ofdm_active<=0;
                    if(is_rx(active_command)) begin
                        core_rx_selected_complete<=1; core_rx_complete<=1;
                    end else core_tx_complete<=1;
                end
            end
        end
    end
endmodule
`default_nettype wire
