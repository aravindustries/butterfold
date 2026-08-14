`timescale 1ns/1ps
`default_nettype none

module scheduler_ofdm_tx_tb;

    parameter integer NUM_TESTS       = 5;
    parameter integer CLK_PERIOD_NS   = 10;
    parameter integer MAX_WAIT_CYCLES = 50000;

    localparam logic [7:0] CMD_OFDM_TX_NORMAL_CP   = 8'h48;
    localparam logic [7:0] CMD_OFDM_TX_EXTENDED_CP = 8'h49;
    localparam integer NORMAL_CP   = 9;
    localparam integer EXTENDED_CP = 10;
    localparam integer NORMAL_OUTPUT_SAMPLES   = NORMAL_CP + 128;
    localparam integer EXTENDED_OUTPUT_SAMPLES = EXTENDED_CP + 128;

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

    logic [15:0] normal_inputs [0:NUM_TESTS*12-1];
    logic [15:0] extended_inputs [0:NUM_TESTS*12-1];
    logic [15:0] normal_expected [0:NUM_TESTS*NORMAL_OUTPUT_SAMPLES-1];
    logic [15:0] extended_expected [0:NUM_TESTS*EXTENDED_OUTPUT_SAMPLES-1];
    logic [7:0] received_bytes [0:2*EXTENDED_OUTPUT_SAMPLES-1];

    integer cycle_count;
    integer passed_frames;
    integer failed_frames;
    integer matched_bytes;
    integer total_bytes;
    integer abs_error_sum;
    integer max_abs_error;

    integer command_to_first_sum;
    integer command_to_last_sum;
    integer input_to_first_sum;
    integer input_to_last_sum;

    logic tx_test_active;

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

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    // DFT12 and IFFT128 results are internal during DFT-s-OFDM TX.
    always @(posedge clk) begin
        if (rst_n && tx_test_active && result_valid_o)
            $fatal(1, "Parallel result_valid_o asserted during DFT-s-OFDM TX");
    end

    function automatic integer absolute_byte_error (
        input logic [7:0] actual_value,
        input logic [7:0] expected_value
    );
        integer signed actual_signed;
        integer signed expected_signed;
        integer signed difference;
        begin
            actual_signed = $signed(actual_value);
            expected_signed = $signed(expected_value);
            difference = actual_signed - expected_signed;
            absolute_byte_error = (difference < 0) ? -difference : difference;
        end
    endfunction

    task automatic reset_dut;
        begin
            rst_n          = 1'b0;
            din            = 8'h00;
            din_valid_i    = 1'b0;
            result_ready_i = 1'b1;
            tx_test_active = 1'b0;

            repeat (5) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic send_byte (
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

    task automatic send_tx_frame (
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
            send_byte(
                extended_mode
                    ? CMD_OFDM_TX_EXTENDED_CP
                    : CMD_OFDM_TX_NORMAL_CP,
                command_cycle
            );

            base_index = test_index * 12;
            for (sample_index = 0; sample_index < 12;
                 sample_index = sample_index + 1) begin
                sample_word = extended_mode
                    ? extended_inputs[base_index + sample_index]
                    : normal_inputs[base_index + sample_index];
                send_byte(sample_word[15:8], unused_cycle);
                send_byte(sample_word[7:0], final_input_cycle);
            end
        end
    endtask

    task automatic receive_and_check_frame (
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

                    received_bytes[byte_index] = dout;
                    sample_index = byte_index >> 1;
                    expected_word = extended_mode
                        ? extended_expected[expected_base + sample_index]
                        : normal_expected[expected_base + sample_index];
                    expected_byte = byte_index[0]
                        ? expected_word[7:0]
                        : expected_word[15:8];

                    byte_error = absolute_byte_error(dout, expected_byte);
                    abs_error_sum = abs_error_sum + byte_error;
                    if (byte_error > max_abs_error)
                        max_abs_error = byte_error;

                    if (dout === expected_byte) begin
                        matched_bytes = matched_bytes + 1;
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
                if ((received_bytes[cp_byte] !== received_bytes[tail_byte]) ||
                    (received_bytes[cp_byte + 1] !== received_bytes[tail_byte + 1])) begin
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

    task automatic run_mode (
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
            send_tx_frame(
                extended_mode,
                test_index,
                command_cycle,
                final_input_cycle
            );
            receive_and_check_frame(
                extended_mode,
                test_index,
                first_output_cycle,
                final_output_cycle,
                frame_passed
            );

            output_bytes = 2 * (128 + (extended_mode ? EXTENDED_CP : NORMAL_CP));
            total_bytes = total_bytes + output_bytes;
            command_to_first_sum = command_to_first_sum +
                (first_output_cycle - command_cycle);
            command_to_last_sum = command_to_last_sum +
                (final_output_cycle - command_cycle);
            input_to_first_sum = input_to_first_sum +
                (first_output_cycle - final_input_cycle);
            input_to_last_sum = input_to_last_sum +
                (final_output_cycle - final_input_cycle);

            if (frame_passed) begin
                passed_frames = passed_frames + 1;
                $display(
                    "PASS %s test %0d: first=%0d last=%0d cycles after command",
                    extended_mode ? "extended-CP" : "normal-CP",
                    test_index,
                    first_output_cycle - command_cycle,
                    final_output_cycle - command_cycle
                );
            end else begin
                failed_frames = failed_frames + 1;
                $display(
                    "FAIL %s test %0d",
                    extended_mode ? "extended-CP" : "normal-CP",
                    test_index
                );
            end
        end
    endtask

    integer test_index;
    integer total_frames;
    real mean_abs_error;

    initial begin
        $readmemh("vectors/ofdm_tx_normal_cp_inputs.hex", normal_inputs);
        $readmemh("vectors/ofdm_tx_extended_cp_inputs.hex", extended_inputs);
        $readmemh("vectors/ofdm_tx_normal_cp_expected.hex", normal_expected);
        $readmemh("vectors/ofdm_tx_extended_cp_expected.hex", extended_expected);

        passed_frames = 0;
        failed_frames = 0;
        matched_bytes = 0;
        total_bytes = 0;
        abs_error_sum = 0;
        max_abs_error = 0;
        command_to_first_sum = 0;
        command_to_last_sum = 0;
        input_to_first_sum = 0;
        input_to_last_sum = 0;

        reset_dut();

        for (test_index = 0; test_index < NUM_TESTS;
             test_index = test_index + 1)
            run_mode(1'b0, test_index);

        for (test_index = 0; test_index < NUM_TESTS;
             test_index = test_index + 1)
            run_mode(1'b1, test_index);

        total_frames = 2 * NUM_TESTS;
        mean_abs_error = (total_bytes == 0)
            ? 0.0 : (1.0 * abs_error_sum / total_bytes);

        $display("============================================================");
        $display("DFT-s-OFDM TX regression summary");
        $display("Frames passed:       %0d / %0d", passed_frames, total_frames);
        $display("Bytes matched:       %0d / %0d", matched_bytes, total_bytes);
        $display("Mean abs byte error: %0.4f LSB", mean_abs_error);
        $display("Max abs byte error:  %0d LSB", max_abs_error);
        $display(
            "Command->first:    avg=%0.2f cycles",
            1.0 * command_to_first_sum / total_frames
        );
        $display(
            "Command->last:     avg=%0.2f cycles",
            1.0 * command_to_last_sum / total_frames
        );
        $display(
            "Last-input->first: avg=%0.2f cycles",
            1.0 * input_to_first_sum / total_frames
        );
        $display(
            "Last-input->last:  avg=%0.2f cycles",
            1.0 * input_to_last_sum / total_frames
        );
        $display("============================================================");

        if (failed_frames == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $finish;
    end

    initial begin
        $dumpfile("scheduler_ofdm_tx_tb.vcd");
        $dumpvars(0, scheduler_ofdm_tx_tb);
    end

endmodule

`default_nettype wire
