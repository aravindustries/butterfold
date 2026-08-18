`timescale 1ns/1ps
`default_nettype none

// ButterFold authoritative two-SRAM final-pin top.
//
// This wrapper intentionally contains no behavioral control logic.  It is the
// structural integration boundary for module-level layout: the command FSM lives
// in butterfold_top_control, and this module only declares interconnect and
// instantiates the control, transform scheduler, and standalone serializer.
module butterfold_top #(
    parameter integer TRANSACTION_FIFO_DEPTH = 1,
    parameter integer TX_BYTE_INTERVAL = 1
) (
    input  logic       rst_n,
    input  logic       clk,
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,
    output logic [7:0] dout,
    output logic       dout_valid_o
`ifdef USE_POWER_PINS
    , inout wire VDD
    , inout wire VSS
`endif
);
    logic signed [15:0] core_X0_i, core_X0_q, core_X1_i, core_X1_q;
    logic signed [15:0] core_X2_i, core_X2_q;
    logic [6:0] core_addr0, core_addr1, core_addr2;
    logic [1:0] core_radix;
    logic core_last, core_result_valid, core_result_ready;
    logic [7:0] core_dout;
    logic core_dout_valid, core_din_ready, core_din_valid;

    logic standalone_active;
    logic serializer_ready, serializer_valid, serializer_busy;
    logic serializer_done, serializer_job_done;
    logic [7:0] serializer_dout;

    logic debug_mode, debug_req, debug_write, debug_ready, debug_rvalid;
    logic [7:0] debug_addr;
    logic [15:0] debug_wdata, debug_rdata;

    // Compatibility/measurement names used by the established regression.
    logic [2:0] ext_state;
    logic [4:0] top_state;
    logic external_fire, feeder_start, job_push;
    logic [7:0] job_head_command;
    logic core_ofdm_active, drain_active;
    logic core_rx_selected_complete, core_rx_complete, core_tx_complete;

    butterfold_top_control u_top_control (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .din_valid_i(din_valid_i),
        .din_ready_o(din_ready_o),
        .dout(dout),
        .dout_valid_o(dout_valid_o),
        .core_din_valid_o(core_din_valid),
        .core_din_ready_i(core_din_ready),
        .core_dout_i(core_dout),
        .core_dout_valid_i(core_dout_valid),
        .core_result_ready_o(core_result_ready),
        .standalone_active_o(standalone_active),
        .serializer_ready_i(serializer_ready),
        .serializer_valid_i(serializer_valid),
        .serializer_job_done_i(serializer_job_done),
        .serializer_dout_i(serializer_dout),
        .debug_mode_o(debug_mode),
        .debug_req_o(debug_req),
        .debug_write_o(debug_write),
        .debug_addr_o(debug_addr),
        .debug_wdata_o(debug_wdata),
        .debug_ready_i(debug_ready),
        .debug_rdata_i(debug_rdata),
        .debug_rvalid_i(debug_rvalid),
        .ext_state(ext_state),
        .external_fire(external_fire),
        .feeder_start(feeder_start),
        .job_push(job_push),
        .job_head_command(job_head_command),
        .core_ofdm_active(core_ofdm_active),
        .drain_active(drain_active),
        .core_rx_selected_complete(core_rx_selected_complete),
        .core_rx_complete(core_rx_complete),
        .core_tx_complete(core_tx_complete),
        .top_state_o(top_state)
    );

    transform_scheduler_core #(
        .TRANSACTION_FIFO_DEPTH(TRANSACTION_FIFO_DEPTH),
        .TX_BYTE_INTERVAL(TX_BYTE_INTERVAL)
    ) u_transform_scheduler_core (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .din_valid_i(core_din_valid),
        .din_ready_o(core_din_ready),
        .X0_i_o(core_X0_i),
        .X0_q_o(core_X0_q),
        .X1_i_o(core_X1_i),
        .X1_q_o(core_X1_q),
        .X2_i_o(core_X2_i),
        .X2_q_o(core_X2_q),
        .result_addr0_o(core_addr0),
        .result_addr1_o(core_addr1),
        .result_addr2_o(core_addr2),
        .result_radix_o(core_radix),
        .result_last_o(core_last),
        .result_valid_o(core_result_valid),
        .result_ready_i(core_result_ready),
        .dout(core_dout),
        .dout_valid_o(core_dout_valid),
        .debug_mode_i(debug_mode),
        .debug_req_i(debug_req),
        .debug_write_i(debug_write),
        .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata),
        .debug_ready_o(debug_ready),
        .debug_rdata_o(debug_rdata),
        .debug_rvalid_o(debug_rvalid)
`ifdef USE_POWER_PINS
        , .VDD(VDD), .VSS(VSS)
`endif
    );

    standalone_result_serializer u_serializer (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(standalone_active),
        .X0_i_i(core_X0_i),
        .X0_q_i(core_X0_q),
        .X1_i_i(core_X1_i),
        .X1_q_i(core_X1_q),
        .X2_i_i(core_X2_i),
        .X2_q_i(core_X2_q),
        .result_addr0_i(core_addr0),
        .result_addr1_i(core_addr1),
        .result_addr2_i(core_addr2),
        .result_radix_i(core_radix),
        .result_last_i(core_last),
        .result_valid_i(core_result_valid),
        .result_ready_o(serializer_ready),
        .dout_o(serializer_dout),
        .dout_valid_o(serializer_valid),
        .busy_o(serializer_busy),
        .transaction_done_o(serializer_done),
        .job_done_o(serializer_job_done)
    );
endmodule

`default_nettype wire
