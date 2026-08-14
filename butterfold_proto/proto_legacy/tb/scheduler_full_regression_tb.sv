`timescale 1ns/1ps
`default_nettype none

module scheduler_full_regression_tb;

    parameter integer N                     = 128;
    parameter integer NUM_TWO_POINT_TESTS   = 8;
    parameter integer NUM_FFT3_TESTS        = 8;
    parameter integer DFT12_N                = 12;
    parameter integer NUM_DFT12_TESTS        = 8;
    parameter integer NUM_FFT128_TESTS      = 5;
    parameter integer NUM_IFFT128_TESTS     = 5;
    parameter integer NUM_OFDM_RX_TESTS      = 4;
    parameter integer NUM_OFDM_TX_TESTS      = 5;
    parameter integer CLK_PERIOD_NS         = 10;
    parameter integer MAX_WAIT_CYCLES       = 300000;

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT128  = 8'h41;
    localparam logic [7:0] CMD_IFFT128 = 8'h42;
    localparam logic [7:0] CMD_IFFT2   = 8'h43;
    localparam logic [7:0] CMD_FFT3    = 8'h44;
    localparam logic [7:0] CMD_DFT12                = 8'h45;
    localparam logic [7:0] CMD_OFDM_RX_NORMAL_CP     = 8'h46;
    localparam logic [7:0] CMD_OFDM_RX_EXTENDED_CP   = 8'h47;
    localparam logic [7:0] CMD_OFDM_TX_NORMAL_CP     = 8'h48;
    localparam logic [7:0] CMD_OFDM_TX_EXTENDED_CP   = 8'h49;

    localparam integer NORMAL_CP   = 9;
    localparam integer EXTENDED_CP = 10;
    localparam integer RX_NORMAL_SAMPLES_PER_TEST   = NORMAL_CP + 128;
    localparam integer RX_EXTENDED_SAMPLES_PER_TEST = EXTENDED_CP + 128;
    localparam integer TX_NORMAL_OUTPUT_SAMPLES     = NORMAL_CP + 128;
    localparam integer TX_EXTENDED_OUTPUT_SAMPLES   = EXTENDED_CP + 128;

    localparam integer TOTAL_DFT12_SAMPLES   = NUM_DFT12_TESTS * DFT12_N;
    localparam integer TOTAL_FFT128_SAMPLES  = NUM_FFT128_TESTS * N;
    localparam integer TOTAL_IFFT128_SAMPLES = NUM_IFFT128_TESTS * N;

    //=========================================================================
    // DUT interface
    //=========================================================================

    logic clk;
    logic rst_n;

    logic [7:0] din;
    logic       din_valid_i;
    logic       din_ready_o;

    logic signed [15:0] X0_i_o;
    logic signed [15:0] X0_q_o;
    logic signed [15:0] X1_i_o;
    logic signed [15:0] X1_q_o;
    logic signed [15:0] X2_i_o;
    logic signed [15:0] X2_q_o;

    logic [6:0] result_addr0_o;
    logic [6:0] result_addr1_o;
    logic [6:0] result_addr2_o;
    logic [1:0] result_radix_o;
    logic       result_last_o;
    logic       result_valid_o;
    logic       result_ready_i;

    logic [7:0] dout;
    logic       dout_valid_o;

    //=========================================================================
    // Golden vectors
    //=========================================================================

    logic [7:0]  two_point_commands [0:NUM_TWO_POINT_TESTS-1];
    logic [31:0] two_point_inputs   [0:NUM_TWO_POINT_TESTS-1];
    logic [63:0] two_point_expected [0:NUM_TWO_POINT_TESTS-1];

    logic [47:0] fft3_inputs   [0:NUM_FFT3_TESTS-1];
    logic [95:0] fft3_expected [0:NUM_FFT3_TESTS-1];

    logic [15:0] dft12_inputs   [0:TOTAL_DFT12_SAMPLES-1];
    logic [31:0] dft12_expected [0:TOTAL_DFT12_SAMPLES-1];

    logic [15:0] fft128_inputs    [0:TOTAL_FFT128_SAMPLES-1];
    logic [31:0] fft128_expected  [0:TOTAL_FFT128_SAMPLES-1];
    logic [15:0] ifft128_inputs   [0:TOTAL_IFFT128_SAMPLES-1];
    logic [31:0] ifft128_expected [0:TOTAL_IFFT128_SAMPLES-1];

    logic signed [15:0] actual_i [0:N-1];
    logic signed [15:0] actual_q [0:N-1];
    logic               bin_seen [0:N-1];

    integer two_point_command_cycle [0:NUM_TWO_POINT_TESTS-1];
    integer two_point_input_cycle   [0:NUM_TWO_POINT_TESTS-1];
    integer two_point_result_cycle  [0:NUM_TWO_POINT_TESTS-1];

    //=========================================================================
    // Statistics
    //=========================================================================

    integer cycle_count;

    integer two_point_passed;
    integer two_point_failed;
    integer two_point_exact_components;
    integer two_point_absolute_error_sum;
    integer two_point_maximum_error;
    integer two_point_command_latency_sum;
    integer two_point_input_latency_sum;

    integer fft3_passed;
    integer fft3_failed;
    integer fft3_exact_components;
    integer fft3_absolute_error_sum;
    integer fft3_maximum_error;
    integer fft3_command_latency_sum;
    integer fft3_input_latency_sum;

    integer dft12_passed;
    integer dft12_failed;
    integer dft12_exact_components;
    integer dft12_absolute_error_sum;
    integer dft12_maximum_error;
    integer dft12_command_to_last_sum;
    integer dft12_input_to_last_sum;

    integer fft128_passed;
    integer fft128_failed;
    integer fft128_exact_components;
    integer fft128_absolute_error_sum;
    integer fft128_maximum_error;
    integer fft128_command_to_last_sum;
    integer fft128_input_to_last_sum;

    integer ifft128_passed;
    integer ifft128_failed;
    integer ifft128_exact_components;
    integer ifft128_absolute_error_sum;
    integer ifft128_maximum_error;
    integer ifft128_command_to_last_sum;
    integer ifft128_input_to_last_sum;


    //=========================================================================
    // OFDM_RX / DFT-s-OFDM TX vectors and statistics
    //=========================================================================

    logic [15:0] rx_normal_inputs
        [0:NUM_OFDM_RX_TESTS*RX_NORMAL_SAMPLES_PER_TEST-1];
    logic [15:0] rx_extended_inputs
        [0:NUM_OFDM_RX_TESTS*RX_EXTENDED_SAMPLES_PER_TEST-1];
    logic [15:0] rx_normal_expected [0:NUM_OFDM_RX_TESTS*128-1];
    logic [15:0] rx_extended_expected [0:NUM_OFDM_RX_TESTS*128-1];

    logic [15:0] tx_normal_inputs [0:NUM_OFDM_TX_TESTS*12-1];
    logic [15:0] tx_extended_inputs [0:NUM_OFDM_TX_TESTS*12-1];
    logic [15:0] tx_normal_expected
        [0:NUM_OFDM_TX_TESTS*TX_NORMAL_OUTPUT_SAMPLES-1];
    logic [15:0] tx_extended_expected
        [0:NUM_OFDM_TX_TESTS*TX_EXTENDED_OUTPUT_SAMPLES-1];
    logic [7:0] tx_received_bytes [0:2*TX_EXTENDED_OUTPUT_SAMPLES-1];

    integer rx_passed_frames;
    integer rx_failed_frames;
    integer rx_matched_bytes;
    integer rx_total_bytes;
    integer rx_abs_error_sum;
    integer rx_max_abs_error;
    integer rx_command_to_first_sum;
    integer rx_command_to_last_sum;
    integer rx_input_to_first_sum;
    integer rx_input_to_last_sum;
    integer rx_min_command_to_first;
    integer rx_max_command_to_first;
    integer rx_min_command_to_last;
    integer rx_max_command_to_last;

    integer tx_passed_frames;
    integer tx_failed_frames;
    integer tx_matched_bytes;
    integer tx_total_bytes;
    integer tx_abs_error_sum;
    integer tx_max_abs_error;
    integer tx_command_to_first_sum;
    integer tx_command_to_last_sum;
    integer tx_input_to_first_sum;
    integer tx_input_to_last_sum;

    logic standalone_test_active;
    logic rx_test_active;
    logic tx_test_active;

    //=========================================================================
    // Clock and DUT
    //=========================================================================

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end


    // Standalone transforms use the parallel result channel only. OFDM block
    // modes use the byte output only and must consume intermediate transforms
    // internally.
    always @(posedge clk) begin
        if (rst_n && standalone_test_active && dout_valid_o)
            $fatal(1, "dout_valid_o asserted during standalone transform test");
        if (rst_n && (rx_test_active || tx_test_active) && result_valid_o)
            $fatal(1, "parallel result_valid_o escaped during OFDM block mode");
    end

    scheduler dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .din            (din),
        .din_valid_i    (din_valid_i),
        .din_ready_o    (din_ready_o),

        .X0_i_o         (X0_i_o),
        .X0_q_o         (X0_q_o),
        .X1_i_o         (X1_i_o),
        .X1_q_o         (X1_q_o),
        .X2_i_o         (X2_i_o),
        .X2_q_o         (X2_q_o),

        .result_addr0_o (result_addr0_o),
        .result_addr1_o (result_addr1_o),
        .result_addr2_o (result_addr2_o),
        .result_radix_o (result_radix_o),
        .result_last_o  (result_last_o),
        .result_valid_o (result_valid_o),
        .result_ready_i (result_ready_i),

        .dout           (dout),
        .dout_valid_o   (dout_valid_o)
    );

    //=========================================================================
    // Utilities
    //=========================================================================

    function automatic integer absolute_difference (
        input logic signed [15:0] actual_value,
        input logic signed [15:0] expected_value
    );
        integer signed difference;
        begin
            difference = $signed(actual_value) - $signed(expected_value);
            if (difference < 0)
                absolute_difference = -difference;
            else
                absolute_difference = difference;
        end
    endfunction

    function automatic integer absolute_byte_error (
        input logic [7:0] actual_value,
        input logic [7:0] expected_value
    );
        integer signed actual_signed;
        integer signed expected_signed;
        integer signed difference;
        begin
            actual_signed   = $signed(actual_value);
            expected_signed = $signed(expected_value);
            difference = actual_signed - expected_signed;
            absolute_byte_error = (difference < 0) ? -difference : difference;
        end
    endfunction
    task automatic reset_dut;
        begin
            rst_n                  = 1'b0;
            din                    = 8'h00;
            din_valid_i            = 1'b0;
            result_ready_i         = 1'b0;
            standalone_test_active = 1'b0;
            rx_test_active         = 1'b0;
            tx_test_active         = 1'b0;

            repeat (5) @(posedge clk);
            @(negedge clk);

            rst_n          = 1'b1;
            result_ready_i = 1'b1;
        end
    endtask
    //=========================================================================
    // Mixed FFT2/IFFT2 pipelined regression
    //=========================================================================

    task automatic send_two_point_request (
        input integer test_number
    );
        logic [7:0] request_byte [0:4];
        integer byte_index;
        integer wait_cycles;
        logic accepted;
        begin
            request_byte[0] = two_point_commands[test_number];
            request_byte[1] = two_point_inputs[test_number][31:24];
            request_byte[2] = two_point_inputs[test_number][23:16];
            request_byte[3] = two_point_inputs[test_number][15:8];
            request_byte[4] = two_point_inputs[test_number][7:0];

            @(negedge clk);
            din_valid_i = 1'b1;
            din         = request_byte[0];

            for (byte_index = 0; byte_index < 5; byte_index = byte_index + 1) begin
                accepted    = 1'b0;
                wait_cycles = 0;

                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted = 1'b1;
                        if (byte_index == 0)
                            two_point_command_cycle[test_number] = cycle_count;
                        if (byte_index == 4)
                            two_point_input_cycle[test_number] = cycle_count;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending two-point test %0d byte %0d",
                                   test_number, byte_index);
                    end
                end

                if (byte_index < 4) begin
                    @(negedge clk);
                    din = request_byte[byte_index + 1];
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din         = 8'h00;
        end
    endtask

    task automatic drive_two_point_tests;
        integer test_number;
        begin
            for (test_number = 0;
                 test_number < NUM_TWO_POINT_TESTS;
                 test_number = test_number + 1) begin
                send_two_point_request(test_number);
            end
        end
    endtask

    task automatic monitor_two_point_tests;
        integer result_number;
        integer wait_cycles;
        integer error_X0_i;
        integer error_X0_q;
        integer error_X1_i;
        integer error_X1_q;
        logic signed [15:0] expected_X0_i;
        logic signed [15:0] expected_X0_q;
        logic signed [15:0] expected_X1_i;
        logic signed [15:0] expected_X1_q;
        logic test_passed;
        logic accepted;
        begin
            for (result_number = 0;
                 result_number < NUM_TWO_POINT_TESTS;
                 result_number = result_number + 1) begin
                wait_cycles = 0;
                accepted    = 1'b0;

                while (!accepted) begin
                    @(posedge clk);

                    if (result_valid_o && result_ready_i) begin
                        accepted = 1'b1;
                        two_point_result_cycle[result_number] = cycle_count;

                        expected_X0_i = $signed(two_point_expected[result_number][63:48]);
                        expected_X0_q = $signed(two_point_expected[result_number][47:32]);
                        expected_X1_i = $signed(two_point_expected[result_number][31:16]);
                        expected_X1_q = $signed(two_point_expected[result_number][15:0]);

                        error_X0_i = absolute_difference(X0_i_o, expected_X0_i);
                        error_X0_q = absolute_difference(X0_q_o, expected_X0_q);
                        error_X1_i = absolute_difference(X1_i_o, expected_X1_i);
                        error_X1_q = absolute_difference(X1_q_o, expected_X1_q);

                        if (error_X0_i == 0)
                            two_point_exact_components = two_point_exact_components + 1;
                        if (error_X0_q == 0)
                            two_point_exact_components = two_point_exact_components + 1;
                        if (error_X1_i == 0)
                            two_point_exact_components = two_point_exact_components + 1;
                        if (error_X1_q == 0)
                            two_point_exact_components = two_point_exact_components + 1;

                        two_point_absolute_error_sum =
                            two_point_absolute_error_sum +
                            error_X0_i + error_X0_q + error_X1_i + error_X1_q;

                        if (error_X0_i > two_point_maximum_error)
                            two_point_maximum_error = error_X0_i;
                        if (error_X0_q > two_point_maximum_error)
                            two_point_maximum_error = error_X0_q;
                        if (error_X1_i > two_point_maximum_error)
                            two_point_maximum_error = error_X1_i;
                        if (error_X1_q > two_point_maximum_error)
                            two_point_maximum_error = error_X1_q;

                        test_passed =
                            (error_X0_i == 0) &&
                            (error_X0_q == 0) &&
                            (error_X1_i == 0) &&
                            (error_X1_q == 0) &&
                            (result_addr0_o == 7'd0) &&
                            (result_addr1_o == 7'd1) &&
                            (result_radix_o == 2'd2) &&
                            result_last_o;

                        if (test_passed)
                            two_point_passed = two_point_passed + 1;
                        else
                            two_point_failed = two_point_failed + 1;

                        two_point_command_latency_sum =
                            two_point_command_latency_sum +
                            (two_point_result_cycle[result_number] -
                             two_point_command_cycle[result_number]);

                        two_point_input_latency_sum =
                            two_point_input_latency_sum +
                            (two_point_result_cycle[result_number] -
                             two_point_input_cycle[result_number]);

                        $display(
                            "2PT test %0d cmd=0x%02h %s latency(command/result)=%0d cycles",
                            result_number,
                            two_point_commands[result_number],
                            test_passed ? "PASS" : "FAIL",
                            two_point_result_cycle[result_number] -
                            two_point_command_cycle[result_number]
                        );
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout waiting for two-point result %0d",
                                   result_number);
                    end
                end
            end
        end
    endtask

    //=========================================================================
    // FFT3 regression
    //=========================================================================

    task automatic run_fft3_test (
        input integer test_number
    );
        logic [7:0] request_byte [0:6];
        integer byte_index;
        integer wait_cycles;
        integer command_cycle;
        integer input_cycle;
        integer result_cycle;
        integer error_X0_i;
        integer error_X0_q;
        integer error_X1_i;
        integer error_X1_q;
        integer error_X2_i;
        integer error_X2_q;
        logic accepted;
        logic test_passed;
        logic signed [15:0] expected_X0_i;
        logic signed [15:0] expected_X0_q;
        logic signed [15:0] expected_X1_i;
        logic signed [15:0] expected_X1_q;
        logic signed [15:0] expected_X2_i;
        logic signed [15:0] expected_X2_q;
        begin
            request_byte[0] = CMD_FFT3;
            request_byte[1] = fft3_inputs[test_number][47:40];
            request_byte[2] = fft3_inputs[test_number][39:32];
            request_byte[3] = fft3_inputs[test_number][31:24];
            request_byte[4] = fft3_inputs[test_number][23:16];
            request_byte[5] = fft3_inputs[test_number][15:8];
            request_byte[6] = fft3_inputs[test_number][7:0];

            @(negedge clk);
            din_valid_i = 1'b1;
            din = request_byte[0];

            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1) begin
                accepted = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted = 1'b1;
                        if (byte_index == 0) command_cycle = cycle_count;
                        if (byte_index == 6) input_cycle = cycle_count;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending FFT3 test %0d byte %0d",
                                   test_number, byte_index);
                    end
                end
                if (byte_index < 6) begin
                    @(negedge clk);
                    din = request_byte[byte_index + 1];
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din = 8'h00;

            accepted = 1'b0;
            wait_cycles = 0;
            while (!accepted) begin
                @(posedge clk);
                if (result_valid_o && result_ready_i) begin
                    accepted = 1'b1;
                    result_cycle = cycle_count;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for FFT3 test %0d", test_number);
                end
            end

            expected_X0_i = $signed(fft3_expected[test_number][95:80]);
            expected_X0_q = $signed(fft3_expected[test_number][79:64]);
            expected_X1_i = $signed(fft3_expected[test_number][63:48]);
            expected_X1_q = $signed(fft3_expected[test_number][47:32]);
            expected_X2_i = $signed(fft3_expected[test_number][31:16]);
            expected_X2_q = $signed(fft3_expected[test_number][15:0]);

            error_X0_i = absolute_difference(X0_i_o, expected_X0_i);
            error_X0_q = absolute_difference(X0_q_o, expected_X0_q);
            error_X1_i = absolute_difference(X1_i_o, expected_X1_i);
            error_X1_q = absolute_difference(X1_q_o, expected_X1_q);
            error_X2_i = absolute_difference(X2_i_o, expected_X2_i);
            error_X2_q = absolute_difference(X2_q_o, expected_X2_q);

            if (error_X0_i == 0) fft3_exact_components = fft3_exact_components + 1;
            if (error_X0_q == 0) fft3_exact_components = fft3_exact_components + 1;
            if (error_X1_i == 0) fft3_exact_components = fft3_exact_components + 1;
            if (error_X1_q == 0) fft3_exact_components = fft3_exact_components + 1;
            if (error_X2_i == 0) fft3_exact_components = fft3_exact_components + 1;
            if (error_X2_q == 0) fft3_exact_components = fft3_exact_components + 1;

            fft3_absolute_error_sum = fft3_absolute_error_sum +
                error_X0_i + error_X0_q + error_X1_i +
                error_X1_q + error_X2_i + error_X2_q;

            if (error_X0_i > fft3_maximum_error) fft3_maximum_error = error_X0_i;
            if (error_X0_q > fft3_maximum_error) fft3_maximum_error = error_X0_q;
            if (error_X1_i > fft3_maximum_error) fft3_maximum_error = error_X1_i;
            if (error_X1_q > fft3_maximum_error) fft3_maximum_error = error_X1_q;
            if (error_X2_i > fft3_maximum_error) fft3_maximum_error = error_X2_i;
            if (error_X2_q > fft3_maximum_error) fft3_maximum_error = error_X2_q;

            test_passed =
                (error_X0_i == 0) && (error_X0_q == 0) &&
                (error_X1_i == 0) && (error_X1_q == 0) &&
                (error_X2_i == 0) && (error_X2_q == 0) &&
                (result_addr0_o == 7'd0) &&
                (result_addr1_o == 7'd1) &&
                (result_addr2_o == 7'd2) &&
                (result_radix_o == 2'd3) &&
                result_last_o;

            if (test_passed) fft3_passed = fft3_passed + 1;
            else fft3_failed = fft3_failed + 1;

            fft3_command_latency_sum = fft3_command_latency_sum +
                (result_cycle - command_cycle);
            fft3_input_latency_sum = fft3_input_latency_sum +
                (result_cycle - input_cycle);

            $display(
                "FFT3 test %0d %s command->result=%0d cycles input->result=%0d cycles",
                test_number, test_passed ? "PASS" : "FAIL",
                result_cycle - command_cycle, result_cycle - input_cycle
            );
        end
    endtask

    //=========================================================================
    // DFT12 Good-Thomas regression
    //=========================================================================

    task automatic send_dft12_request (
        input integer test_number,
        output integer command_accept_cycle,
        output integer final_input_accept_cycle
    );
        integer sample_index;
        integer vector_index;
        integer wait_cycles;
        logic accepted;
        logic [15:0] sample_word;
        begin
            @(negedge clk);
            din_valid_i = 1'b1;
            din = CMD_DFT12;

            accepted = 1'b0;
            wait_cycles = 0;
            while (!accepted) begin
                @(posedge clk);
                if (din_valid_i && din_ready_o) begin
                    command_accept_cycle = cycle_count;
                    accepted = 1'b1;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout sending DFT12 command");
                end
            end

            for (sample_index = 0;
                 sample_index < DFT12_N;
                 sample_index = sample_index + 1) begin
                vector_index = test_number * DFT12_N + sample_index;
                sample_word = dft12_inputs[vector_index];

                @(negedge clk);
                din = sample_word[15:8];
                accepted = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o)
                        accepted = 1'b1;
                    else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending DFT12 I sample %0d",
                                   sample_index);
                    end
                end

                @(negedge clk);
                din = sample_word[7:0];
                accepted = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted = 1'b1;
                        if (sample_index == DFT12_N - 1)
                            final_input_accept_cycle = cycle_count;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending DFT12 Q sample %0d",
                                   sample_index);
                    end
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din = 8'h00;
        end
    endtask

    task automatic run_dft12_test (
        input integer test_number
    );
        integer command_accept_cycle;
        integer final_input_accept_cycle;
        integer last_result_cycle;
        integer result_count;
        integer wait_cycles;
        integer bin_index;
        integer vector_index;
        integer error_i;
        integer error_q;
        logic accepted;
        logic last_seen;
        logic test_passed;
        logic signed [15:0] expected_i;
        logic signed [15:0] expected_q;
        begin
            for (bin_index = 0; bin_index < DFT12_N; bin_index = bin_index + 1) begin
                actual_i[bin_index] = '0;
                actual_q[bin_index] = '0;
                bin_seen[bin_index] = 1'b0;
            end

            send_dft12_request(
                test_number, command_accept_cycle, final_input_accept_cycle
            );

            result_count = 0;
            wait_cycles = 0;
            last_seen = 1'b0;
            test_passed = 1'b1;

            while (!last_seen) begin
                @(posedge clk);
                if (result_valid_o && result_ready_i) begin
                    wait_cycles = 0;

                    if (result_radix_o != 2'd2) begin
                        $display("DFT12 test %0d returned radix %0d",
                                 test_number, result_radix_o);
                        test_passed = 1'b0;
                    end

                    if ((result_addr0_o >= DFT12_N) ||
                        (result_addr1_o >= DFT12_N)) begin
                        $display("DFT12 test %0d returned invalid addresses %0d,%0d",
                                 test_number, result_addr0_o, result_addr1_o);
                        test_passed = 1'b0;
                    end else begin
                        if (bin_seen[result_addr0_o]) begin
                            $display("DFT12 test %0d duplicate bin %0d",
                                     test_number, result_addr0_o);
                            test_passed = 1'b0;
                        end
                        if (bin_seen[result_addr1_o]) begin
                            $display("DFT12 test %0d duplicate bin %0d",
                                     test_number, result_addr1_o);
                            test_passed = 1'b0;
                        end

                        actual_i[result_addr0_o] = X0_i_o;
                        actual_q[result_addr0_o] = X0_q_o;
                        actual_i[result_addr1_o] = X1_i_o;
                        actual_q[result_addr1_o] = X1_q_o;
                        bin_seen[result_addr0_o] = 1'b1;
                        bin_seen[result_addr1_o] = 1'b1;
                    end

                    if (result_last_o) begin
                        last_seen = 1'b1;
                        last_result_cycle = cycle_count;
                        if (result_count != 5) begin
                            $display("DFT12 test %0d result_last on transaction %0d",
                                     test_number, result_count);
                            test_passed = 1'b0;
                        end
                    end
                    result_count = result_count + 1;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for DFT12 test %0d", test_number);
                end
            end

            if (result_count != 6) begin
                $display("DFT12 test %0d received %0d transactions, expected 6",
                         test_number, result_count);
                test_passed = 1'b0;
            end

            for (bin_index = 0; bin_index < DFT12_N; bin_index = bin_index + 1) begin
                vector_index = test_number * DFT12_N + bin_index;
                expected_i = $signed(dft12_expected[vector_index][31:16]);
                expected_q = $signed(dft12_expected[vector_index][15:0]);

                if (!bin_seen[bin_index]) begin
                    $display("DFT12 test %0d missing bin %0d",
                             test_number, bin_index);
                    test_passed = 1'b0;
                end

                error_i = absolute_difference(actual_i[bin_index], expected_i);
                error_q = absolute_difference(actual_q[bin_index], expected_q);

                if (error_i == 0)
                    dft12_exact_components = dft12_exact_components + 1;
                else
                    test_passed = 1'b0;
                if (error_q == 0)
                    dft12_exact_components = dft12_exact_components + 1;
                else
                    test_passed = 1'b0;

                dft12_absolute_error_sum = dft12_absolute_error_sum +
                    error_i + error_q;
                if (error_i > dft12_maximum_error)
                    dft12_maximum_error = error_i;
                if (error_q > dft12_maximum_error)
                    dft12_maximum_error = error_q;
            end

            if (test_passed)
                dft12_passed = dft12_passed + 1;
            else
                dft12_failed = dft12_failed + 1;

            dft12_command_to_last_sum = dft12_command_to_last_sum +
                (last_result_cycle - command_accept_cycle);
            dft12_input_to_last_sum = dft12_input_to_last_sum +
                (last_result_cycle - final_input_accept_cycle);

            $display(
                "DFT12 test %0d %s command->last=%0d cycles last-input->last=%0d cycles",
                test_number, test_passed ? "PASS" : "FAIL",
                last_result_cycle - command_accept_cycle,
                last_result_cycle - final_input_accept_cycle
            );
        end
    endtask

    //=========================================================================
    // FFT128/IFFT128 block driver and receiver
    //=========================================================================

    task automatic send_block_request (
        input logic [7:0] command,
        input integer test_number,
        input logic inverse,
        output integer command_accept_cycle,
        output integer final_input_accept_cycle
    );
        integer sample_index;
        integer vector_index;
        integer wait_cycles;
        logic accepted;
        logic [15:0] sample_word;
        begin
            @(negedge clk);
            din_valid_i = 1'b1;
            din         = command;

            accepted    = 1'b0;
            wait_cycles = 0;
            while (!accepted) begin
                @(posedge clk);
                if (din_valid_i && din_ready_o) begin
                    command_accept_cycle = cycle_count;
                    accepted = 1'b1;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout sending block command 0x%02h", command);
                end
            end

            for (sample_index = 0; sample_index < N; sample_index = sample_index + 1) begin
                vector_index = test_number * N + sample_index;
                if (inverse)
                    sample_word = ifft128_inputs[vector_index];
                else
                    sample_word = fft128_inputs[vector_index];

                @(negedge clk);
                din = sample_word[15:8];

                accepted    = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o)
                        accepted = 1'b1;
                    else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending block sample %0d I", sample_index);
                    end
                end

                @(negedge clk);
                din = sample_word[7:0];

                accepted    = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted = 1'b1;
                        if (sample_index == N-1)
                            final_input_accept_cycle = cycle_count;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending block sample %0d Q", sample_index);
                    end
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din         = 8'h00;
        end
    endtask

    task automatic receive_block_results (
        output integer first_result_cycle,
        output integer last_result_cycle
    );
        integer transaction_count;
        integer wait_cycles;
        integer bin_index;
        begin
            transaction_count  = 0;
            wait_cycles        = 0;
            first_result_cycle = -1;
            last_result_cycle  = -1;

            for (bin_index = 0; bin_index < N; bin_index = bin_index + 1) begin
                actual_i[bin_index] = '0;
                actual_q[bin_index] = '0;
                bin_seen[bin_index] = 1'b0;
            end

            while (transaction_count < N/2) begin
                @(posedge clk);

                if (result_valid_o && result_ready_i) begin
                    if (result_radix_o != 2'd2)
                        $fatal(1, "Block result reported non-radix-2 transaction");
                    if (bin_seen[result_addr0_o])
                        $fatal(1, "Duplicate block output bin %0d", result_addr0_o);
                    if (bin_seen[result_addr1_o])
                        $fatal(1, "Duplicate block output bin %0d", result_addr1_o);

                    actual_i[result_addr0_o] = X0_i_o;
                    actual_q[result_addr0_o] = X0_q_o;
                    actual_i[result_addr1_o] = X1_i_o;
                    actual_q[result_addr1_o] = X1_q_o;
                    bin_seen[result_addr0_o] = 1'b1;
                    bin_seen[result_addr1_o] = 1'b1;

                    if (transaction_count == 0)
                        first_result_cycle = cycle_count;

                    if (result_last_o) begin
                        if (transaction_count != N/2 - 1)
                            $fatal(1, "result_last_o asserted early");
                        last_result_cycle = cycle_count;
                    end

                    transaction_count = transaction_count + 1;
                    wait_cycles = 0;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for block result %0d",
                               transaction_count);
                end
            end

            if (last_result_cycle < 0)
                $fatal(1, "Block completed without result_last_o");

            for (bin_index = 0; bin_index < N; bin_index = bin_index + 1) begin
                if (!bin_seen[bin_index])
                    $fatal(1, "Block output bin %0d missing", bin_index);
            end
        end
    endtask

    task automatic check_block_result (
        input integer test_number,
        input logic inverse,
        output logic test_passed
    );
        integer bin_index;
        integer vector_index;
        integer error_i;
        integer error_q;
        logic signed [15:0] expected_i;
        logic signed [15:0] expected_q;
        begin
            test_passed = 1'b1;

            for (bin_index = 0; bin_index < N; bin_index = bin_index + 1) begin
                vector_index = test_number * N + bin_index;

                if (inverse) begin
                    expected_i = $signed(ifft128_expected[vector_index][31:16]);
                    expected_q = $signed(ifft128_expected[vector_index][15:0]);
                end else begin
                    expected_i = $signed(fft128_expected[vector_index][31:16]);
                    expected_q = $signed(fft128_expected[vector_index][15:0]);
                end

                error_i = absolute_difference(actual_i[bin_index], expected_i);
                error_q = absolute_difference(actual_q[bin_index], expected_q);

                if (inverse) begin
                    if (error_i == 0)
                        ifft128_exact_components = ifft128_exact_components + 1;
                    if (error_q == 0)
                        ifft128_exact_components = ifft128_exact_components + 1;
                    ifft128_absolute_error_sum =
                        ifft128_absolute_error_sum + error_i + error_q;
                    if (error_i > ifft128_maximum_error)
                        ifft128_maximum_error = error_i;
                    if (error_q > ifft128_maximum_error)
                        ifft128_maximum_error = error_q;
                end else begin
                    if (error_i == 0)
                        fft128_exact_components = fft128_exact_components + 1;
                    if (error_q == 0)
                        fft128_exact_components = fft128_exact_components + 1;
                    fft128_absolute_error_sum =
                        fft128_absolute_error_sum + error_i + error_q;
                    if (error_i > fft128_maximum_error)
                        fft128_maximum_error = error_i;
                    if (error_q > fft128_maximum_error)
                        fft128_maximum_error = error_q;
                end

                if ((error_i != 0) || (error_q != 0)) begin
                    test_passed = 1'b0;
                    $display(
                        "  %s mismatch test=%0d index=%0d expected=(%0d,%0d) actual=(%0d,%0d)",
                        inverse ? "IFFT128" : "FFT128",
                        test_number,
                        bin_index,
                        expected_i,
                        expected_q,
                        actual_i[bin_index],
                        actual_q[bin_index]
                    );
                end
            end
        end
    endtask

    task automatic run_block_test (
        input logic [7:0] command,
        input integer test_number,
        input logic inverse
    );
        integer command_accept_cycle;
        integer final_input_accept_cycle;
        integer first_result_cycle;
        integer last_result_cycle;
        logic test_passed;
        begin
            send_block_request(
                command,
                test_number,
                inverse,
                command_accept_cycle,
                final_input_accept_cycle
            );

            receive_block_results(first_result_cycle, last_result_cycle);
            check_block_result(test_number, inverse, test_passed);

            if (inverse) begin
                if (test_passed)
                    ifft128_passed = ifft128_passed + 1;
                else
                    ifft128_failed = ifft128_failed + 1;
                ifft128_command_to_last_sum =
                    ifft128_command_to_last_sum +
                    (last_result_cycle - command_accept_cycle);
                ifft128_input_to_last_sum =
                    ifft128_input_to_last_sum +
                    (last_result_cycle - final_input_accept_cycle);
            end else begin
                if (test_passed)
                    fft128_passed = fft128_passed + 1;
                else
                    fft128_failed = fft128_failed + 1;
                fft128_command_to_last_sum =
                    fft128_command_to_last_sum +
                    (last_result_cycle - command_accept_cycle);
                fft128_input_to_last_sum =
                    fft128_input_to_last_sum +
                    (last_result_cycle - final_input_accept_cycle);
            end

            $display(
                "%s test %0d %s command->last=%0d cycles last-input->last=%0d cycles",
                inverse ? "IFFT128" : "FFT128",
                test_number,
                test_passed ? "PASS" : "FAIL",
                last_result_cycle - command_accept_cycle,
                last_result_cycle - final_input_accept_cycle
            );
        end
    endtask



    //=========================================================================
    // OFDM_RX end-to-end regression
    //=========================================================================


    task automatic rx_send_byte (
        input  logic [7:0] byte_value,
        output integer     accept_cycle
    );
        integer wait_cycles;
        logic accepted;
        begin
            wait_cycles = 0;
            accepted = 1'b0;

            @(negedge clk);
            din = byte_value;
            din_valid_i = 1'b1;

            while (!accepted) begin
                @(posedge clk);
                if (din_valid_i && din_ready_o) begin
                    accept_cycle = cycle_count;
                    accepted = 1'b1;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout sending byte 0x%02h", byte_value);
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din = 8'h00;
        end
    endtask



    task automatic rx_send_ofdm_frame (
        input  logic       extended_mode,
        input  integer     test_index,
        output integer     command_cycle,
        output integer     final_input_cycle
    );
        integer sample_index;
        integer base_index;
        integer unused_cycle;
        logic [15:0] sample_word;
        begin
            rx_test_active = 1'b1;

            rx_send_byte(
                extended_mode
                    ? CMD_OFDM_RX_EXTENDED_CP
                    : CMD_OFDM_RX_NORMAL_CP,
                command_cycle
            );

            if (extended_mode) begin
                base_index = test_index * RX_EXTENDED_SAMPLES_PER_TEST;
                for (sample_index = 0;
                     sample_index < RX_EXTENDED_SAMPLES_PER_TEST;
                     sample_index = sample_index + 1) begin
                    sample_word = rx_extended_inputs[base_index + sample_index];
                    rx_send_byte(sample_word[15:8], unused_cycle);
                    rx_send_byte(sample_word[7:0], final_input_cycle);
                end
            end else begin
                base_index = test_index * RX_NORMAL_SAMPLES_PER_TEST;
                for (sample_index = 0;
                     sample_index < RX_NORMAL_SAMPLES_PER_TEST;
                     sample_index = sample_index + 1) begin
                    sample_word = rx_normal_inputs[base_index + sample_index];
                    rx_send_byte(sample_word[15:8], unused_cycle);
                    rx_send_byte(sample_word[7:0], final_input_cycle);
                end
            end
        end
    endtask



    task automatic rx_receive_and_check_frame (
        input  logic       extended_mode,
        input  integer     test_index,
        output integer     first_output_cycle,
        output integer     final_output_cycle,
        output logic       frame_passed
    );
        integer byte_index;
        integer bin_index;
        integer expected_base;
        integer wait_cycles;
        integer byte_error;
        logic started;
        logic [15:0] expected_word;
        logic [7:0] expected_byte;
        begin
            byte_index = 0;
            wait_cycles = 0;
            started = 1'b0;
            frame_passed = 1'b1;
            first_output_cycle = 0;
            final_output_cycle = 0;
            expected_base = test_index * 128;

            while (byte_index < 256) begin
                @(posedge clk);

                if (dout_valid_o) begin
                    if (!started) begin
                        started = 1'b1;
                        first_output_cycle = cycle_count;
                    end

                    bin_index = byte_index >> 1;
                    expected_word = extended_mode
                        ? rx_extended_expected[expected_base + bin_index]
                        : rx_normal_expected[expected_base + bin_index];
                    expected_byte = byte_index[0]
                        ? expected_word[7:0]
                        : expected_word[15:8];

                    byte_error = absolute_byte_error(dout, expected_byte);
                    rx_abs_error_sum = rx_abs_error_sum + byte_error;
                    if (byte_error > rx_max_abs_error)
                        rx_max_abs_error = byte_error;

                    if (dout === expected_byte) begin
                        rx_matched_bytes = rx_matched_bytes + 1;
                    end else begin
                        frame_passed = 1'b0;
                        $display(
                            "  Mismatch bin=%0d component=%s expected=%0d actual=%0d",
                            bin_index,
                            byte_index[0] ? "Q" : "I",
                            $signed(expected_byte),
                            $signed(dout)
                        );
                    end

                    if (byte_index == 255)
                        final_output_cycle = cycle_count;

                    byte_index = byte_index + 1;
                    wait_cycles = 0;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (started)
                        $fatal(1, "dout_valid_o dropped inside the 256-byte OFDM burst");
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for OFDM output");
                end
            end

            rx_test_active = 1'b0;
        end
    endtask



    task automatic run_ofdm_rx_mode (
        input logic   extended_mode,
        input integer test_index
    );
        integer command_cycle;
        integer final_input_cycle;
        integer first_output_cycle;
        integer final_output_cycle;
        integer command_to_first;
        integer command_to_last;
        integer input_to_first;
        integer input_to_last;
        logic frame_passed;
        begin
            rx_send_ofdm_frame(
                extended_mode,
                test_index,
                command_cycle,
                final_input_cycle
            );

            rx_receive_and_check_frame(
                extended_mode,
                test_index,
                first_output_cycle,
                final_output_cycle,
                frame_passed
            );

            command_to_first = first_output_cycle - command_cycle;
            command_to_last  = final_output_cycle - command_cycle;
            input_to_first   = first_output_cycle - final_input_cycle;
            input_to_last    = final_output_cycle - final_input_cycle;

            rx_command_to_first_sum = rx_command_to_first_sum + command_to_first;
            rx_command_to_last_sum  = rx_command_to_last_sum + command_to_last;
            rx_input_to_first_sum   = rx_input_to_first_sum + input_to_first;
            rx_input_to_last_sum    = rx_input_to_last_sum + input_to_last;

            if (command_to_first < rx_min_command_to_first)
                rx_min_command_to_first = command_to_first;
            if (command_to_first > rx_max_command_to_first)
                rx_max_command_to_first = command_to_first;
            if (command_to_last < rx_min_command_to_last)
                rx_min_command_to_last = command_to_last;
            if (command_to_last > rx_max_command_to_last)
                rx_max_command_to_last = command_to_last;

            if (frame_passed) begin
                rx_passed_frames = rx_passed_frames + 1;
                $display(
                    "%s test %0d PASS: cmd->first=%0d, last-input->first=%0d, cmd->last=%0d cycles",
                    extended_mode ? "EXTENDED_CP" : "NORMAL_CP",
                    test_index,
                    command_to_first,
                    input_to_first,
                    command_to_last
                );
            end else begin
                rx_failed_frames = rx_failed_frames + 1;
                $display(
                    "%s test %0d FAIL",
                    extended_mode ? "EXTENDED_CP" : "NORMAL_CP",
                    test_index
                );
            end
        end
    endtask


    //=========================================================================
    // DFT-s-OFDM TX end-to-end regression
    //=========================================================================


    task automatic tx_send_byte (
        input  logic [7:0] byte_value,
        output integer     accept_cycle
    );
        integer wait_cycles;
        logic accepted;
        begin
            wait_cycles = 0;
            accepted = 1'b0;

            @(negedge clk);
            din = byte_value;
            din_valid_i = 1'b1;

            while (!accepted) begin
                @(posedge clk);
                if (din_valid_i && din_ready_o) begin
                    accept_cycle = cycle_count;
                    accepted = 1'b1;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout sending byte 0x%02h", byte_value);
                end
            end

            @(negedge clk);
            din_valid_i = 1'b0;
            din = 8'h00;
        end
    endtask



    task automatic tx_send_tx_frame (
        input  logic   extended_mode,
        input  integer test_index,
        output integer command_cycle,
        output integer final_input_cycle
    );
        integer sample_index;
        integer base_index;
        integer unused_cycle;
        logic [15:0] sample_word;
        begin
            tx_test_active = 1'b1;
            tx_send_byte(
                extended_mode
                    ? CMD_OFDM_TX_EXTENDED_CP
                    : CMD_OFDM_TX_NORMAL_CP,
                command_cycle
            );

            base_index = test_index * 12;
            for (sample_index = 0; sample_index < 12;
                 sample_index = sample_index + 1) begin
                sample_word = extended_mode
                    ? tx_extended_inputs[base_index + sample_index]
                    : tx_normal_inputs[base_index + sample_index];
                tx_send_byte(sample_word[15:8], unused_cycle);
                tx_send_byte(sample_word[7:0], final_input_cycle);
            end
        end
    endtask



    task automatic tx_receive_and_check_frame (
        input  logic   extended_mode,
        input  integer test_index,
        output integer first_output_cycle,
        output integer final_output_cycle,
        output logic   frame_passed
    );
        integer cp_length;
        integer output_samples;
        integer output_bytes;
        integer byte_index;
        integer sample_index;
        integer expected_base;
        integer wait_cycles;
        integer byte_error;
        integer cp_byte;
        integer tail_byte;
        logic started;
        logic [15:0] expected_word;
        logic [7:0] expected_byte;
        begin
            cp_length = extended_mode ? EXTENDED_CP : NORMAL_CP;
            output_samples = 128 + cp_length;
            output_bytes = 2 * output_samples;
            expected_base = test_index * output_samples;

            byte_index = 0;
            wait_cycles = 0;
            started = 1'b0;
            frame_passed = 1'b1;
            first_output_cycle = 0;
            final_output_cycle = 0;

            while (byte_index < output_bytes) begin
                @(posedge clk);

                if (dout_valid_o) begin
                    if (!started) begin
                        started = 1'b1;
                        first_output_cycle = cycle_count;
                    end

                    tx_received_bytes[byte_index] = dout;
                    sample_index = byte_index >> 1;
                    expected_word = extended_mode
                        ? tx_extended_expected[expected_base + sample_index]
                        : tx_normal_expected[expected_base + sample_index];
                    expected_byte = byte_index[0]
                        ? expected_word[7:0]
                        : expected_word[15:8];

                    byte_error = absolute_byte_error(dout, expected_byte);
                    tx_abs_error_sum = tx_abs_error_sum + byte_error;
                    if (byte_error > tx_max_abs_error)
                        tx_max_abs_error = byte_error;

                    if (dout === expected_byte) begin
                        tx_matched_bytes = tx_matched_bytes + 1;
                    end else begin
                        frame_passed = 1'b0;
                        $display(
                            "  Mismatch output_sample=%0d component=%s expected=%0d actual=%0d",
                            sample_index,
                            byte_index[0] ? "Q" : "I",
                            $signed(expected_byte),
                            $signed(dout)
                        );
                    end

                    if (byte_index == output_bytes - 1)
                        final_output_cycle = cycle_count;

                    byte_index = byte_index + 1;
                    wait_cycles = 0;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (started)
                        $fatal(1, "dout_valid_o dropped inside TX output burst");
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for DFT-s-OFDM TX output");
                end
            end

            // CP sample j must exactly repeat body sample 128-cp_length+j.
            // In the output stream that body sample begins at output sample 128+j.
            for (sample_index = 0; sample_index < cp_length;
                 sample_index = sample_index + 1) begin
                cp_byte = 2 * sample_index;
                tail_byte = 2 * (128 + sample_index);
                if ((tx_received_bytes[cp_byte] !== tx_received_bytes[tail_byte]) ||
                    (tx_received_bytes[cp_byte + 1] !== tx_received_bytes[tail_byte + 1])) begin
                    frame_passed = 1'b0;
                    $display(
                        "  CP mismatch prefix_sample=%0d tail_output_sample=%0d",
                        sample_index, 128 + sample_index
                    );
                end
            end

            tx_test_active = 1'b0;
        end
    endtask



    task automatic run_ofdm_tx_mode (
        input logic   extended_mode,
        input integer test_index
    );
        integer command_cycle;
        integer final_input_cycle;
        integer first_output_cycle;
        integer final_output_cycle;
        integer output_bytes;
        logic frame_passed;
        begin
            tx_send_tx_frame(
                extended_mode,
                test_index,
                command_cycle,
                final_input_cycle
            );
            tx_receive_and_check_frame(
                extended_mode,
                test_index,
                first_output_cycle,
                final_output_cycle,
                frame_passed
            );

            output_bytes = 2 * (128 + (extended_mode ? EXTENDED_CP : NORMAL_CP));
            tx_total_bytes = tx_total_bytes + output_bytes;
            tx_command_to_first_sum = tx_command_to_first_sum +
                (first_output_cycle - command_cycle);
            tx_command_to_last_sum = tx_command_to_last_sum +
                (final_output_cycle - command_cycle);
            tx_input_to_first_sum = tx_input_to_first_sum +
                (first_output_cycle - final_input_cycle);
            tx_input_to_last_sum = tx_input_to_last_sum +
                (final_output_cycle - final_input_cycle);

            if (frame_passed) begin
                tx_passed_frames = tx_passed_frames + 1;
                $display(
                    "PASS %s test %0d: first=%0d last=%0d cycles after command",
                    extended_mode ? "extended-CP" : "normal-CP",
                    test_index,
                    first_output_cycle - command_cycle,
                    final_output_cycle - command_cycle
                );
            end else begin
                tx_failed_frames = tx_failed_frames + 1;
                $display(
                    "FAIL %s test %0d",
                    extended_mode ? "extended-CP" : "normal-CP",
                    test_index
                );
            end
        end
    endtask


    //=========================================================================
    // Main regression
    //=========================================================================

    initial begin
        integer test_number;
        integer total_failed;
        integer standalone_failed;
        integer two_point_total_components;
        integer fft3_total_components;
        integer dft12_total_components;
        integer fft128_total_components;
        integer ifft128_total_components;
        integer rx_total_frames;
        integer tx_total_frames;

        two_point_passed = 0;
        two_point_failed = 0;
        two_point_exact_components = 0;
        two_point_absolute_error_sum = 0;
        two_point_maximum_error = 0;
        two_point_command_latency_sum = 0;
        two_point_input_latency_sum = 0;

        fft3_passed = 0;
        fft3_failed = 0;
        fft3_exact_components = 0;
        fft3_absolute_error_sum = 0;
        fft3_maximum_error = 0;
        fft3_command_latency_sum = 0;
        fft3_input_latency_sum = 0;

        dft12_passed = 0;
        dft12_failed = 0;
        dft12_exact_components = 0;
        dft12_absolute_error_sum = 0;
        dft12_maximum_error = 0;
        dft12_command_to_last_sum = 0;
        dft12_input_to_last_sum = 0;

        fft128_passed = 0;
        fft128_failed = 0;
        fft128_exact_components = 0;
        fft128_absolute_error_sum = 0;
        fft128_maximum_error = 0;
        fft128_command_to_last_sum = 0;
        fft128_input_to_last_sum = 0;

        ifft128_passed = 0;
        ifft128_failed = 0;
        ifft128_exact_components = 0;
        ifft128_absolute_error_sum = 0;
        ifft128_maximum_error = 0;
        ifft128_command_to_last_sum = 0;
        ifft128_input_to_last_sum = 0;

        rx_passed_frames = 0;
        rx_failed_frames = 0;
        rx_matched_bytes = 0;
        rx_total_bytes = 2 * NUM_OFDM_RX_TESTS * 256;
        rx_abs_error_sum = 0;
        rx_max_abs_error = 0;
        rx_command_to_first_sum = 0;
        rx_command_to_last_sum = 0;
        rx_input_to_first_sum = 0;
        rx_input_to_last_sum = 0;
        rx_min_command_to_first = 32'h7fffffff;
        rx_max_command_to_first = 0;
        rx_min_command_to_last = 32'h7fffffff;
        rx_max_command_to_last = 0;

        tx_passed_frames = 0;
        tx_failed_frames = 0;
        tx_matched_bytes = 0;
        tx_total_bytes = 0;
        tx_abs_error_sum = 0;
        tx_max_abs_error = 0;
        tx_command_to_first_sum = 0;
        tx_command_to_last_sum = 0;
        tx_input_to_first_sum = 0;
        tx_input_to_last_sum = 0;

        $readmemh("vectors/two_point_commands.hex", two_point_commands);
        $readmemh("vectors/two_point_inputs.hex", two_point_inputs);
        $readmemh("vectors/two_point_expected.hex", two_point_expected);
        $readmemh("vectors/fft3_inputs.hex", fft3_inputs);
        $readmemh("vectors/fft3_expected.hex", fft3_expected);
        $readmemh("vectors/dft12_inputs.hex", dft12_inputs);
        $readmemh("vectors/dft12_expected.hex", dft12_expected);
        $readmemh("vectors/fft128_inputs.hex", fft128_inputs);
        $readmemh("vectors/fft128_expected.hex", fft128_expected);
        $readmemh("vectors/ifft128_inputs.hex", ifft128_inputs);
        $readmemh("vectors/ifft128_expected.hex", ifft128_expected);
        $readmemh("vectors/ofdm_rx_normal_cp_inputs.hex", rx_normal_inputs);
        $readmemh("vectors/ofdm_rx_extended_cp_inputs.hex", rx_extended_inputs);
        $readmemh("vectors/ofdm_rx_normal_cp_expected.hex", rx_normal_expected);
        $readmemh("vectors/ofdm_rx_extended_cp_expected.hex", rx_extended_expected);
        $readmemh("vectors/ofdm_tx_normal_cp_inputs.hex", tx_normal_inputs);
        $readmemh("vectors/ofdm_tx_extended_cp_inputs.hex", tx_extended_inputs);
        $readmemh("vectors/ofdm_tx_normal_cp_expected.hex", tx_normal_expected);
        $readmemh("vectors/ofdm_tx_extended_cp_expected.hex", tx_extended_expected);

        reset_dut();

        $display("============================================================");
        $display("1/7 FFT2 and IFFT2 mixed pipelined regression");
        $display("============================================================");
        standalone_test_active = 1'b1;
        fork
            drive_two_point_tests();
            monitor_two_point_tests();
        join

        $display("============================================================");
        $display("2/7 FFT3 regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_FFT3_TESTS;
             test_number = test_number + 1)
            run_fft3_test(test_number);

        $display("============================================================");
        $display("3/7 DFT12 regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_DFT12_TESTS;
             test_number = test_number + 1)
            run_dft12_test(test_number);

        $display("============================================================");
        $display("4/7 FFT128 regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_FFT128_TESTS;
             test_number = test_number + 1)
            run_block_test(CMD_FFT128, test_number, 1'b0);

        $display("============================================================");
        $display("5/7 IFFT128 regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_IFFT128_TESTS;
             test_number = test_number + 1)
            run_block_test(CMD_IFFT128, test_number, 1'b1);
        standalone_test_active = 1'b0;

        $display("============================================================");
        $display("6/7 OFDM_RX normal-CP and symbol-zero-CP regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_OFDM_RX_TESTS;
             test_number = test_number + 1)
            run_ofdm_rx_mode(1'b0, test_number);
        for (test_number = 0; test_number < NUM_OFDM_RX_TESTS;
             test_number = test_number + 1)
            run_ofdm_rx_mode(1'b1, test_number);

        $display("============================================================");
        $display("7/7 DFT-s-OFDM TX normal-CP and symbol-zero-CP regression");
        $display("============================================================");
        for (test_number = 0; test_number < NUM_OFDM_TX_TESTS;
             test_number = test_number + 1)
            run_ofdm_tx_mode(1'b0, test_number);
        for (test_number = 0; test_number < NUM_OFDM_TX_TESTS;
             test_number = test_number + 1)
            run_ofdm_tx_mode(1'b1, test_number);

        two_point_total_components = NUM_TWO_POINT_TESTS * 4;
        fft3_total_components = NUM_FFT3_TESTS * 6;
        dft12_total_components = NUM_DFT12_TESTS * DFT12_N * 2;
        fft128_total_components = NUM_FFT128_TESTS * N * 2;
        ifft128_total_components = NUM_IFFT128_TESTS * N * 2;
        rx_total_frames = 2 * NUM_OFDM_RX_TESTS;
        tx_total_frames = 2 * NUM_OFDM_TX_TESTS;

        $display("");
        $display("============================================================");
        $display("COMPLETE ALL-MODE REGRESSION SUMMARY");
        $display("============================================================");
        $display("FFT2/IFFT2: %0d/%0d tests; %0d/%0d exact components; max=%0d LSB",
                 two_point_passed, NUM_TWO_POINT_TESTS,
                 two_point_exact_components, two_point_total_components,
                 two_point_maximum_error);
        $display("FFT3:       %0d/%0d tests; %0d/%0d exact components; max=%0d LSB",
                 fft3_passed, NUM_FFT3_TESTS,
                 fft3_exact_components, fft3_total_components,
                 fft3_maximum_error);
        $display("DFT12:      %0d/%0d tests; %0d/%0d exact components; max=%0d LSB",
                 dft12_passed, NUM_DFT12_TESTS,
                 dft12_exact_components, dft12_total_components,
                 dft12_maximum_error);
        $display("FFT128:     %0d/%0d tests; %0d/%0d exact components; max=%0d LSB",
                 fft128_passed, NUM_FFT128_TESTS,
                 fft128_exact_components, fft128_total_components,
                 fft128_maximum_error);
        $display("IFFT128:    %0d/%0d tests; %0d/%0d exact components; max=%0d LSB",
                 ifft128_passed, NUM_IFFT128_TESTS,
                 ifft128_exact_components, ifft128_total_components,
                 ifft128_maximum_error);
        $display("OFDM_RX:    %0d/%0d frames; %0d/%0d exact output bytes; max=%0d LSB",
                 rx_passed_frames, rx_total_frames,
                 rx_matched_bytes, rx_total_bytes, rx_max_abs_error);
        $display("OFDM_TX:    %0d/%0d frames; %0d/%0d exact output bytes; max=%0d LSB",
                 tx_passed_frames, tx_total_frames,
                 tx_matched_bytes, tx_total_bytes, tx_max_abs_error);
        $display("");
        $display("Average command-to-final-result/output latency:");
        $display("  FFT2/IFFT2: %0.2f cycles",
                 1.0 * two_point_command_latency_sum / NUM_TWO_POINT_TESTS);
        $display("  FFT3:       %0.2f cycles",
                 1.0 * fft3_command_latency_sum / NUM_FFT3_TESTS);
        $display("  DFT12:      %0.2f cycles",
                 1.0 * dft12_command_to_last_sum / NUM_DFT12_TESTS);
        $display("  FFT128:     %0.2f cycles",
                 1.0 * fft128_command_to_last_sum / NUM_FFT128_TESTS);
        $display("  IFFT128:    %0.2f cycles",
                 1.0 * ifft128_command_to_last_sum / NUM_IFFT128_TESTS);
        $display("  OFDM_RX:    %0.2f cycles",
                 1.0 * rx_command_to_last_sum / rx_total_frames);
        $display("  OFDM_TX:    %0.2f cycles",
                 1.0 * tx_command_to_last_sum / tx_total_frames);
        $display("============================================================");

        standalone_failed = two_point_failed + fft3_failed + dft12_failed +
                            fft128_failed + ifft128_failed;
        total_failed = standalone_failed + rx_failed_frames + tx_failed_frames;

        if (total_failed == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL (%0d failed tests/frames)", total_failed);

        $finish;
    end

    initial begin
        $dumpfile("scheduler_full_regression_tb.vcd");
        $dumpvars(0, scheduler_full_regression_tb);
    end

endmodule

`default_nettype wire
