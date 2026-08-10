`timescale 1ns/1ps
`default_nettype none

// ButterFold authoritative two-SRAM final-pin top.
//
// Large memory is exactly two parallel GF180 256x8 macros inside the
// transform core. RX capture, FFT/IFFT, TX waveform readout, and idle-only
// post-silicon SRAM debug commands share that one physical 256x16 port.
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
);
    localparam logic [7:0] CMD_FFT2       = 8'h40;
    localparam logic [7:0] CMD_FFT128     = 8'h41;
    localparam logic [7:0] CMD_IFFT128    = 8'h42;
    localparam logic [7:0] CMD_IFFT2      = 8'h43;
    localparam logic [7:0] CMD_FFT3       = 8'h44;
    localparam logic [7:0] CMD_DFT12      = 8'h45;
    localparam logic [7:0] CMD_RX_SHORT   = 8'h46;
    localparam logic [7:0] CMD_RX_LONG    = 8'h47;
    localparam logic [7:0] CMD_TX_SHORT   = 8'h48;
    localparam logic [7:0] CMD_TX_LONG    = 8'h49;
    localparam logic [7:0] CMD_ECHO       = 8'h4a;
    localparam logic [7:0] CMD_MAGIC      = 8'h4b;
    localparam logic [7:0] CMD_SRAM_READ  = 8'h4c;
    localparam logic [7:0] CMD_SRAM_WRITE = 8'h4d;

    localparam logic [7:0] SRAM_WRITE_ACK = 8'hac;

    function automatic logic is_standalone(input logic [7:0] c);
        is_standalone = (c >= CMD_FFT2) && (c <= CMD_DFT12);
    endfunction
    function automatic logic is_ofdm(input logic [7:0] c);
        is_ofdm = (c >= CMD_RX_SHORT) && (c <= CMD_TX_LONG);
    endfunction
    function automatic logic is_rx(input logic [7:0] c);
        is_rx = (c == CMD_RX_SHORT) || (c == CMD_RX_LONG);
    endfunction
    function automatic [8:0] transform_input_bytes(input logic [7:0] c);
        case (c)
          CMD_FFT2, CMD_IFFT2: transform_input_bytes = 9'd4;
          CMD_FFT3:            transform_input_bytes = 9'd6;
          CMD_FFT128,
          CMD_IFFT128:         transform_input_bytes = 9'd256;
          CMD_DFT12:           transform_input_bytes = 9'd24;
          CMD_RX_SHORT:        transform_input_bytes = 9'd274;
          CMD_RX_LONG:         transform_input_bytes = 9'd276;
          CMD_TX_SHORT,
          CMD_TX_LONG:         transform_input_bytes = 9'd24;
          default:             transform_input_bytes = 9'd0;
        endcase
    endfunction
    function automatic [8:0] ofdm_output_bytes(input logic [7:0] c);
        case (c)
          CMD_RX_SHORT, CMD_RX_LONG: ofdm_output_bytes = 9'd24;
          CMD_TX_SHORT:              ofdm_output_bytes = 9'd274;
          CMD_TX_LONG:               ofdm_output_bytes = 9'd276;
          default:                   ofdm_output_bytes = 9'd0;
        endcase
    endfunction

    typedef enum logic [4:0] {
        TOP_IDLE,
        TOP_TRANSFORM_INPUT,
        TOP_TRANSFORM_WAIT,
        TOP_ECHO_INPUT,
        TOP_ECHO_OUTPUT,
        TOP_MAGIC_OUTPUT,
        TOP_SRAM_READ_ADDR,
        TOP_SRAM_READ_REQ,
        TOP_SRAM_READ_WAIT,
        TOP_SRAM_READ_HI,
        TOP_SRAM_READ_LO,
        TOP_SRAM_WRITE_ADDR,
        TOP_SRAM_WRITE_HI,
        TOP_SRAM_WRITE_LO,
        TOP_SRAM_WRITE_REQ,
        TOP_SRAM_WRITE_ACK
    } top_state_t;
    top_state_t top_state;

    logic signed [15:0] core_X0_i, core_X0_q, core_X1_i, core_X1_q;
    logic signed [15:0] core_X2_i, core_X2_q;
    logic [6:0] core_addr0, core_addr1, core_addr2;
    logic [1:0] core_radix;
    logic core_last, core_result_valid, core_result_ready;
    logic [7:0] core_dout;
    logic core_dout_valid, core_din_ready, core_din_valid;

    logic standalone_active, ofdm_active;
    logic [7:0] active_command;
    logic [8:0] input_left, output_left;
    logic serializer_ready, serializer_valid, serializer_busy;
    logic serializer_done, serializer_job_done;
    logic [7:0] serializer_dout;

    logic debug_mode, debug_req, debug_write, debug_ready, debug_rvalid;
    logic [7:0] debug_addr;
    logic [15:0] debug_wdata, debug_rdata, debug_read_latch;
    logic [7:0] debug_data_hi;
    logic [7:0] echo_data;
    logic [2:0] magic_index;

    // Compatibility/measurement names used by the established regression.
    logic [2:0] ext_state;
    logic external_fire, feeder_start, job_push;
    logic [7:0] job_head_command;
    logic core_ofdm_active, drain_active;
    logic core_rx_selected_complete, core_rx_complete, core_tx_complete;

    assign external_fire = din_valid_i && din_ready_o;
    assign feeder_start = external_fire && (top_state == TOP_IDLE) && is_ofdm(din);
    assign job_head_command = active_command;
    assign core_ofdm_active = ofdm_active;
    assign drain_active = ofdm_active && (top_state == TOP_TRANSFORM_WAIT);
    assign ext_state = (top_state == TOP_IDLE) ? 3'd0 :
                       ((top_state == TOP_TRANSFORM_INPUT) ? 3'd1 : 3'd3);

    always @* begin
        din_ready_o = 1'b0;
        case (top_state)
          TOP_IDLE:            din_ready_o = core_din_ready;
          TOP_TRANSFORM_INPUT: din_ready_o = core_din_ready;
          TOP_ECHO_INPUT,
          TOP_SRAM_READ_ADDR,
          TOP_SRAM_WRITE_ADDR,
          TOP_SRAM_WRITE_HI,
          TOP_SRAM_WRITE_LO:   din_ready_o = 1'b1;
          default:             din_ready_o = 1'b0;
        endcase
    end

    // Valid is independent of ready.  The core performs the actual
    // valid/ready acceptance, so feeding ready back into valid only creates a
    // long combinational control cone without changing protocol behavior.
    assign core_din_valid = din_valid_i &&
        (((top_state == TOP_IDLE) && (is_standalone(din) || is_ofdm(din))) ||
         (top_state == TOP_TRANSFORM_INPUT));

    assign debug_mode = (top_state == TOP_SRAM_READ_REQ) ||
                        (top_state == TOP_SRAM_READ_WAIT) ||
                        (top_state == TOP_SRAM_WRITE_REQ);
    assign debug_req = (top_state == TOP_SRAM_READ_REQ) ||
                       (top_state == TOP_SRAM_WRITE_REQ);
    assign debug_write = (top_state == TOP_SRAM_WRITE_REQ);

    transform_scheduler_core #(
        .TRANSACTION_FIFO_DEPTH(TRANSACTION_FIFO_DEPTH),
        .TX_BYTE_INTERVAL(TX_BYTE_INTERVAL)
    ) u_transform_scheduler_core (
        .clk(clk), .rst_n(rst_n),
        .din(din), .din_valid_i(core_din_valid), .din_ready_o(core_din_ready),
        .X0_i_o(core_X0_i), .X0_q_o(core_X0_q),
        .X1_i_o(core_X1_i), .X1_q_o(core_X1_q),
        .X2_i_o(core_X2_i), .X2_q_o(core_X2_q),
        .result_addr0_o(core_addr0), .result_addr1_o(core_addr1),
        .result_addr2_o(core_addr2), .result_radix_o(core_radix),
        .result_last_o(core_last), .result_valid_o(core_result_valid),
        .result_ready_i(core_result_ready),
        .dout(core_dout), .dout_valid_o(core_dout_valid),
        .debug_mode_i(debug_mode), .debug_req_i(debug_req),
        .debug_write_i(debug_write), .debug_addr_i(debug_addr),
        .debug_wdata_i(debug_wdata), .debug_ready_o(debug_ready),
        .debug_rdata_o(debug_rdata), .debug_rvalid_o(debug_rvalid)
    );

    standalone_result_serializer u_serializer (
        .clk(clk), .rst_n(rst_n), .enable_i(standalone_active),
        .X0_i_i(core_X0_i), .X0_q_i(core_X0_q),
        .X1_i_i(core_X1_i), .X1_q_i(core_X1_q),
        .X2_i_i(core_X2_i), .X2_q_i(core_X2_q),
        .result_addr0_i(core_addr0), .result_addr1_i(core_addr1),
        .result_addr2_i(core_addr2), .result_radix_i(core_radix),
        .result_last_i(core_last), .result_valid_i(core_result_valid),
        .result_ready_o(serializer_ready), .dout_o(serializer_dout),
        .dout_valid_o(serializer_valid), .busy_o(serializer_busy),
        .transaction_done_o(serializer_done), .job_done_o(serializer_job_done)
    );

    assign core_result_ready = standalone_active ? serializer_ready : 1'b1;

    always @* begin
        dout = 8'h00;
        dout_valid_o = 1'b0;
        if (serializer_valid) begin
            dout = serializer_dout;
            dout_valid_o = 1'b1;
        end else if (core_dout_valid) begin
            dout = core_dout;
            dout_valid_o = 1'b1;
        end else case (top_state)
          TOP_ECHO_OUTPUT: begin dout = echo_data; dout_valid_o = 1'b1; end
          TOP_MAGIC_OUTPUT: begin
            case (magic_index)
              3'd0: dout = 8'h42; // B
              3'd1: dout = 8'h46; // F
              3'd2: dout = 8'h4c; // L
              default: dout = 8'h44; // D
            endcase
            dout_valid_o = 1'b1;
          end
          TOP_SRAM_READ_HI: begin dout = debug_read_latch[15:8]; dout_valid_o = 1'b1; end
          TOP_SRAM_READ_LO: begin dout = debug_read_latch[7:0]; dout_valid_o = 1'b1; end
          TOP_SRAM_WRITE_ACK: begin dout = SRAM_WRITE_ACK; dout_valid_o = 1'b1; end
          default: begin end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_state <= TOP_IDLE;
            standalone_active <= 1'b0;
            ofdm_active <= 1'b0;
            active_command <= 8'd0;
            input_left <= 9'd0;
            output_left <= 9'd0;
            debug_addr <= 8'd0;
            debug_wdata <= 16'd0;
            debug_read_latch <= 16'd0;
            debug_data_hi <= 8'd0;
            echo_data <= 8'd0;
            magic_index <= 3'd0;
            job_push <= 1'b0;
            core_rx_selected_complete <= 1'b0;
            core_rx_complete <= 1'b0;
            core_tx_complete <= 1'b0;
        end else begin
            job_push <= 1'b0;
            core_rx_selected_complete <= 1'b0;
            core_rx_complete <= 1'b0;
            core_tx_complete <= 1'b0;

            case (top_state)
              TOP_IDLE: if (external_fire) begin
                  active_command <= din;
                  if (is_standalone(din) || is_ofdm(din)) begin
                      standalone_active <= is_standalone(din);
                      ofdm_active <= is_ofdm(din);
                      input_left <= transform_input_bytes(din);
                      output_left <= ofdm_output_bytes(din);
                      top_state <= TOP_TRANSFORM_INPUT;
                  end else case (din)
                    CMD_ECHO:       top_state <= TOP_ECHO_INPUT;
                    CMD_MAGIC: begin magic_index <= 3'd0; top_state <= TOP_MAGIC_OUTPUT; end
                    CMD_SRAM_READ:  top_state <= TOP_SRAM_READ_ADDR;
                    CMD_SRAM_WRITE: top_state <= TOP_SRAM_WRITE_ADDR;
                    default:        top_state <= TOP_IDLE;
                  endcase
              end

              TOP_TRANSFORM_INPUT: if (external_fire) begin
                  input_left <= input_left - 1'b1;
                  if (input_left == 9'd1) begin
                      job_push <= is_ofdm(active_command);
                      top_state <= TOP_TRANSFORM_WAIT;
                  end
              end

              TOP_TRANSFORM_WAIT: begin
                  if (standalone_active && serializer_job_done) begin
                      standalone_active <= 1'b0;
                      top_state <= TOP_IDLE;
                  end
                  if (ofdm_active && core_dout_valid) begin
                      output_left <= output_left - 1'b1;
                      if (output_left == 9'd1) begin
                          ofdm_active <= 1'b0;
                          top_state <= TOP_IDLE;
                          if (is_rx(active_command)) begin
                              core_rx_selected_complete <= 1'b1;
                              core_rx_complete <= 1'b1;
                          end else core_tx_complete <= 1'b1;
                      end
                  end
              end

              TOP_ECHO_INPUT: if (external_fire) begin
                  echo_data <= din;
                  top_state <= TOP_ECHO_OUTPUT;
              end
              TOP_ECHO_OUTPUT: top_state <= TOP_IDLE;
              TOP_MAGIC_OUTPUT: begin
                  if (magic_index == 3'd3) top_state <= TOP_IDLE;
                  else magic_index <= magic_index + 1'b1;
              end
              TOP_SRAM_READ_ADDR: if (external_fire) begin
                  debug_addr <= din;
                  top_state <= TOP_SRAM_READ_REQ;
              end
              TOP_SRAM_READ_REQ: if (debug_ready) top_state <= TOP_SRAM_READ_WAIT;
              TOP_SRAM_READ_WAIT: if (debug_rvalid) begin
                  debug_read_latch <= debug_rdata;
                  top_state <= TOP_SRAM_READ_HI;
              end
              TOP_SRAM_READ_HI: top_state <= TOP_SRAM_READ_LO;
              TOP_SRAM_READ_LO: top_state <= TOP_IDLE;
              TOP_SRAM_WRITE_ADDR: if (external_fire) begin
                  debug_addr <= din;
                  top_state <= TOP_SRAM_WRITE_HI;
              end
              TOP_SRAM_WRITE_HI: if (external_fire) begin
                  debug_data_hi <= din;
                  top_state <= TOP_SRAM_WRITE_LO;
              end
              TOP_SRAM_WRITE_LO: if (external_fire) begin
                  debug_wdata <= {debug_data_hi, din};
                  top_state <= TOP_SRAM_WRITE_REQ;
              end
              TOP_SRAM_WRITE_REQ: if (debug_ready) top_state <= TOP_SRAM_WRITE_ACK;
              TOP_SRAM_WRITE_ACK: top_state <= TOP_IDLE;
              default: top_state <= TOP_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
