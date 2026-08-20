`default_nettype none

// Top-level command/control block for ButterFold.
//
// This module owns the byte-stream command FSM, debug protocol, output muxing,
// and regression observability signals that used to live directly in
// butterfold_top.  Keeping it separate lets butterfold_top remain a structural
// integration wrapper for module-level physical design.
module butterfold_top_control (
    input  logic       rst_n,
    input  logic       clk,
    input  logic [7:0] din,
    input  logic       din_valid_i,
    output logic       din_ready_o,
    output logic [7:0] dout,
    output logic       dout_valid_o,

    output logic       core_din_valid_o,
    input  logic       core_din_ready_i,
    input  logic [7:0] core_dout_i,
    input  logic       core_dout_valid_i,
    output logic       core_result_ready_o,

    output logic       standalone_active_o,
    input  logic       serializer_ready_i,
    input  logic       serializer_valid_i,
    input  logic       serializer_job_done_i,
    input  logic [7:0] serializer_dout_i,

    output logic       debug_mode_o,
    output logic       debug_req_o,
    output logic       debug_write_o,
    output logic [7:0] debug_addr_o,
    output logic [15:0] debug_wdata_o,
    input  logic       debug_ready_i,
    input  logic [15:0] debug_rdata_i,
    input  logic       debug_rvalid_i,

    // Compatibility/measurement names used by the established regression.
    output logic [2:0] ext_state,
    output logic       external_fire,
    output logic       feeder_start,
    output logic       job_push,
    output logic [7:0] job_head_command,
    output logic       core_ofdm_active,
    output logic       drain_active,
    output logic       core_rx_selected_complete,
    output logic       core_rx_complete,
    output logic       core_tx_complete,
    output logic [4:0] top_state_o
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

    function automatic logic [8:0] transform_input_bytes(input logic [7:0] c);
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

    function automatic logic [8:0] ofdm_output_bytes(input logic [7:0] c);
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
    assign top_state_o = top_state;

    logic ofdm_active;
    logic [7:0] active_command;
    logic [8:0] input_left, output_left;
    logic [15:0] debug_read_latch;
    logic [7:0] debug_data_hi;
    logic [7:0] echo_data;
    logic [2:0] magic_index;

    // ------------------------------------------------------------------
    // Command decode.
    //
    // The command-classification functions are evaluated ONCE here, in
    // continuous assignments, and the FSM below consumes the resulting nets.
    //
    // Calling them directly inside the clocked always block instead leaves
    // Yosys with orphaned per-call-site temporaries (\<fn>$func$<file>:<line>$N.c
    // and .$result), which the pre-synthesis `check` pass reports as
    // "used but has no driver".  Those warnings are harmless - the logic is
    // correctly inlined into the DFF input cone and opt_clean deletes the
    // dangling names - but hoisting the calls removes the noise entirely and
    // makes the decode explicit in schematics and area reports rather than
    // relying on common-subexpression elimination to merge four copies of
    // the same comparator chain.
    // ------------------------------------------------------------------
    logic       din_is_standalone;
    logic       din_is_ofdm;
    logic       din_is_accepted;
    logic [8:0] din_input_bytes;
    logic [8:0] din_output_bytes;
    logic       active_is_ofdm;
    logic       active_is_rx;

    assign din_is_standalone = is_standalone(din);
    assign din_is_ofdm       = is_ofdm(din);
    assign din_is_accepted   = din_is_standalone || din_is_ofdm;
    assign din_input_bytes   = transform_input_bytes(din);
    assign din_output_bytes  = ofdm_output_bytes(din);
    assign active_is_ofdm    = is_ofdm(active_command);
    assign active_is_rx      = is_rx(active_command);

    assign external_fire = din_valid_i && din_ready_o;
    assign feeder_start = external_fire && (top_state == TOP_IDLE) && din_is_ofdm;
    assign job_head_command = active_command;
    assign core_ofdm_active = ofdm_active;
    assign drain_active = ofdm_active && (top_state == TOP_TRANSFORM_WAIT);
    assign ext_state = (top_state == TOP_IDLE) ? 3'd0 :
                       ((top_state == TOP_TRANSFORM_INPUT) ? 3'd1 : 3'd3);

    always @* begin
        din_ready_o = 1'b0;
        case (top_state)
          TOP_IDLE:            din_ready_o = core_din_ready_i;
          TOP_TRANSFORM_INPUT: din_ready_o = core_din_ready_i;
          TOP_ECHO_INPUT,
          TOP_SRAM_READ_ADDR,
          TOP_SRAM_WRITE_ADDR,
          TOP_SRAM_WRITE_HI,
          TOP_SRAM_WRITE_LO:   din_ready_o = 1'b1;
          default:             din_ready_o = 1'b0;
        endcase
    end

    // Valid is independent of ready. The core performs the actual valid/ready
    // acceptance, so feeding ready back into valid only creates a long
    // combinational control cone without changing protocol behavior.
    assign core_din_valid_o = din_valid_i &&
        (((top_state == TOP_IDLE) && din_is_accepted) ||
         (top_state == TOP_TRANSFORM_INPUT));

    assign debug_mode_o = (top_state == TOP_SRAM_READ_REQ) ||
                          (top_state == TOP_SRAM_READ_WAIT) ||
                          (top_state == TOP_SRAM_WRITE_REQ);
    assign debug_req_o = (top_state == TOP_SRAM_READ_REQ) ||
                         (top_state == TOP_SRAM_WRITE_REQ);
    assign debug_write_o = (top_state == TOP_SRAM_WRITE_REQ);

    assign core_result_ready_o =
        standalone_active_o ? serializer_ready_i : 1'b1;

    always @* begin
        dout = 8'h00;
        dout_valid_o = 1'b0;
        if (serializer_valid_i) begin
            dout = serializer_dout_i;
            dout_valid_o = 1'b1;
        end else if (core_dout_valid_i) begin
            dout = core_dout_i;
            dout_valid_o = 1'b1;
        end else case (top_state)
          TOP_ECHO_OUTPUT: begin
            dout = echo_data;
            dout_valid_o = 1'b1;
          end
          TOP_MAGIC_OUTPUT: begin
            case (magic_index)
              3'd0: dout = 8'h42; // B
              3'd1: dout = 8'h46; // F
              3'd2: dout = 8'h4c; // L
              default: dout = 8'h44; // D
            endcase
            dout_valid_o = 1'b1;
          end
          TOP_SRAM_READ_HI: begin
            dout = debug_read_latch[15:8];
            dout_valid_o = 1'b1;
          end
          TOP_SRAM_READ_LO: begin
            dout = debug_read_latch[7:0];
            dout_valid_o = 1'b1;
          end
          TOP_SRAM_WRITE_ACK: begin
            dout = SRAM_WRITE_ACK;
            dout_valid_o = 1'b1;
          end
          default: begin end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_state <= TOP_IDLE;
            standalone_active_o <= 1'b0;
            ofdm_active <= 1'b0;
            active_command <= 8'd0;
            input_left <= 9'd0;
            output_left <= 9'd0;
            debug_addr_o <= 8'd0;
            debug_wdata_o <= 16'd0;
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
                  if (din_is_accepted) begin
                      standalone_active_o <= din_is_standalone;
                      ofdm_active <= din_is_ofdm;
                      input_left <= din_input_bytes;
                      output_left <= din_output_bytes;
                      top_state <= TOP_TRANSFORM_INPUT;
                  end else case (din)
                    CMD_ECHO:       top_state <= TOP_ECHO_INPUT;
                    CMD_MAGIC: begin
                        magic_index <= 3'd0;
                        top_state <= TOP_MAGIC_OUTPUT;
                    end
                    CMD_SRAM_READ:  top_state <= TOP_SRAM_READ_ADDR;
                    CMD_SRAM_WRITE: top_state <= TOP_SRAM_WRITE_ADDR;
                    default:        top_state <= TOP_IDLE;
                  endcase
              end

              TOP_TRANSFORM_INPUT: if (external_fire) begin
                  input_left <= input_left - 1'b1;
                  if (input_left == 9'd1) begin
                      job_push <= active_is_ofdm;
                      top_state <= TOP_TRANSFORM_WAIT;
                  end
              end

              TOP_TRANSFORM_WAIT: begin
                  if (standalone_active_o && serializer_job_done_i) begin
                      standalone_active_o <= 1'b0;
                      top_state <= TOP_IDLE;
                  end
                  if (ofdm_active && core_dout_valid_i) begin
                      output_left <= output_left - 1'b1;
                      if (output_left == 9'd1) begin
                          ofdm_active <= 1'b0;
                          top_state <= TOP_IDLE;
                          if (active_is_rx) begin
                              core_rx_selected_complete <= 1'b1;
                              core_rx_complete <= 1'b1;
                          end else begin
                              core_tx_complete <= 1'b1;
                          end
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
                  debug_addr_o <= din;
                  top_state <= TOP_SRAM_READ_REQ;
              end

              TOP_SRAM_READ_REQ: if (debug_ready_i) top_state <= TOP_SRAM_READ_WAIT;

              TOP_SRAM_READ_WAIT: if (debug_rvalid_i) begin
                  debug_read_latch <= debug_rdata_i;
                  top_state <= TOP_SRAM_READ_HI;
              end

              TOP_SRAM_READ_HI: top_state <= TOP_SRAM_READ_LO;
              TOP_SRAM_READ_LO: top_state <= TOP_IDLE;

              TOP_SRAM_WRITE_ADDR: if (external_fire) begin
                  debug_addr_o <= din;
                  top_state <= TOP_SRAM_WRITE_HI;
              end

              TOP_SRAM_WRITE_HI: if (external_fire) begin
                  debug_data_hi <= din;
                  top_state <= TOP_SRAM_WRITE_LO;
              end

              TOP_SRAM_WRITE_LO: if (external_fire) begin
                  debug_wdata_o <= {debug_data_hi, din};
                  top_state <= TOP_SRAM_WRITE_REQ;
              end

              TOP_SRAM_WRITE_REQ: if (debug_ready_i) top_state <= TOP_SRAM_WRITE_ACK;
              TOP_SRAM_WRITE_ACK: top_state <= TOP_IDLE;
              default: top_state <= TOP_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire