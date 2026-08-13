`timescale 1ns/1ps
`default_nettype none

module scheduler_mixed_radix_tb;

    parameter integer N                     = 128;
    parameter integer NUM_TWO_POINT_TESTS   = 8;
    parameter integer NUM_FFT3_TESTS        = 8;
    parameter integer NUM_FFT128_TESTS      = 5;
    parameter integer NUM_IFFT128_TESTS     = 5;
    parameter integer CLK_PERIOD_NS         = 10;
    parameter integer MAX_WAIT_CYCLES       = 200000;

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT128  = 8'h41;
    localparam logic [7:0] CMD_IFFT128 = 8'h42;
    localparam logic [7:0] CMD_IFFT2   = 8'h43;
    localparam logic [7:0] CMD_FFT3    = 8'h44;

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

    //=========================================================================
    // Golden vectors
    //=========================================================================

    logic [7:0]  two_point_commands [0:NUM_TWO_POINT_TESTS-1];
    logic [31:0] two_point_inputs   [0:NUM_TWO_POINT_TESTS-1];
    logic [63:0] two_point_expected [0:NUM_TWO_POINT_TESTS-1];

    logic [47:0] fft3_inputs   [0:NUM_FFT3_TESTS-1];
    logic [95:0] fft3_expected [0:NUM_FFT3_TESTS-1];

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
        .result_ready_i (result_ready_i)
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

    task automatic reset_dut;
        begin
            rst_n          = 1'b0;
            din            = 8'h00;
            din_valid_i    = 1'b0;
            result_ready_i = 1'b0;

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
    // Main regression
    //=========================================================================

    initial begin
        integer test_number;
        integer total_failed;
        integer two_point_total_components;
        integer fft3_total_components;
        integer fft128_total_components;
        integer ifft128_total_components;

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

        $readmemh("vectors/two_point_commands.hex", two_point_commands);
        $readmemh("vectors/two_point_inputs.hex", two_point_inputs);
        $readmemh("vectors/two_point_expected.hex", two_point_expected);
        $readmemh("vectors/fft3_inputs.hex", fft3_inputs);
        $readmemh("vectors/fft3_expected.hex", fft3_expected);
        $readmemh("vectors/fft128_inputs.hex", fft128_inputs);
        $readmemh("vectors/fft128_expected.hex", fft128_expected);
        $readmemh("vectors/ifft128_inputs.hex", ifft128_inputs);
        $readmemh("vectors/ifft128_expected.hex", ifft128_expected);

        reset_dut();

        $display("============================================================");
        $display("FFT2/IFFT2 mixed pipelined regression");
        $display("============================================================");

        fork
            drive_two_point_tests();
            monitor_two_point_tests();
        join

        $display("============================================================");
        $display("FFT3 regression");
        $display("============================================================");

        for (test_number = 0;
             test_number < NUM_FFT3_TESTS;
             test_number = test_number + 1) begin
            run_fft3_test(test_number);
        end

        $display("============================================================");
        $display("FFT128 regression");
        $display("============================================================");

        for (test_number = 0;
             test_number < NUM_FFT128_TESTS;
             test_number = test_number + 1) begin
            run_block_test(CMD_FFT128, test_number, 1'b0);
        end

        $display("============================================================");
        $display("IFFT128 regression");
        $display("============================================================");

        for (test_number = 0;
             test_number < NUM_IFFT128_TESTS;
             test_number = test_number + 1) begin
            run_block_test(CMD_IFFT128, test_number, 1'b1);
        end

        two_point_total_components = NUM_TWO_POINT_TESTS * 4;
        fft3_total_components = NUM_FFT3_TESTS * 6;
        fft128_total_components = NUM_FFT128_TESTS * N * 2;
        ifft128_total_components = NUM_IFFT128_TESTS * N * 2;

        $display("");
        $display("============================================================");
        $display("All-mode verification summary");
        $display("============================================================");
        $display("FFT2/IFFT2 tests:       %0d/%0d passed",
                 two_point_passed, NUM_TWO_POINT_TESTS);
        $display("FFT2/IFFT2 components:  %0d/%0d exact (%0.2f%%)",
                 two_point_exact_components,
                 two_point_total_components,
                 100.0 * two_point_exact_components /
                 two_point_total_components);
        $display("FFT2/IFFT2 mean error:  %0.6f LSB; max=%0d LSB",
                 1.0 * two_point_absolute_error_sum /
                 two_point_total_components,
                 two_point_maximum_error);
        $display("FFT2/IFFT2 avg command->result: %0.2f cycles",
                 1.0 * two_point_command_latency_sum /
                 NUM_TWO_POINT_TESTS);
        $display("FFT2/IFFT2 avg input->result:   %0.2f cycles",
                 1.0 * two_point_input_latency_sum /
                 NUM_TWO_POINT_TESTS);
        $display("");
        $display("FFT3 tests:             %0d/%0d passed",
                 fft3_passed, NUM_FFT3_TESTS);
        $display("FFT3 components:        %0d/%0d exact (%0.2f%%)",
                 fft3_exact_components, fft3_total_components,
                 100.0 * fft3_exact_components / fft3_total_components);
        $display("FFT3 mean error:        %0.6f LSB; max=%0d LSB",
                 1.0 * fft3_absolute_error_sum / fft3_total_components,
                 fft3_maximum_error);
        $display("FFT3 avg command->result: %0.2f cycles",
                 1.0 * fft3_command_latency_sum / NUM_FFT3_TESTS);
        $display("FFT3 avg input->result:   %0.2f cycles",
                 1.0 * fft3_input_latency_sum / NUM_FFT3_TESTS);
        $display("");
        $display("FFT128 tests:           %0d/%0d passed",
                 fft128_passed, NUM_FFT128_TESTS);
        $display("FFT128 components:      %0d/%0d exact (%0.2f%%)",
                 fft128_exact_components,
                 fft128_total_components,
                 100.0 * fft128_exact_components /
                 fft128_total_components);
        $display("FFT128 mean error:      %0.6f LSB; max=%0d LSB",
                 1.0 * fft128_absolute_error_sum /
                 fft128_total_components,
                 fft128_maximum_error);
        $display("FFT128 avg command->last: %0.2f cycles",
                 1.0 * fft128_command_to_last_sum /
                 NUM_FFT128_TESTS);
        $display("FFT128 avg input->last:   %0.2f cycles",
                 1.0 * fft128_input_to_last_sum /
                 NUM_FFT128_TESTS);
        $display("");
        $display("IFFT128 tests:          %0d/%0d passed",
                 ifft128_passed, NUM_IFFT128_TESTS);
        $display("IFFT128 components:     %0d/%0d exact (%0.2f%%)",
                 ifft128_exact_components,
                 ifft128_total_components,
                 100.0 * ifft128_exact_components /
                 ifft128_total_components);
        $display("IFFT128 mean error:     %0.6f LSB; max=%0d LSB",
                 1.0 * ifft128_absolute_error_sum /
                 ifft128_total_components,
                 ifft128_maximum_error);
        $display("IFFT128 avg command->last: %0.2f cycles",
                 1.0 * ifft128_command_to_last_sum /
                 NUM_IFFT128_TESTS);
        $display("IFFT128 avg input->last:   %0.2f cycles",
                 1.0 * ifft128_input_to_last_sum /
                 NUM_IFFT128_TESTS);
        $display("============================================================");

        total_failed =
            two_point_failed + fft3_failed + fft128_failed + ifft128_failed;

        if (total_failed == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL (%0d failed tests)", total_failed);

        $finish;
    end

    initial begin
        $dumpfile("scheduler_mixed_radix_tb.vcd");
        $dumpvars(0, scheduler_mixed_radix_tb);
    end

endmodule

`default_nettype wire
