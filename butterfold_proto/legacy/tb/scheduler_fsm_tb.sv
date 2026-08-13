`timescale 1ns/1ps
`default_nettype none

module scheduler_tb;

    //==========================================================================
    // Testbench configuration
    //==========================================================================

    parameter integer NUM_TESTS       = 5;
    parameter integer CLK_PERIOD_NS   = 10;
    parameter integer MAX_WAIT_CYCLES = 1000;

    localparam logic [7:0] CMD_FFT2 = 8'h40;

    //==========================================================================
    // DUT interface
    //==========================================================================

    logic clk;
    logic rst_n;

    // Serialized input byte stream
    logic [7:0] din;
    logic       din_valid_i;
    logic       din_ready_o;

    // Parallel FFT2 output
    logic signed [15:0] X0_i_o;
    logic signed [15:0] X0_q_o;
    logic signed [15:0] X1_i_o;
    logic signed [15:0] X1_q_o;

    logic result_valid_o;
    logic result_ready_i;

    //==========================================================================
    // Vector storage
    //
    // Input line:
    //     x0_i x0_q x1_i x1_q
    //
    // Four 8-bit fields = 32 bits.
    //
    // Expected line:
    //     X0_i X0_q X1_i X1_q
    //
    // Four 16-bit fields = 64 bits.
    //==========================================================================

    logic [31:0] input_vectors    [0:NUM_TESTS-1];
    logic [63:0] expected_vectors [0:NUM_TESTS-1];

    //==========================================================================
    // Current result values
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
    integer cycle_count;

    integer passed_tests;
    integer failed_tests;

    integer matched_components;
    integer total_components;

    integer absolute_error_sum;
    integer maximum_absolute_error;

    integer command_to_result_sum;
    integer input_to_result_sum;

    integer min_command_to_result;
    integer max_command_to_result;

    integer min_input_to_result;
    integer max_input_to_result;

    real test_accuracy;
    real component_accuracy;
    real mean_absolute_error;

    real average_command_to_result;
    real average_input_to_result;

    //==========================================================================
    // Clock
    //==========================================================================

    initial begin
        clk = 1'b0;

        forever begin
            #(CLK_PERIOD_NS / 2) clk = ~clk;
        end
    end

    //==========================================================================
    // Cycle counter
    //==========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end

    //==========================================================================
    // DUT
    //==========================================================================

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

        .result_valid_o (result_valid_o),
        .result_ready_i (result_ready_i)
    );

    //==========================================================================
    // Absolute-error utility
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
    // Reset
    //==========================================================================

    task automatic reset_dut;
        begin
            rst_n          = 1'b0;
            din            = 8'h00;
            din_valid_i    = 1'b0;
            result_ready_i = 1'b0;

            repeat (5) begin
                @(posedge clk);
            end

            /*
             * Release reset away from the active clock edge.
             */
            @(negedge clk);

            rst_n          = 1'b1;
            result_ready_i = 1'b1;
        end
    endtask

    //==========================================================================
    // Send one byte through the scheduler input interface
    //==========================================================================

    task automatic send_byte (
        input  logic [7:0] byte_value,
        output integer     acceptance_cycle
    );
        integer wait_cycles;
        logic   accepted;

        begin
            wait_cycles = 0;
            accepted    = 1'b0;

            /*
             * Drive input away from the active clock edge.
             */
            @(negedge clk);

            din         = byte_value;
            din_valid_i = 1'b1;

            while (!accepted) begin
                @(posedge clk);

                if (din_valid_i && din_ready_o) begin
                    accepted         = 1'b1;
                    acceptance_cycle = cycle_count;
                end else begin
                    wait_cycles = wait_cycles + 1;

                    if (wait_cycles >= MAX_WAIT_CYCLES) begin
                        $fatal(
                            1,
                            "Timeout sending input byte 0x%02h",
                            byte_value
                        );
                    end
                end
            end

            @(negedge clk);

            din_valid_i = 1'b0;
            din         = 8'h00;
        end
    endtask

    //==========================================================================
    // Send one complete FFT2 request
    //
    // Input protocol:
    //
    //     byte 0: 0x40 command
    //     byte 1: x0_i
    //     byte 2: x0_q
    //     byte 3: x1_i
    //     byte 4: x1_q
    //==========================================================================

    task automatic send_fft2_request (
        input  logic [31:0] input_word,
        output integer      command_accept_cycle,
        output integer      final_input_accept_cycle
    );
        integer unused_cycle;

        begin
            send_byte(
                CMD_FFT2,
                command_accept_cycle
            );

            send_byte(
                input_word[31:24],
                unused_cycle
            );

            send_byte(
                input_word[23:16],
                unused_cycle
            );

            send_byte(
                input_word[15:8],
                unused_cycle
            );

            send_byte(
                input_word[7:0],
                final_input_accept_cycle
            );
        end
    endtask

    //==========================================================================
    // Receive one complete parallel FFT2 result
    //
    // All four output components are sampled on the same handshake:
    //
    //     result_valid_o && result_ready_i
    //==========================================================================

    task automatic receive_fft2_result (
        output integer result_accept_cycle
    );
        integer wait_cycles;
        logic   accepted;

        begin
            wait_cycles = 0;
            accepted    = 1'b0;

            while (!accepted) begin
                @(posedge clk);

                if (result_valid_o && result_ready_i) begin
                    /*
                     * Capture all four components atomically.
                     */
                    actual_X0_i = X0_i_o;
                    actual_X0_q = X0_q_o;
                    actual_X1_i = X1_i_o;
                    actual_X1_q = X1_q_o;

                    result_accept_cycle = cycle_count;
                    accepted            = 1'b1;
                end else begin
                    wait_cycles = wait_cycles + 1;

                    if (wait_cycles >= MAX_WAIT_CYCLES) begin
                        $fatal(
                            1,
                            "Timeout waiting for parallel FFT2 result"
                        );
                    end
                end
            end
        end
    endtask

    //==========================================================================
    // Main test sequence
    //==========================================================================

    initial begin
        integer command_accept_cycle;
        integer final_input_accept_cycle;
        integer result_accept_cycle;

        integer command_to_result_cycles;
        integer input_to_result_cycles;

        integer error_X0_i;
        integer error_X0_q;
        integer error_X1_i;
        integer error_X1_q;

        integer test_error_sum;

        logic test_passed;

        //----------------------------------------------------------------------
        // Initialize testbench signals and statistics
        //----------------------------------------------------------------------

        rst_n          = 1'b0;
        din            = 8'h00;
        din_valid_i    = 1'b0;
        result_ready_i = 1'b0;

        cycle_count = 0;

        passed_tests = 0;
        failed_tests = 0;

        matched_components = 0;
        total_components   = NUM_TESTS * 4;

        absolute_error_sum     = 0;
        maximum_absolute_error = 0;

        command_to_result_sum = 0;
        input_to_result_sum   = 0;

        min_command_to_result = 32'h7fff_ffff;
        max_command_to_result = 0;

        min_input_to_result = 32'h7fff_ffff;
        max_input_to_result = 0;

        //----------------------------------------------------------------------
        // Load vectors
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
        $display("Parallel-output FFT2 scheduler verification");
        $display("Tests:        %0d", NUM_TESTS);
        $display("Clock period: %0d ns", CLK_PERIOD_NS);
        $display("============================================================");
        $display("");

        //----------------------------------------------------------------------
        // Execute every test vector
        //----------------------------------------------------------------------

        for (
            test_index = 0;
            test_index < NUM_TESTS;
            test_index = test_index + 1
        ) begin
            //------------------------------------------------------------------
            // Verify vector-file entries are initialized
            //------------------------------------------------------------------

            if (^input_vectors[test_index] === 1'bx) begin
                $fatal(
                    1,
                    "Input vector %0d is missing or malformed",
                    test_index
                );
            end

            if (^expected_vectors[test_index] === 1'bx) begin
                $fatal(
                    1,
                    "Expected vector %0d is missing or malformed",
                    test_index
                );
            end

            //------------------------------------------------------------------
            // Send request and receive one parallel result
            //------------------------------------------------------------------

            send_fft2_request(
                input_vectors[test_index],
                command_accept_cycle,
                final_input_accept_cycle
            );

            receive_fft2_result(
                result_accept_cycle
            );

            //------------------------------------------------------------------
            // Unpack expected result
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
            // Calculate errors in integer Q-format codes
            //----------------------------------------------------------------------

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

            if (error_X0_i > maximum_absolute_error) begin
                maximum_absolute_error = error_X0_i;
            end

            if (error_X0_q > maximum_absolute_error) begin
                maximum_absolute_error = error_X0_q;
            end

            if (error_X1_i > maximum_absolute_error) begin
                maximum_absolute_error = error_X1_i;
            end

            if (error_X1_q > maximum_absolute_error) begin
                maximum_absolute_error = error_X1_q;
            end

            //------------------------------------------------------------------
            // Count exact component matches
            //----------------------------------------------------------------------

            if (actual_X0_i === expected_X0_i) begin
                matched_components = matched_components + 1;
            end

            if (actual_X0_q === expected_X0_q) begin
                matched_components = matched_components + 1;
            end

            if (actual_X1_i === expected_X1_i) begin
                matched_components = matched_components + 1;
            end

            if (actual_X1_q === expected_X1_q) begin
                matched_components = matched_components + 1;
            end

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
            // Latency measurements
            //----------------------------------------------------------------------

            command_to_result_cycles =
                result_accept_cycle -
                command_accept_cycle;

            input_to_result_cycles =
                result_accept_cycle -
                final_input_accept_cycle;

            command_to_result_sum =
                command_to_result_sum +
                command_to_result_cycles;

            input_to_result_sum =
                input_to_result_sum +
                input_to_result_cycles;

            if (
                command_to_result_cycles <
                min_command_to_result
            ) begin
                min_command_to_result =
                    command_to_result_cycles;
            end

            if (
                command_to_result_cycles >
                max_command_to_result
            ) begin
                max_command_to_result =
                    command_to_result_cycles;
            end

            if (
                input_to_result_cycles <
                min_input_to_result
            ) begin
                min_input_to_result =
                    input_to_result_cycles;
            end

            if (
                input_to_result_cycles >
                max_input_to_result
            ) begin
                max_input_to_result =
                    input_to_result_cycles;
            end

            //------------------------------------------------------------------
            // Per-test report
            //----------------------------------------------------------------------

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
                "  Error:    X0_i=%0d X0_q=%0d X1_i=%0d X1_q=%0d LSB",
                error_X0_i,
                error_X0_q,
                error_X1_i,
                error_X1_q
            );

            $display(
                "  Latency:  command->result=%0d cycles ",
                "last-input->result=%0d cycles",
                command_to_result_cycles,
                input_to_result_cycles
            );

            if (test_passed) begin
                $display("  Result:   PASS");
            end else begin
                $display("  Result:   FAIL");
            end

            $display("");
        end

        //----------------------------------------------------------------------
        // Final report
        //----------------------------------------------------------------------

        test_accuracy =
            100.0 * passed_tests / NUM_TESTS;

        component_accuracy =
            100.0 * matched_components / total_components;

        mean_absolute_error =
            1.0 * absolute_error_sum / total_components;

        average_command_to_result =
            1.0 * command_to_result_sum / NUM_TESTS;

        average_input_to_result =
            1.0 * input_to_result_sum / NUM_TESTS;

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
            "Command -> result:        avg=%0.2f min=%0d max=%0d cycles",
            average_command_to_result,
            min_command_to_result,
            max_command_to_result
        );

        $display(
            "Last input -> result:     avg=%0.2f min=%0d max=%0d cycles",
            average_input_to_result,
            min_input_to_result,
            max_input_to_result
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
    // Waveform dump
    //==========================================================================

    initial begin
        $dumpfile("scheduler_tb.vcd");
        $dumpvars(0, scheduler_tb);
    end

endmodule

`default_nettype wire
