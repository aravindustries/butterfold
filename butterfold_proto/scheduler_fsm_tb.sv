`timescale 1ns/1ps
`default_nettype none

module scheduler_tb;

    //==========================================================================
    // Testbench configuration
    //==========================================================================

    parameter int NUM_TESTS       = 5;
    parameter int CLK_PERIOD_NS   = 10;
    parameter int MAX_WAIT_CYCLES = 1000;

    localparam logic [7:0] CMD_FFT2 = 8'h40;

    //==========================================================================
    // DUT interface
    //==========================================================================

    logic clk;
    logic rst_n;

    logic [7:0] din;
    logic       din_valid_i;
    logic       din_ready_i;

    logic [7:0] dout;
    logic       dout_valid_o;
    logic       dout_ready_i;

    //==========================================================================
    // Vector storage
    //
    // Input line:
    //
    //     x0_i x0_q x1_i x1_q
    //
    // Four 8-bit values = 32 bits.
    //
    // Expected line:
    //
    //     X0_i X0_q X1_i X1_q
    //
    // Four 16-bit values = 64 bits.
    //==========================================================================

    logic [31:0] input_vectors    [0:NUM_TESTS-1];
    logic [63:0] expected_vectors [0:NUM_TESTS-1];

    logic [7:0] received_bytes [0:7];

    //==========================================================================
    // Current reconstructed result
    //==========================================================================

    logic signed [15:0] actual_X0_i;
    logic signed [15:0] actual_X0_q;
    logic signed [15:0] actual_X1_i;
    logic signed [15:0] actual_X1_q;

    logic signed [15:0] expected_X0_i;
    logic signed [15:0] expected_X0_q;
    logic signed [15:0] expected_X1_i;
    logic signed [15:0] expected_X1_q;

    //==========================================================================
    // Statistics
    //==========================================================================

    integer test_index;

    integer passed_tests;
    integer failed_tests;

    integer matched_components;
    integer total_components;

    integer absolute_error_sum;
    integer maximum_absolute_error;

    integer command_to_first_sum;
    integer command_to_last_sum;
    integer input_to_first_sum;

    integer min_command_to_first;
    integer max_command_to_first;

    integer min_command_to_last;
    integer max_command_to_last;

    integer min_input_to_first;
    integer max_input_to_first;

    real test_accuracy;
    real component_accuracy;
    real mean_absolute_error;

    real average_command_to_first;
    real average_command_to_last;
    real average_input_to_first;

    //==========================================================================
    // Clock generation
    //==========================================================================

    initial begin
        clk = 1'b0;

        forever begin
            #(CLK_PERIOD_NS / 2) clk = ~clk;
        end
    end

    //==========================================================================
    // DUT
    //==========================================================================

    scheduler dut (
        .clk          (clk),
        .rst_n        (rst_n),

        .din          (din),
        .din_valid_i  (din_valid_i),
        .din_ready_i  (din_ready_i),

        .dout         (dout),
        .dout_valid_o (dout_valid_o),
        .dout_ready_i (dout_ready_i)
    );

    //==========================================================================
    // Utility functions
    //==========================================================================

    function automatic integer absolute_difference (
        input logic signed [15:0] actual_value,
        input logic signed [15:0] expected_value
    );
        integer signed difference;

        begin
            difference =
                $signed(actual_value) -
                $signed(expected_value);

            if (difference < 0) begin
                absolute_difference = -difference;
            end else begin
                absolute_difference = difference;
            end
        end
    endfunction

    //==========================================================================
    // Reset task
    //==========================================================================

    task automatic reset_dut;
        begin
            rst_n        = 1'b0;
            din          = 8'h00;
            din_valid_i  = 1'b0;
            dout_ready_i = 1'b0;

            repeat (5) begin
                @(posedge clk);
            end

            @(negedge clk);

            rst_n        = 1'b1;
            dout_ready_i = 1'b1;
        end
    endtask

    //==========================================================================
    // FFT2 request driver
    //
    // Sends:
    //
    //     0x40, x0_i, x0_q, x1_i, x1_q
    //
    // The valid signal remains asserted between consecutive bytes so that the
    // request can be accepted at one byte per clock when the scheduler is
    // ready.
    //==========================================================================

    task automatic send_fft2_request (
        input  logic [31:0] input_word,
        output time         command_accept_time,
        output time         final_input_accept_time
    );
        logic [7:0] request_bytes [0:4];

        integer byte_index;
        integer wait_cycles;
        logic   byte_accepted;

        begin
            request_bytes[0] = CMD_FFT2;
            request_bytes[1] = input_word[31:24]; // x0_i
            request_bytes[2] = input_word[23:16]; // x0_q
            request_bytes[3] = input_word[15:8];  // x1_i
            request_bytes[4] = input_word[7:0];   // x1_q

            command_accept_time     = 0;
            final_input_accept_time = 0;

            @(negedge clk);

            din_valid_i = 1'b1;
            din         = request_bytes[0];

            for (byte_index = 0; byte_index < 5; byte_index++) begin
                wait_cycles  = 0;
                byte_accepted = 1'b0;

                while (!byte_accepted) begin
                    @(posedge clk);

                    if (din_valid_i && din_ready_i) begin
                        byte_accepted = 1'b1;

                        if (byte_index == 0) begin
                            command_accept_time = $time;
                        end

                        if (byte_index == 4) begin
                            final_input_accept_time = $time;
                        end
                    end else begin
                        wait_cycles = wait_cycles + 1;

                        if (wait_cycles >= MAX_WAIT_CYCLES) begin
                            $fatal(
                                1,
                                "Timeout sending request byte %0d",
                                byte_index
                            );
                        end
                    end
                end

                if (byte_index < 4) begin
                    /*
                     * Change to the next byte away from the active clock edge.
                     * Keep valid asserted for back-to-back transfers.
                     */
                    @(negedge clk);
                    din = request_bytes[byte_index + 1];
                end
            end

            @(negedge clk);

            din_valid_i = 1'b0;
            din         = 8'h00;
        end
    endtask

    //==========================================================================
    // FFT2 response receiver
    //
    // Receives:
    //
    //     X0_i low
    //     X0_i high
    //     X0_q low
    //     X0_q high
    //     X1_i low
    //     X1_i high
    //     X1_q low
    //     X1_q high
    //==========================================================================

    task automatic receive_fft2_response (
        output time first_output_accept_time,
        output time final_output_accept_time
    );
        integer byte_index;
        integer wait_cycles;
        logic   byte_accepted;

        begin
            first_output_accept_time = 0;
            final_output_accept_time = 0;

            for (byte_index = 0; byte_index < 8; byte_index++) begin
                wait_cycles   = 0;
                byte_accepted = 1'b0;

                while (!byte_accepted) begin
                    @(posedge clk);

                    if (dout_valid_o && dout_ready_i) begin
                        received_bytes[byte_index] = dout;
                        byte_accepted = 1'b1;

                        if (byte_index == 0) begin
                            first_output_accept_time = $time;
                        end

                        if (byte_index == 7) begin
                            final_output_accept_time = $time;
                        end
                    end else begin
                        wait_cycles = wait_cycles + 1;

                        if (wait_cycles >= MAX_WAIT_CYCLES) begin
                            $fatal(
                                1,
                                "Timeout waiting for response byte %0d",
                                byte_index
                            );
                        end
                    end
                end
            end
        end
    endtask

    //==========================================================================
    // Main test process
    //==========================================================================

    initial begin
        time command_accept_time;
        time final_input_accept_time;
        time first_output_accept_time;
        time final_output_accept_time;

        integer command_to_first_cycles;
        integer command_to_last_cycles;
        integer input_to_first_cycles;

        integer error_X0_i;
        integer error_X0_q;
        integer error_X1_i;
        integer error_X1_q;

        integer test_error_sum;
        logic   test_passed;

        //----------------------------------------------------------------------
        // Initialize statistics
        //----------------------------------------------------------------------

        passed_tests  = 0;
        failed_tests  = 0;

        matched_components = 0;
        total_components   = NUM_TESTS * 4;

        absolute_error_sum    = 0;
        maximum_absolute_error = 0;

        command_to_first_sum = 0;
        command_to_last_sum  = 0;
        input_to_first_sum   = 0;

        min_command_to_first = 32'h7fff_ffff;
        max_command_to_first = 0;

        min_command_to_last = 32'h7fff_ffff;
        max_command_to_last = 0;

        min_input_to_first = 32'h7fff_ffff;
        max_input_to_first = 0;

        //----------------------------------------------------------------------
        // Read vector files
        //----------------------------------------------------------------------

        $readmemh(
            "vectors/two_point_inputs.hex",
            input_vectors
        );

        $readmemh(
            "vectors/two_point_expected.hex",
            expected_vectors
        );

        reset_dut();

        $display("");
        $display("============================================================");
        $display("FFT2 scheduler verification");
        $display("Number of tests: %0d", NUM_TESTS);
        $display("Clock period:    %0d ns", CLK_PERIOD_NS);
        $display("============================================================");
        $display("");

        //----------------------------------------------------------------------
        // Run every test vector
        //----------------------------------------------------------------------

        for (
            test_index = 0;
            test_index < NUM_TESTS;
            test_index = test_index + 1
        ) begin
            /*
             * Catch missing or malformed vector-file entries.
             */
            if (^input_vectors[test_index] === 1'bx) begin
                $fatal(
                    1,
                    "Input vector %0d is unknown or missing",
                    test_index
                );
            end

            if (^expected_vectors[test_index] === 1'bx) begin
                $fatal(
                    1,
                    "Expected vector %0d is unknown or missing",
                    test_index
                );
            end

            //------------------------------------------------------------------
            // Drive one request and receive one result
            //------------------------------------------------------------------

            send_fft2_request(
                input_vectors[test_index],
                command_accept_time,
                final_input_accept_time
            );

            receive_fft2_response(
                first_output_accept_time,
                final_output_accept_time
            );

            //------------------------------------------------------------------
            // Reconstruct little-endian 16-bit output components
            //------------------------------------------------------------------

            actual_X0_i = $signed({
                received_bytes[1],
                received_bytes[0]
            });

            actual_X0_q = $signed({
                received_bytes[3],
                received_bytes[2]
            });

            actual_X1_i = $signed({
                received_bytes[5],
                received_bytes[4]
            });

            actual_X1_q = $signed({
                received_bytes[7],
                received_bytes[6]
            });

            //------------------------------------------------------------------
            // Unpack expected values
            //------------------------------------------------------------------

            expected_X0_i =
                $signed(expected_vectors[test_index][63:48]);

            expected_X0_q =
                $signed(expected_vectors[test_index][47:32]);

            expected_X1_i =
                $signed(expected_vectors[test_index][31:16]);

            expected_X1_q =
                $signed(expected_vectors[test_index][15:0]);

            //------------------------------------------------------------------
            // Calculate component errors
            //------------------------------------------------------------------

            error_X0_i = absolute_difference(
                actual_X0_i,
                expected_X0_i
            );

            error_X0_q = absolute_difference(
                actual_X0_q,
                expected_X0_q
            );

            error_X1_i = absolute_difference(
                actual_X1_i,
                expected_X1_i
            );

            error_X1_q = absolute_difference(
                actual_X1_q,
                expected_X1_q
            );

            test_error_sum =
                error_X0_i +
                error_X0_q +
                error_X1_i +
                error_X1_q;

            absolute_error_sum =
                absolute_error_sum +
                test_error_sum;

            if (error_X0_i > maximum_absolute_error)
                maximum_absolute_error = error_X0_i;

            if (error_X0_q > maximum_absolute_error)
                maximum_absolute_error = error_X0_q;

            if (error_X1_i > maximum_absolute_error)
                maximum_absolute_error = error_X1_i;

            if (error_X1_q > maximum_absolute_error)
                maximum_absolute_error = error_X1_q;

            //------------------------------------------------------------------
            // Count exact component matches
            //------------------------------------------------------------------

            if (actual_X0_i === expected_X0_i)
                matched_components = matched_components + 1;

            if (actual_X0_q === expected_X0_q)
                matched_components = matched_components + 1;

            if (actual_X1_i === expected_X1_i)
                matched_components = matched_components + 1;

            if (actual_X1_q === expected_X1_q)
                matched_components = matched_components + 1;

            test_passed =
                (actual_X0_i === expected_X0_i) &&
                (actual_X0_q === expected_X0_q) &&
                (actual_X1_i === expected_X1_i) &&
                (actual_X1_q === expected_X1_q);

            if (test_passed) begin
                passed_tests = passed_tests + 1;
            end else begin
                failed_tests = failed_tests + 1;
            end

            //------------------------------------------------------------------
            // Calculate measured cycle counts
            //
            // Time differences are divided by the clock period, giving the
            // number of rising-edge intervals between handshakes.
            //------------------------------------------------------------------

            command_to_first_cycles =
                (first_output_accept_time - command_accept_time) /
                CLK_PERIOD_NS;

            input_to_first_cycles =
                (first_output_accept_time - final_input_accept_time) /
                CLK_PERIOD_NS;

            command_to_last_cycles =
                (final_output_accept_time - command_accept_time) /
                CLK_PERIOD_NS;

            command_to_first_sum =
                command_to_first_sum +
                command_to_first_cycles;

            input_to_first_sum =
                input_to_first_sum +
                input_to_first_cycles;

            command_to_last_sum =
                command_to_last_sum +
                command_to_last_cycles;

            if (command_to_first_cycles < min_command_to_first)
                min_command_to_first = command_to_first_cycles;

            if (command_to_first_cycles > max_command_to_first)
                max_command_to_first = command_to_first_cycles;

            if (input_to_first_cycles < min_input_to_first)
                min_input_to_first = input_to_first_cycles;

            if (input_to_first_cycles > max_input_to_first)
                max_input_to_first = input_to_first_cycles;

            if (command_to_last_cycles < min_command_to_last)
                min_command_to_last = command_to_last_cycles;

            if (command_to_last_cycles > max_command_to_last)
                max_command_to_last = command_to_last_cycles;

            //------------------------------------------------------------------
            // Per-test report
            //------------------------------------------------------------------

            $display("Test %0d", test_index);

            $display(
                "  Inputs:   x0=(%0d,%0d), x1=(%0d,%0d)",
                $signed(input_vectors[test_index][31:24]),
                $signed(input_vectors[test_index][23:16]),
                $signed(input_vectors[test_index][15:8]),
                $signed(input_vectors[test_index][7:0])
            );

            $display(
                "  Expected: X0=(%0d,%0d), X1=(%0d,%0d)",
                expected_X0_i,
                expected_X0_q,
                expected_X1_i,
                expected_X1_q
            );

            $display(
                "  Actual:   X0=(%0d,%0d), X1=(%0d,%0d)",
                actual_X0_i,
                actual_X0_q,
                actual_X1_i,
                actual_X1_q
            );

            $display(
                "  LSB error: X0_i=%0d X0_q=%0d X1_i=%0d X1_q=%0d",
                error_X0_i,
                error_X0_q,
                error_X1_i,
                error_X1_q
            );

            $display(
                "  Latency: command->first=%0d cycles ",
                "last-input->first=%0d cycles ",
                "command->last=%0d cycles",
                command_to_first_cycles,
                input_to_first_cycles,
                command_to_last_cycles
            );

            if (test_passed) begin
                $display("  Result: PASS");
            end else begin
                $display("  Result: FAIL");
            end

            $display("");
        end

        //----------------------------------------------------------------------
        // Final statistics
        //----------------------------------------------------------------------

        test_accuracy =
            100.0 * passed_tests / NUM_TESTS;

        component_accuracy =
            100.0 * matched_components / total_components;

        mean_absolute_error =
            1.0 * absolute_error_sum / total_components;

        average_command_to_first =
            1.0 * command_to_first_sum / NUM_TESTS;

        average_input_to_first =
            1.0 * input_to_first_sum / NUM_TESTS;

        average_command_to_last =
            1.0 * command_to_last_sum / NUM_TESTS;

        $display("============================================================");
        $display("FFT2 verification summary");
        $display("============================================================");

        $display(
            "Tests passed:             %0d / %0d",
            passed_tests,
            NUM_TESTS
        );

        $display(
            "Test accuracy:            %0.2f%%",
            test_accuracy
        );

        $display(
            "Exact component matches:  %0d / %0d",
            matched_components,
            total_components
        );

        $display(
            "Component accuracy:       %0.2f%%",
            component_accuracy
        );

        $display(
            "Mean absolute error:      %0.4f LSB",
            mean_absolute_error
        );

        $display(
            "Maximum absolute error:   %0d LSB",
            maximum_absolute_error
        );

        $display("");

        $display(
            "Command -> first output:  avg=%0.2f min=%0d max=%0d cycles",
            average_command_to_first,
            min_command_to_first,
            max_command_to_first
        );

        $display(
            "Last input -> first out:  avg=%0.2f min=%0d max=%0d cycles",
            average_input_to_first,
            min_input_to_first,
            max_input_to_first
        );

        $display(
            "Command -> final output:  avg=%0.2f min=%0d max=%0d cycles",
            average_command_to_last,
            min_command_to_last,
            max_command_to_last
        );

        $display("============================================================");

        if (failed_tests == 0) begin
            $display("OVERALL RESULT: PASS");
        end else begin
            $display("OVERALL RESULT: FAIL");
        end

        $finish;
    end

    //==========================================================================
    // Optional waveform dump
    //==========================================================================

    initial begin
        $dumpfile("scheduler_tb.vcd");
        $dumpvars(0, scheduler_tb);
    end

endmodule

`default_nettype wire
