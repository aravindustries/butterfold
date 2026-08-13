`timescale 1ns/1ps
`default_nettype none

module scheduler_ifft128_tb;

    parameter integer N               = 128;
    parameter integer NUM_TESTS       = 5;
    parameter integer CLK_PERIOD_NS   = 10;
    parameter integer MAX_WAIT_CYCLES = 100000;

    localparam logic [7:0] CMD_IFFT128 = 8'h42;
    localparam integer TOTAL_SAMPLES = NUM_TESTS * N;

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

    logic [6:0] result_addr0_o;
    logic [6:0] result_addr1_o;
    logic       result_last_o;
    logic       result_valid_o;
    logic       result_ready_i;

    //=========================================================================
    // Test vectors
    //
    // ifft128_inputs.hex:
    //     one 16-bit line per input sample: {i[7:0], q[7:0]}
    //
    // ifft128_expected.hex:
    //     one 32-bit line per output bin: {I[15:0], Q[15:0]}
    //=========================================================================

    logic [15:0] input_vectors    [0:TOTAL_SAMPLES-1];
    logic [31:0] expected_vectors [0:TOTAL_SAMPLES-1];

    logic signed [15:0] actual_i [0:N-1];
    logic signed [15:0] actual_q [0:N-1];
    logic               bin_seen [0:N-1];

    //=========================================================================
    // Statistics
    //=========================================================================

    integer cycle_count;
    integer test_index;

    integer passed_tests;
    integer failed_tests;
    integer exact_bins;
    integer exact_components;
    integer total_bins;
    integer total_components;
    integer absolute_error_sum;
    integer maximum_absolute_error;

    integer command_to_first_sum;
    integer command_to_last_sum;
    integer input_to_first_sum;
    integer input_to_last_sum;

    integer min_command_to_first;
    integer max_command_to_first;
    integer min_command_to_last;
    integer max_command_to_last;
    integer min_input_to_first;
    integer max_input_to_first;
    integer min_input_to_last;
    integer max_input_to_last;

    real test_accuracy;
    real bin_accuracy;
    real component_accuracy;
    real mean_absolute_error;

    //=========================================================================
    // Clock and cycle counter
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

    //=========================================================================
    // DUT
    //=========================================================================

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

        .result_addr0_o (result_addr0_o),
        .result_addr1_o (result_addr1_o),
        .result_last_o  (result_last_o),
        .result_valid_o (result_valid_o),
        .result_ready_i (result_ready_i)
    );

    //=========================================================================
    // Utility
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

    // Send command plus 128 interleaved I/Q samples with no intentional gaps.
    task automatic send_ifft128_request (
        input  integer current_test,
        output integer command_accept_cycle,
        output integer final_input_accept_cycle
    );
        integer sample_index;
        integer vector_index;
        integer accepted_cycle;
        integer wait_cycles;
        logic   accepted;
        begin
            @(negedge clk);
            din_valid_i = 1'b1;
            din         = CMD_IFFT128;

            // Command handshake.
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
                        $fatal(1, "Timeout sending IFFT128 command");
                end
            end

            // Keep valid asserted and change data only on falling edges.
            for (sample_index = 0; sample_index < N; sample_index = sample_index + 1) begin
                vector_index = current_test * N + sample_index;

                @(negedge clk);
                din = input_vectors[vector_index][15:8];

                accepted    = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted = 1'b1;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending IFFT128 sample %0d I", sample_index);
                    end
                end

                @(negedge clk);
                din = input_vectors[vector_index][7:0];

                accepted    = 1'b0;
                wait_cycles = 0;
                while (!accepted) begin
                    @(posedge clk);
                    if (din_valid_i && din_ready_o) begin
                        accepted_cycle = cycle_count;
                        accepted = 1'b1;
                    end else begin
                        wait_cycles = wait_cycles + 1;
                        if (wait_cycles >= MAX_WAIT_CYCLES)
                            $fatal(1, "Timeout sending IFFT128 sample %0d Q", sample_index);
                    end
                end
            end

            final_input_accept_cycle = accepted_cycle;

            @(negedge clk);
            din_valid_i = 1'b0;
            din         = 8'h00;
        end
    endtask

    // Collect 64 final-stage butterfly transactions. Each transaction provides
    // two output bins and their natural-order destination addresses.
    task automatic receive_ifft128_results (
        output integer first_result_cycle,
        output integer last_result_cycle
    );
        integer transaction_count;
        integer wait_cycles;
        integer bin_index;
        begin
            transaction_count = 0;
            wait_cycles       = 0;
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
                    if (result_addr0_o >= N || result_addr1_o >= N)
                        $fatal(1, "Output address out of range: %0d, %0d",
                               result_addr0_o, result_addr1_o);

                    if (bin_seen[result_addr0_o])
                        $fatal(1, "Duplicate output bin %0d", result_addr0_o);

                    if (bin_seen[result_addr1_o])
                        $fatal(1, "Duplicate output bin %0d", result_addr1_o);

                    actual_i[result_addr0_o] = X0_i_o;
                    actual_q[result_addr0_o] = X0_q_o;
                    actual_i[result_addr1_o] = X1_i_o;
                    actual_q[result_addr1_o] = X1_q_o;
                    bin_seen[result_addr0_o] = 1'b1;
                    bin_seen[result_addr1_o] = 1'b1;

                    if (transaction_count == 0)
                        first_result_cycle = cycle_count;

                    if (result_last_o) begin
                        if (transaction_count != (N/2 - 1))
                            $fatal(1, "result_last_o asserted early at transaction %0d",
                                   transaction_count);
                        last_result_cycle = cycle_count;
                    end

                    transaction_count = transaction_count + 1;
                    wait_cycles = 0;
                end else begin
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles >= MAX_WAIT_CYCLES)
                        $fatal(1, "Timeout waiting for IFFT128 result transaction %0d",
                               transaction_count);
                end
            end

            if (last_result_cycle < 0)
                $fatal(1, "IFFT128 completed without result_last_o");

            for (bin_index = 0; bin_index < N; bin_index = bin_index + 1) begin
                if (!bin_seen[bin_index])
                    $fatal(1, "IFFT128 output bin %0d was never received", bin_index);
            end
        end
    endtask

    //=========================================================================
    // Main test process
    //=========================================================================

    initial begin
        integer command_accept_cycle;
        integer final_input_accept_cycle;
        integer first_result_cycle;
        integer last_result_cycle;

        integer command_to_first_cycles;
        integer command_to_last_cycles;
        integer input_to_first_cycles;
        integer input_to_last_cycles;

        integer bin_index;
        integer vector_index;
        integer error_i;
        integer error_q;
        integer test_error_sum;
        integer test_exact_bins;
        integer test_exact_components;

        logic signed [15:0] expected_i;
        logic signed [15:0] expected_q;
        logic test_passed;

        passed_tests = 0;
        failed_tests = 0;
        exact_bins = 0;
        exact_components = 0;
        total_bins = NUM_TESTS * N;
        total_components = NUM_TESTS * N * 2;
        absolute_error_sum = 0;
        maximum_absolute_error = 0;

        command_to_first_sum = 0;
        command_to_last_sum  = 0;
        input_to_first_sum   = 0;
        input_to_last_sum    = 0;

        min_command_to_first = 32'h7fff_ffff;
        max_command_to_first = 0;
        min_command_to_last  = 32'h7fff_ffff;
        max_command_to_last  = 0;
        min_input_to_first   = 32'h7fff_ffff;
        max_input_to_first   = 0;
        min_input_to_last    = 32'h7fff_ffff;
        max_input_to_last    = 0;

        $readmemh("vectors/ifft128_inputs.hex", input_vectors);
        $readmemh("vectors/ifft128_expected.hex", expected_vectors);

        reset_dut();

        $display("");
        $display("============================================================");
        $display("IFFT128 scheduler verification");
        $display("Tests:        %0d", NUM_TESTS);
        $display("Clock period: %0d ns", CLK_PERIOD_NS);
        $display("============================================================");

        for (test_index = 0; test_index < NUM_TESTS; test_index = test_index + 1) begin
            send_ifft128_request(
                test_index,
                command_accept_cycle,
                final_input_accept_cycle
            );

            receive_ifft128_results(
                first_result_cycle,
                last_result_cycle
            );

            test_error_sum       = 0;
            test_exact_bins      = 0;
            test_exact_components = 0;

            for (bin_index = 0; bin_index < N; bin_index = bin_index + 1) begin
                vector_index = test_index * N + bin_index;
                expected_i = $signed(expected_vectors[vector_index][31:16]);
                expected_q = $signed(expected_vectors[vector_index][15:0]);

                error_i = absolute_difference(actual_i[bin_index], expected_i);
                error_q = absolute_difference(actual_q[bin_index], expected_q);

                test_error_sum = test_error_sum + error_i + error_q;

                if (error_i == 0)
                    test_exact_components = test_exact_components + 1;
                if (error_q == 0)
                    test_exact_components = test_exact_components + 1;
                if (error_i == 0 && error_q == 0)
                    test_exact_bins = test_exact_bins + 1;

                if (error_i > maximum_absolute_error)
                    maximum_absolute_error = error_i;
                if (error_q > maximum_absolute_error)
                    maximum_absolute_error = error_q;

                if (error_i != 0 || error_q != 0) begin
                    $display(
                        "  Mismatch test=%0d bin=%0d expected=(%0d,%0d) actual=(%0d,%0d)",
                        test_index,
                        bin_index,
                        expected_i,
                        expected_q,
                        actual_i[bin_index],
                        actual_q[bin_index]
                    );
                end
            end

            exact_bins       = exact_bins + test_exact_bins;
            exact_components = exact_components + test_exact_components;
            absolute_error_sum = absolute_error_sum + test_error_sum;

            test_passed = (test_exact_bins == N);
            if (test_passed)
                passed_tests = passed_tests + 1;
            else
                failed_tests = failed_tests + 1;

            command_to_first_cycles = first_result_cycle - command_accept_cycle;
            command_to_last_cycles  = last_result_cycle - command_accept_cycle;
            input_to_first_cycles   = first_result_cycle - final_input_accept_cycle;
            input_to_last_cycles    = last_result_cycle - final_input_accept_cycle;

            command_to_first_sum = command_to_first_sum + command_to_first_cycles;
            command_to_last_sum  = command_to_last_sum  + command_to_last_cycles;
            input_to_first_sum   = input_to_first_sum   + input_to_first_cycles;
            input_to_last_sum    = input_to_last_sum    + input_to_last_cycles;

            if (command_to_first_cycles < min_command_to_first)
                min_command_to_first = command_to_first_cycles;
            if (command_to_first_cycles > max_command_to_first)
                max_command_to_first = command_to_first_cycles;
            if (command_to_last_cycles < min_command_to_last)
                min_command_to_last = command_to_last_cycles;
            if (command_to_last_cycles > max_command_to_last)
                max_command_to_last = command_to_last_cycles;
            if (input_to_first_cycles < min_input_to_first)
                min_input_to_first = input_to_first_cycles;
            if (input_to_first_cycles > max_input_to_first)
                max_input_to_first = input_to_first_cycles;
            if (input_to_last_cycles < min_input_to_last)
                min_input_to_last = input_to_last_cycles;
            if (input_to_last_cycles > max_input_to_last)
                max_input_to_last = input_to_last_cycles;

            $display("");
            $display("Test %0d: %s", test_index, test_passed ? "PASS" : "FAIL");
            $display("  Exact bins:             %0d / %0d", test_exact_bins, N);
            $display("  Exact components:       %0d / %0d", test_exact_components, 2*N);
            $display("  Command -> first result:%0d cycles", command_to_first_cycles);
            $display("  Last input -> first:    %0d cycles", input_to_first_cycles);
            $display("  Command -> last result: %0d cycles", command_to_last_cycles);
            $display("  Last input -> last:     %0d cycles", input_to_last_cycles);
        end

        test_accuracy = 100.0 * passed_tests / NUM_TESTS;
        bin_accuracy = 100.0 * exact_bins / total_bins;
        component_accuracy = 100.0 * exact_components / total_components;
        mean_absolute_error = 1.0 * absolute_error_sum / total_components;

        $display("");
        $display("============================================================");
        $display("IFFT128 verification summary");
        $display("============================================================");
        $display("Tests passed:            %0d / %0d", passed_tests, NUM_TESTS);
        $display("Test accuracy:           %0.2f%%", test_accuracy);
        $display("Exact bins:              %0d / %0d (%0.2f%%)",
                 exact_bins, total_bins, bin_accuracy);
        $display("Exact components:        %0d / %0d (%0.2f%%)",
                 exact_components, total_components, component_accuracy);
        $display("Mean absolute error:     %0.6f LSB", mean_absolute_error);
        $display("Maximum absolute error:  %0d LSB", maximum_absolute_error);
        $display("");
        $display("Command -> first result: avg=%0.2f min=%0d max=%0d cycles",
                 1.0 * command_to_first_sum / NUM_TESTS,
                 min_command_to_first, max_command_to_first);
        $display("Last input -> first:     avg=%0.2f min=%0d max=%0d cycles",
                 1.0 * input_to_first_sum / NUM_TESTS,
                 min_input_to_first, max_input_to_first);
        $display("Command -> last result:  avg=%0.2f min=%0d max=%0d cycles",
                 1.0 * command_to_last_sum / NUM_TESTS,
                 min_command_to_last, max_command_to_last);
        $display("Last input -> last:      avg=%0.2f min=%0d max=%0d cycles",
                 1.0 * input_to_last_sum / NUM_TESTS,
                 min_input_to_last, max_input_to_last);
        $display("============================================================");

        if (failed_tests == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $finish;
    end

    initial begin
        $dumpfile("scheduler_ifft128_tb.vcd");
        $dumpvars(0, scheduler_ifft128_tb);
    end

endmodule

`default_nettype wire
