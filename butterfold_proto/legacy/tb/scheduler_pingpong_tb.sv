`timescale 1ns/1ps
`default_nettype none

module scheduler_pingpong_tb;
    localparam integer CLK_PERIOD_NS = 10;
    localparam integer MAX_WAIT = 200000;
    localparam integer TX_INTERVAL = 16;

    localparam logic [7:0] CMD_OFDM_RX_SHORT_NORMAL_CP = 8'h46;
    localparam logic [7:0] CMD_OFDM_RX_LONG_NORMAL_CP  = 8'h47;
    localparam logic [7:0] CMD_OFDM_TX_SHORT_NORMAL_CP = 8'h48;
    localparam logic [7:0] CMD_OFDM_TX_LONG_NORMAL_CP  = 8'h49;

    logic clk;
    logic rst_n;
    logic [7:0] din;
    logic din_valid_i;
    logic din_ready_o;
    logic signed [15:0] X0_i_o, X0_q_o, X1_i_o, X1_q_o, X2_i_o, X2_q_o;
    logic [6:0] result_addr0_o, result_addr1_o, result_addr2_o;
    logic [1:0] result_radix_o;
    logic result_last_o, result_valid_o, result_ready_i;
    logic [7:0] dout;
    logic dout_valid_o;

    integer cycle_count;
    integer errors;

    logic [15:0] rx_short_inputs [0:4*(9+128)-1];
    logic [15:0] rx_long_inputs  [0:4*(10+128)-1];
    logic [15:0] rx_short_expected [0:4*12-1];
    logic [15:0] rx_long_expected  [0:4*12-1];
    logic [15:0] tx_short_inputs [0:5*12-1];
    logic [15:0] tx_long_inputs  [0:5*12-1];
    logic [15:0] tx_short_expected [0:5*(9+128)-1];
    logic [15:0] tx_long_expected  [0:5*(10+128)-1];

    scheduler #(
        .TX_BYTE_INTERVAL(TX_INTERVAL)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .din(din), .din_valid_i(din_valid_i), .din_ready_o(din_ready_o),
        .X0_i_o(X0_i_o), .X0_q_o(X0_q_o),
        .X1_i_o(X1_i_o), .X1_q_o(X1_q_o),
        .X2_i_o(X2_i_o), .X2_q_o(X2_q_o),
        .result_addr0_o(result_addr0_o),
        .result_addr1_o(result_addr1_o),
        .result_addr2_o(result_addr2_o),
        .result_radix_o(result_radix_o),
        .result_last_o(result_last_o),
        .result_valid_o(result_valid_o),
        .result_ready_i(result_ready_i),
        .dout(dout), .dout_valid_o(dout_valid_o)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            din = 8'd0;
            din_valid_i = 1'b0;
            result_ready_i = 1'b1;
            repeat (5) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            repeat (3) @(posedge clk);
        end
    endtask

    task automatic send_byte(input logic [7:0] value, output integer accepted_cycle);
        integer waited;
        logic accepted;
        begin
            waited = 0;
            accepted = 1'b0;
            @(negedge clk);
            din = value;
            din_valid_i = 1'b1;
            while (!accepted) begin
                @(posedge clk);
                if (din_ready_o) begin
                    accepted_cycle = cycle_count;
                    accepted = 1'b1;
                end else begin
                    waited = waited + 1;
                    if (waited > MAX_WAIT) $fatal(1, "input timeout");
                end
            end
            @(negedge clk);
            din_valid_i = 1'b0;
            din = 8'd0;
        end
    endtask

    task automatic send_rx_frame(
        input logic long_cp,
        input integer test_index,
        output integer command_cycle,
        output integer final_cycle
    );
        integer i, base, tmp;
        logic [15:0] w;
        begin
            send_byte(long_cp ? CMD_OFDM_RX_LONG_NORMAL_CP : CMD_OFDM_RX_SHORT_NORMAL_CP,
                      command_cycle);
            if (long_cp) begin
                base = test_index * (10+128);
                for (i=0; i<(10+128); i=i+1) begin
                    w = rx_long_inputs[base+i];
                    send_byte(w[15:8], tmp);
                    send_byte(w[7:0], final_cycle);
                end
            end else begin
                base = test_index * (9+128);
                for (i=0; i<(9+128); i=i+1) begin
                    w = rx_short_inputs[base+i];
                    send_byte(w[15:8], tmp);
                    send_byte(w[7:0], final_cycle);
                end
            end
        end
    endtask

    task automatic send_tx_frame(
        input logic long_cp,
        input integer test_index,
        output integer command_cycle,
        output integer final_cycle
    );
        integer i, base, tmp;
        logic [15:0] w;
        begin
            send_byte(long_cp ? CMD_OFDM_TX_LONG_NORMAL_CP : CMD_OFDM_TX_SHORT_NORMAL_CP,
                      command_cycle);
            base = test_index * 12;
            for (i=0; i<12; i=i+1) begin
                w = long_cp ? tx_long_inputs[base+i] : tx_short_inputs[base+i];
                send_byte(w[15:8], tmp);
                send_byte(w[7:0], final_cycle);
            end
        end
    endtask

    task automatic check_rx_pair(output integer first_output_cycle);
        integer byte_count, expected_index, waited;
        logic [15:0] word;
        logic [7:0] exp;
        begin
            byte_count = 0;
            waited = 0;
            first_output_cycle = -1;
            while (byte_count < 48) begin
                @(posedge clk);
                if (dout_valid_o) begin
                    if (first_output_cycle < 0) first_output_cycle = cycle_count;
                    if (byte_count < 24) begin
                        expected_index = byte_count >> 1;
                        word = rx_short_expected[expected_index]; // test 0
                    end else begin
                        expected_index = (byte_count-24) >> 1;
                        word = rx_long_expected[12 + expected_index]; // test 1
                    end
                    exp = byte_count[0] ? word[7:0] : word[15:8];
                    if (dout !== exp) begin
                        $display("RX pair mismatch byte=%0d expected=%02h actual=%02h", byte_count, exp, dout);
                        errors = errors + 1;
                    end
                    byte_count = byte_count + 1;
                    waited = 0;
                end else begin
                    waited = waited + 1;
                    if (waited > MAX_WAIT) $fatal(1, "RX output timeout");
                end
            end
        end
    endtask

    task automatic check_tx_pair(
        output integer first_output_cycle,
        output integer boundary_gap
    );
        integer byte_count, frame_byte, expected_index, waited;
        integer last_valid_cycle, current_gap;
        integer first_len, second_len;
        logic [15:0] word;
        logic [7:0] exp;
        begin
            first_len = 2*(9+128);
            second_len = 2*(10+128);
            byte_count = 0;
            waited = 0;
            last_valid_cycle = -1;
            first_output_cycle = -1;
            boundary_gap = -1;

            while (byte_count < first_len + second_len) begin
                @(posedge clk);
                if (dout_valid_o) begin
                    if (first_output_cycle < 0) first_output_cycle = cycle_count;
                    if (last_valid_cycle >= 0) begin
                        current_gap = cycle_count - last_valid_cycle;
                        if (current_gap != TX_INTERVAL) begin
                            $display("TX pacing mismatch byte=%0d gap=%0d expected=%0d", byte_count, current_gap, TX_INTERVAL);
                            errors = errors + 1;
                        end
                    end
                    if (byte_count == first_len)
                        boundary_gap = cycle_count - last_valid_cycle;
                    last_valid_cycle = cycle_count;

                    if (byte_count < first_len) begin
                        frame_byte = byte_count;
                        expected_index = frame_byte >> 1;
                        word = tx_short_expected[expected_index]; // test 0
                    end else begin
                        frame_byte = byte_count - first_len;
                        expected_index = frame_byte >> 1;
                        word = tx_long_expected[(10+128) + expected_index]; // test 1
                    end
                    exp = frame_byte[0] ? word[7:0] : word[15:8];
                    if (dout !== exp) begin
                        $display("TX pair mismatch byte=%0d expected=%02h actual=%02h", byte_count, exp, dout);
                        errors = errors + 1;
                    end
                    byte_count = byte_count + 1;
                    waited = 0;
                end else begin
                    waited = waited + 1;
                    if (waited > MAX_WAIT) $fatal(1, "TX output timeout");
                end
            end
        end
    endtask

    integer rx_cmd0, rx_end0, rx_cmd1, rx_end1, rx_first;
    integer tx_cmd0, tx_end0, tx_cmd1, tx_end1, tx_first, tx_boundary_gap;

    initial begin
        cycle_count = 0;
        errors = 0;

        $readmemh("vectors/ofdm_rx_short_normal_cp_inputs.hex", rx_short_inputs);
        $readmemh("vectors/ofdm_rx_long_normal_cp_inputs.hex", rx_long_inputs);
        $readmemh("vectors/ofdm_rx_short_normal_cp_expected_rb.hex", rx_short_expected);
        $readmemh("vectors/ofdm_rx_long_normal_cp_expected_rb.hex", rx_long_expected);
        $readmemh("vectors/ofdm_tx_short_normal_cp_inputs.hex", tx_short_inputs);
        $readmemh("vectors/ofdm_tx_long_normal_cp_inputs.hex", tx_long_inputs);
        $readmemh("vectors/ofdm_tx_short_normal_cp_expected.hex", tx_short_expected);
        $readmemh("vectors/ofdm_tx_long_normal_cp_expected.hex", tx_long_expected);

        reset_dut();

        $display("=== RX ping-pong: capture second symbol before first result ===");
        fork
            begin
                send_rx_frame(1'b0, 0, rx_cmd0, rx_end0);
                send_rx_frame(1'b1, 1, rx_cmd1, rx_end1);
            end
            check_rx_pair(rx_first);
        join

        if (rx_end1 >= rx_first) begin
            $display("RX overlap FAIL: second frame capture ended at %0d, first output began at %0d", rx_end1, rx_first);
            errors = errors + 1;
        end else begin
            $display("RX overlap PASS: second frame fully buffered %0d cycles before first output", rx_first-rx_end1);
        end

        repeat (20) @(posedge clk);

        $display("=== TX ping-pong: generate next symbol while previous waveform drains ===");
        fork
            begin
                send_tx_frame(1'b0, 0, tx_cmd0, tx_end0);
                send_tx_frame(1'b1, 1, tx_cmd1, tx_end1);
            end
            check_tx_pair(tx_first, tx_boundary_gap);
        join

        if (tx_end1 >= tx_first) begin
            $display("TX input overlap FAIL: second TX payload ended at %0d, first waveform began at %0d", tx_end1, tx_first);
            errors = errors + 1;
        end else begin
            $display("TX input overlap PASS: both TX requests buffered before first waveform output");
        end

        if (tx_boundary_gap != TX_INTERVAL) begin
            $display("TX frame-boundary continuity FAIL: gap=%0d expected=%0d", tx_boundary_gap, TX_INTERVAL);
            errors = errors + 1;
        end else begin
            $display("TX frame-boundary continuity PASS: byte cadence=%0d clocks", TX_INTERVAL);
        end

        if (errors == 0)
            $display("PING-PONG OVERALL RESULT: PASS");
        else
            $display("PING-PONG OVERALL RESULT: FAIL (%0d errors)", errors);

        $finish;
    end

endmodule

`default_nettype wire
