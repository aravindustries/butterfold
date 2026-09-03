`timescale 1ns/1ps
`default_nettype none

module butterfold_top_tb;
    localparam integer N = 64;
    localparam integer SHORT_CP = 4;
    localparam integer LONG_CP = 5;
    localparam integer DFT12_N = 12;
    localparam integer RX_NUM_TESTS = 4;
    localparam integer SC_START_BIN = 1;
    localparam integer NUM_EXTRACTED_SC = 12;
    localparam integer MAX_WAIT = 200000;
`ifdef BUTTERFOLD_WAVE_PACED
    localparam integer TEST_TX_BYTE_INTERVAL = 16;
`else
    localparam integer TEST_TX_BYTE_INTERVAL = 1;
`endif
    localparam integer EXPECTED_RX_SHORT_FAST = 1902;
    localparam integer EXPECTED_RX_LONG_FAST = 1906;
    localparam integer EXPECTED_TX_SHORT_FAST = 2136;
    localparam integer EXPECTED_TX_LONG_FAST = 2138;
    localparam integer EXPECTED_RX_SHORT_PACED = 1902;
    localparam integer EXPECTED_RX_LONG_PACED = 1906;
    localparam integer EXPECTED_TX_SHORT_PACED = 4161;
    localparam integer EXPECTED_TX_LONG_PACED = 4193;

    localparam logic [7:0] CMD_FFT2    = 8'h40;
    localparam logic [7:0] CMD_FFT64   = 8'h41;
    localparam logic [7:0] CMD_IFFT64  = 8'h42;
    localparam logic [7:0] CMD_IFFT2   = 8'h43;
    localparam logic [7:0] CMD_FFT3    = 8'h44;
    localparam logic [7:0] CMD_DFT12   = 8'h45;
    localparam logic [7:0] CMD_RX_SHORT = 8'h46;
    localparam logic [7:0] CMD_RX_LONG  = 8'h47;
    localparam logic [7:0] CMD_TX_SHORT = 8'h48;
    localparam logic [7:0] CMD_TX_LONG  = 8'h49;
    localparam logic [7:0] CMD_ECHO       = 8'h4a;
    localparam logic [7:0] CMD_MAGIC      = 8'h4b;
    localparam logic [7:0] CMD_SRAM_READ  = 8'h4c;
    localparam logic [7:0] CMD_SRAM_WRITE = 8'h4d;

    logic clk;
    logic rst_n;
    logic [7:0] din;
    logic din_valid_i;
    logic din_ready_o;
    logic [7:0] dout;
    logic dout_valid_o;

    // Independent vectors generated under golden/vectors/.
    logic [7:0]  two_point_commands [0:7];
    logic [31:0] two_point_inputs   [0:7];
    logic [63:0] two_point_expected [0:7];

    logic [47:0] fft3_inputs   [0:7];
    logic [95:0] fft3_expected [0:7];

    logic [15:0] dft12_inputs   [0:8*12-1];
    logic [31:0] dft12_expected [0:8*12-1];

    logic [15:0] fft64_inputs   [0:5*N-1];
    logic [31:0] fft64_expected [0:5*N-1];
    logic [15:0] ifft64_inputs   [0:5*N-1];
    logic [31:0] ifft64_expected [0:5*N-1];

    logic [15:0] rx_short_inputs [0:4*(SHORT_CP+N)-1];
    logic [15:0] rx_long_inputs  [0:4*(LONG_CP+N)-1];
    logic [15:0] rx_short_expected [0:RX_NUM_TESTS*N-1];
    logic [15:0] rx_long_expected  [0:RX_NUM_TESTS*N-1];

    logic [15:0] tx_short_inputs [0:5*12-1];
    logic [15:0] tx_long_inputs  [0:5*12-1];
    logic [15:0] tx_short_expected [0:5*(SHORT_CP+N)-1];
    logic [15:0] tx_long_expected  [0:5*(LONG_CP+N)-1];

    logic signed [15:0] actual_i [0:N-1];
    logic signed [15:0] actual_q [0:N-1];
    logic seen [0:N-1];

    integer errors;
    integer cycle_count;

`ifdef BUTTERFOLD_PERF
    integer perf_fft_state_cycles [0:10];
    integer perf_fft_index;
    integer perf_butterflies;
    integer perf_reads;
    integer perf_writes;
    integer perf_results;
    integer perf_last_result_cycle;
    integer perf_compute_count;

    initial begin
        perf_butterflies = 0;
        perf_reads = 0;
        perf_writes = 0;
        perf_results = 0;
        perf_last_result_cycle = 0;
        perf_compute_count = 0;
        for (perf_fft_index = 0; perf_fft_index <= 10;
             perf_fft_index = perf_fft_index + 1)
            perf_fft_state_cycles[perf_fft_index] = 0;
    end

    always @(posedge clk) begin
        if (dut.u_transform_scheduler_core.fft128_start) begin
            perf_butterflies = 0;
            perf_reads = 0;
            perf_writes = 0;
            perf_results = 0;
            perf_last_result_cycle = cycle_count;
            perf_compute_count = 0;
            for (perf_fft_index = 0; perf_fft_index <= 10;
                 perf_fft_index = perf_fft_index + 1)
                perf_fft_state_cycles[perf_fft_index] = 0;
            $display("PERF FFT_START t=%0t inverse=%0d ofdm=%0d tx=%0d",
                $time,
                dut.u_transform_scheduler_core.fft128_block_inverse,
                dut.u_transform_scheduler_core.ofdm_fft_block_ready ||
                    dut.u_transform_scheduler_core.tx_ifft_block_ready,
                dut.u_transform_scheduler_core.tx_ifft_block_ready);
        end
        if (dut.u_transform_scheduler_core.fft128_active) begin
            if (dut.u_transform_scheduler_core.u_mixed_radix_butterfly.compute_fire &&
                perf_compute_count < 20) begin
                $display("PERF BF_COMPUTE index=%0d cycle=%0d",
                    perf_compute_count, cycle_count);
                perf_compute_count = perf_compute_count + 1;
            end
            perf_fft_state_cycles[dut.u_transform_scheduler_core.fft128_state] =
                perf_fft_state_cycles[dut.u_transform_scheduler_core.fft128_state] + 1;
            if (dut.u_transform_scheduler_core.fft_mem_req &&
                !dut.u_transform_scheduler_core.fft_mem_write)
                perf_reads = perf_reads + 1;
            if (dut.u_transform_scheduler_core.fft_mem_req &&
                dut.u_transform_scheduler_core.fft_mem_write)
                perf_writes = perf_writes + 1;
            if (dut.u_transform_scheduler_core.bf_result_fire) begin
                if (perf_results < 20)
                    $display("PERF BF_RESULT index=%0d cycle=%0d delta=%0d",
                        perf_results, cycle_count,
                        cycle_count - perf_last_result_cycle);
                perf_last_result_cycle = cycle_count;
                perf_results = perf_results + 1;
                if (!dut.u_transform_scheduler_core.dft12_active)
                    perf_butterflies = perf_butterflies + 1;
            end
        end
        if (dut.u_transform_scheduler_core.fft128_done) begin
            $display("PERF FFT_DONE t=%0t butterflies=%0d reads=%0d results=%0d writes=%0d states=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                $time, perf_butterflies, perf_reads, perf_results, perf_writes,
                perf_fft_state_cycles[0], perf_fft_state_cycles[1],
                perf_fft_state_cycles[2], perf_fft_state_cycles[3],
                perf_fft_state_cycles[4], perf_fft_state_cycles[5],
                perf_fft_state_cycles[6], perf_fft_state_cycles[7],
                perf_fft_state_cycles[8], perf_fft_state_cycles[9] + 1,
                perf_fft_state_cycles[10]);
        end
        if (dut.u_transform_scheduler_core.dft12_done)
            $display("PERF DFT12_DONE t=%0t tx=%0d", $time,
                dut.u_transform_scheduler_core.dft12_tx_active);
        if (dut.u_transform_scheduler_core.dft12_start)
            $display("PERF DFT12_START t=%0t tx_ready=%0d", $time,
                dut.u_transform_scheduler_core.tx_dft12_block_ready);
        if (dut.u_transform_scheduler_core.tx_mapper_done)
            $display("PERF MAPPER_DONE t=%0t", $time);
        if (dut.u_transform_scheduler_core.ofdm_output_start)
            $display("PERF RX_SERIAL_START t=%0t", $time);
        if (dut.u_transform_scheduler_core.ofdm_output_done)
            $display("PERF RX_SERIAL_DONE t=%0t", $time);
        if (dut.u_transform_scheduler_core.tx_output_start)
            $display("PERF TX_SERIAL_START t=%0t", $time);
        if (dut.u_transform_scheduler_core.tx_output_done)
            $display("PERF TX_SERIAL_DONE t=%0t", $time);
        if (dut.core_rx_selected_complete)
            $display("PERF RX_EXTRACT_DONE t=%0t", $time);
        if (dut.core_rx_complete)
            $display("PERF RX_CORE_DONE t=%0t", $time);
        if (dut.core_tx_complete)
            $display("PERF TX_BANK_READY t=%0t", $time);
        if (dut.feeder_start)
            $display("PERF FEEDER_START t=%0t cmd=%02h", $time,
                dut.job_head_command);
        if (dut.external_fire && dut.ext_state == 0)
            $display("PERF COMMAND t=%0t cmd=%02h", $time, din);
        if (dut.external_fire)
            $display("PERF DIN t=%0t state=%0d data=%02h", $time,
                dut.ext_state, din);
        if (dout_valid_o)
            $display("PERF DOUT t=%0t data=%02h", $time, dout);
    end
`endif

    butterfold_core #(
        .TRANSACTION_FIFO_DEPTH(4),
        .TX_BYTE_INTERVAL(TEST_TX_BYTE_INTERVAL)
    ) dut (
        .rst_n        (rst_n),
        .clk          (clk),
        .din          (din),
        .din_valid_i  (din_valid_i),
        .din_ready_o  (din_ready_o),
        .dout         (dout),
        .dout_valid_o (dout_valid_o)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle_count <= cycle_count + 1;

    task automatic send_byte(input logic [7:0] value);
        integer wait_count;
        logic accepted;
        begin
            @(negedge clk);
            din <= value;
            din_valid_i <= 1'b1;
            wait_count = 0;
            accepted = 1'b0;
            while (!accepted) begin
                @(posedge clk);
                if (din_valid_i && din_ready_o)
                    accepted = 1'b1;
                else begin
                    wait_count = wait_count + 1;
                    if (wait_count > MAX_WAIT)
                        $fatal(1, "Timeout sending byte %02h", value);
                end
            end
            @(negedge clk);
            din_valid_i <= 1'b0;
            din <= 8'h00;
        end
    endtask

    task automatic recv_byte(output logic [7:0] value);
        integer wait_count;
        logic received;
        begin
            wait_count = 0;
            received = 1'b0;
            while (!received) begin
                @(posedge clk);
                if (dout_valid_o) begin
                    value = dout;
                    received = 1'b1;
                end else begin
                    wait_count = wait_count + 1;
                    if (wait_count > MAX_WAIT)
                        $fatal(1, "Timeout waiting for dout byte");
                end
            end
        end
    endtask

    task automatic debug_write(input logic [7:0] addr, input logic [15:0] value);
        logic [7:0] ack;
        begin
            send_byte(CMD_SRAM_WRITE);
            send_byte(addr);
            send_byte(value[15:8]);
            send_byte(value[7:0]);
            recv_byte(ack);
            if (ack !== 8'hac) begin
                $display("SRAM WRITE ack mismatch addr=%02h got=%02h", addr, ack);
                errors = errors + 1;
            end
        end
    endtask

    task automatic debug_read(input logic [7:0] addr, output logic [15:0] value);
        logic [7:0] hi, lo;
        begin
            send_byte(CMD_SRAM_READ);
            send_byte(addr);
            recv_byte(hi);
            recv_byte(lo);
            value = {hi,lo};
        end
    endtask

    task automatic run_debug_protocol;
        logic [7:0] b;
        logic [15:0] got, expected_debug;
        integer a;
        begin
            send_byte(CMD_ECHO); send_byte(8'ha5); recv_byte(b);
            if (b !== 8'ha5) begin $display("ECHO mismatch"); errors=errors+1; end

            send_byte(CMD_MAGIC);
            recv_byte(b); if (b!==8'h42) begin $display("MAGIC[0] mismatch"); errors=errors+1; end
            recv_byte(b); if (b!==8'h46) begin $display("MAGIC[1] mismatch"); errors=errors+1; end
            recv_byte(b); if (b!==8'h4c) begin $display("MAGIC[2] mismatch"); errors=errors+1; end
            recv_byte(b); if (b!==8'h44) begin $display("MAGIC[3] mismatch"); errors=errors+1; end

            debug_write(8'h00,16'h0000); debug_read(8'h00,got);
            if(got!==16'h0000) begin $display("SRAM zero mismatch"); errors=errors+1; end
            debug_write(8'h01,16'hffff); debug_read(8'h01,got);
            if(got!==16'hffff) begin $display("SRAM ones mismatch"); errors=errors+1; end
            debug_write(8'h02,16'haaaa); debug_read(8'h02,got);
            if(got!==16'haaaa) begin $display("SRAM AAAA mismatch"); errors=errors+1; end
            debug_write(8'h03,16'h5555); debug_read(8'h03,got);
            if(got!==16'h5555) begin $display("SRAM 5555 mismatch"); errors=errors+1; end

            for(a=0;a<16;a=a+1) begin
                debug_write(8'h10+a[7:0],16'h0001<<a);
                debug_read(8'h10+a[7:0],got);
                if(got!==(16'h0001<<a)) begin $display("SRAM walking-1 mismatch %0d",a); errors=errors+1; end
                debug_write(8'h20+a[7:0],~(16'h0001<<a));
                debug_read(8'h20+a[7:0],got);
                if(got!==(~(16'h0001<<a))) begin $display("SRAM walking-0 mismatch %0d",a); errors=errors+1; end
            end

            for(a=0;a<256;a=a+1) begin
                expected_debug = (a * 16'h9e37) ^ 16'ha5a5;
                debug_write(a[7:0],expected_debug);
                debug_read(a[7:0],got);
                if(got!==expected_debug) begin
                    $display("SRAM sweep mismatch addr=%02h exp=%04h got=%04h",a[7:0],expected_debug,got);
                    errors=errors+1;
                end
            end
            $display("PASS debug protocol: ECHO MAGIC SRAM READ/WRITE full sweep");
        end
    endtask

    // One standalone complex output record:
    // address, I high, I low, Q high, Q low.
    task automatic recv_complex_record(
        output logic [6:0] addr,
        output logic signed [15:0] value_i,
        output logic signed [15:0] value_q
    );
        logic [7:0] b0, b1, b2, b3, b4;
        begin
            recv_byte(b0);
            recv_byte(b1);
            recv_byte(b2);
            recv_byte(b3);
            recv_byte(b4);
            addr = b0[6:0];
            value_i = $signed({b1,b2});
            value_q = $signed({b3,b4});
        end
    endtask

    task automatic clear_actual;
        integer k;
        begin
            for (k=0; k<N; k=k+1) begin
                actual_i[k] = '0;
                actual_q[k] = '0;
                seen[k] = 1'b0;
            end
        end
    endtask

    task automatic run_two_point(input integer test_index);
        logic [6:0] addr;
        logic signed [15:0] vi, vq;
        logic signed [15:0] exp_i [0:1];
        logic signed [15:0] exp_q [0:1];
        integer r;
        begin
            clear_actual();
            send_byte(two_point_commands[test_index]);
            send_byte(two_point_inputs[test_index][31:24]);
            send_byte(two_point_inputs[test_index][23:16]);
            send_byte(two_point_inputs[test_index][15:8]);
            send_byte(two_point_inputs[test_index][7:0]);

            for (r=0; r<2; r=r+1) begin
                recv_complex_record(addr, vi, vq);
                if (addr > 1) begin
                    $display("2PT invalid address %0d", addr); errors=errors+1;
                end else begin
                    actual_i[addr]=vi; actual_q[addr]=vq; seen[addr]=1'b1;
                end
            end
            exp_i[0] = $signed(two_point_expected[test_index][63:48]);
            exp_q[0] = $signed(two_point_expected[test_index][47:32]);
            exp_i[1] = $signed(two_point_expected[test_index][31:16]);
            exp_q[1] = $signed(two_point_expected[test_index][15:0]);
            for (r=0; r<2; r=r+1) begin
                if (!seen[r] || actual_i[r] !== exp_i[r] || actual_q[r] !== exp_q[r]) begin
                    $display("2PT mismatch bin %0d expected=(%0d,%0d) actual=(%0d,%0d)",
                        r, exp_i[r], exp_q[r], actual_i[r], actual_q[r]);
                    errors=errors+1;
                end
            end
            $display("PASS interface exercise: %s", two_point_commands[test_index]==CMD_FFT2 ? "FFT2" : "IFFT2");
        end
    endtask

    task automatic run_fft3;
        logic [6:0] addr;
        logic signed [15:0] vi, vq;
        logic signed [15:0] ei, eq;
        integer r;
        begin
            clear_actual();
            send_byte(CMD_FFT3);
            for (r=5; r>=0; r=r-1)
                send_byte(fft3_inputs[0][r*8 +: 8]);
            for (r=0; r<3; r=r+1) begin
                recv_complex_record(addr,vi,vq);
                actual_i[addr]=vi; actual_q[addr]=vq; seen[addr]=1'b1;
            end
            for (r=0; r<3; r=r+1) begin
                case (r)
                    0: begin ei=$signed(fft3_expected[0][95:80]); eq=$signed(fft3_expected[0][79:64]); end
                    1: begin ei=$signed(fft3_expected[0][63:48]); eq=$signed(fft3_expected[0][47:32]); end
                    default: begin ei=$signed(fft3_expected[0][31:16]); eq=$signed(fft3_expected[0][15:0]); end
                endcase
                if (!seen[r] || actual_i[r]!==ei || actual_q[r]!==eq) begin
                    $display("FFT3 mismatch bin %0d",r); errors=errors+1;
                end
            end
            $display("PASS interface exercise: FFT3");
        end
    endtask

    task automatic run_block_standalone(
        input logic [7:0] command,
        input integer size,
        input integer input_base,
        input integer expected_base
    );
        logic [6:0] addr;
        logic signed [15:0] vi,vq,ei,eq;
        integer k;
        begin
            clear_actual();
            send_byte(command);
            for (k=0;k<size;k=k+1) begin
                if (command==CMD_DFT12) begin
                    send_byte(dft12_inputs[input_base+k][15:8]);
                    send_byte(dft12_inputs[input_base+k][7:0]);
                end else if (command==CMD_FFT64) begin
                    send_byte(fft64_inputs[input_base+k][15:8]);
                    send_byte(fft64_inputs[input_base+k][7:0]);
                end else begin
                    send_byte(ifft64_inputs[input_base+k][15:8]);
                    send_byte(ifft64_inputs[input_base+k][7:0]);
                end
            end
            for (k=0;k<size;k=k+1) begin
                recv_complex_record(addr,vi,vq);
                if (addr >= size || seen[addr]) begin
                    $display("Standalone block command %02h bad/duplicate address %0d",command,addr);
                    errors=errors+1;
                end else begin
                    actual_i[addr]=vi; actual_q[addr]=vq; seen[addr]=1'b1;
                end
            end
            for (k=0;k<size;k=k+1) begin
                if (command==CMD_DFT12) begin
                    ei=$signed(dft12_expected[expected_base+k][31:16]);
                    eq=$signed(dft12_expected[expected_base+k][15:0]);
                end else if (command==CMD_FFT64) begin
                    ei=$signed(fft64_expected[expected_base+k][31:16]);
                    eq=$signed(fft64_expected[expected_base+k][15:0]);
                end else begin
                    ei=$signed(ifft64_expected[expected_base+k][31:16]);
                    eq=$signed(ifft64_expected[expected_base+k][15:0]);
                end
                if (!seen[k] || actual_i[k]!==ei || actual_q[k]!==eq) begin
                    $display("Standalone block command %02h mismatch bin %0d expected=(%0d,%0d) actual=(%0d,%0d)",
                        command,k,ei,eq,actual_i[k],actual_q[k]);
                    errors=errors+1;
                end
            end
            $display("PASS interface exercise: command 0x%02h",command);
        end
    endtask

    task automatic run_rx(input logic [7:0] command, input logic long_cp);
        integer count, k;
        logic [7:0] b;
        logic [15:0] e;
        begin
            count = long_cp ? (LONG_CP + N) : (SHORT_CP + N);
            send_byte(command);
            for (k=0;k<count;k=k+1) begin
                if (long_cp) begin
                    send_byte(rx_long_inputs[k][15:8]);
                    send_byte(rx_long_inputs[k][7:0]);
                end else begin
                    send_byte(rx_short_inputs[k][15:8]);
                    send_byte(rx_short_inputs[k][7:0]);
                end
            end
            for (k=0;k<NUM_EXTRACTED_SC;k=k+1) begin
                e = long_cp
                    ? rx_long_expected[SC_START_BIN+k]
                    : rx_short_expected[SC_START_BIN+k];
                recv_byte(b); if (b!==e[15:8]) begin $display("RX %02h I byte mismatch %0d",command,k); errors=errors+1; end
                recv_byte(b); if (b!==e[7:0])  begin $display("RX %02h Q byte mismatch %0d",command,k); errors=errors+1; end
            end
            $display("PASS interface exercise: OFDM_RX 0x%02h",command);
        end
    endtask

    task automatic run_tx(input logic [7:0] command, input logic long_cp);
        integer out_samples, k;
        logic [7:0] b;
        logic [15:0] e;
        begin
            out_samples = long_cp ? (LONG_CP + N) : (SHORT_CP + N);
            send_byte(command);
            for (k=0;k<12;k=k+1) begin
                if (long_cp) begin
                    send_byte(tx_long_inputs[k][15:8]);
                    send_byte(tx_long_inputs[k][7:0]);
                end else begin
                    send_byte(tx_short_inputs[k][15:8]);
                    send_byte(tx_short_inputs[k][7:0]);
                end
            end
            for (k=0;k<out_samples;k=k+1) begin
                e = long_cp ? tx_long_expected[k] : tx_short_expected[k];
                recv_byte(b); if (b!==e[15:8]) begin $display("TX %02h I byte mismatch %0d",command,k); errors=errors+1; end
                recv_byte(b); if (b!==e[7:0])  begin $display("TX %02h Q byte mismatch %0d",command,k); errors=errors+1; end
            end
            $display("PASS interface exercise: OFDM_TX 0x%02h",command);
        end
    endtask

`ifdef BUTTERFOLD_STRESS
    integer stress_feeder_cycle [0:3];
    integer stress_feeder_count;
    always @(posedge clk) begin
        if (dut.feeder_start && stress_feeder_count < 4) begin
            stress_feeder_cycle[stress_feeder_count] = cycle_count;
            stress_feeder_count = stress_feeder_count + 1;
        end
    end

    task automatic stress_send_rx(input logic long_cp, input integer test_index);
        integer k, base;
        begin
            send_byte(long_cp ? CMD_RX_LONG : CMD_RX_SHORT);
            base = test_index * (long_cp ? (LONG_CP + N) : (SHORT_CP + N));
            for (k=0; k<(long_cp ? (LONG_CP + N) : (SHORT_CP + N)); k=k+1) begin
                if (long_cp) begin
                    send_byte(rx_long_inputs[base+k][15:8]);
                    send_byte(rx_long_inputs[base+k][7:0]);
                end else begin
                    send_byte(rx_short_inputs[base+k][15:8]);
                    send_byte(rx_short_inputs[base+k][7:0]);
                end
            end
        end
    endtask

    task automatic stress_check_rx_pair;
        integer k;
        logic [7:0] b, expected_byte;
        logic [15:0] expected_word;
        begin
            for (k=0; k<48; k=k+1) begin
                recv_byte(b);
                if (k < 2*NUM_EXTRACTED_SC)
                    expected_word = rx_short_expected[
                        0*N + SC_START_BIN + (k>>1)
                    ];
                else
                    expected_word = rx_long_expected[
                        1*N + SC_START_BIN +
                        ((k-2*NUM_EXTRACTED_SC)>>1)
                    ];
                expected_byte = k[0] ? expected_word[7:0] : expected_word[15:8];
                if (b !== expected_byte) begin
                    $display("STRESS RX mismatch byte %0d", k);
                    errors = errors + 1;
                end
            end
        end
    endtask

    task automatic stress_send_tx(input logic long_cp, input integer test_index);
        integer k, base;
        begin
            send_byte(long_cp ? CMD_TX_LONG : CMD_TX_SHORT);
            base = test_index * 12;
            for (k=0; k<12; k=k+1) begin
                if (long_cp) begin
                    send_byte(tx_long_inputs[base+k][15:8]);
                    send_byte(tx_long_inputs[base+k][7:0]);
                end else begin
                    send_byte(tx_short_inputs[base+k][15:8]);
                    send_byte(tx_short_inputs[base+k][7:0]);
                end
            end
        end
    endtask

    task automatic stress_check_tx_pair;
        integer k, frame_byte, expected_index;
        integer last_cycle, boundary_gap;
        logic [7:0] b, expected_byte;
        logic [15:0] expected_word;
        begin
            last_cycle = -1;
            boundary_gap = -1;
            for (k=0; k<2*((SHORT_CP + N) + (LONG_CP + N)); k=k+1) begin
                recv_byte(b);
                if (k < 2*(SHORT_CP + N)) begin
                    frame_byte = k;
                    expected_index = frame_byte >> 1;
                    expected_word = tx_short_expected[expected_index];
                end else begin
                    frame_byte = k - 2*(SHORT_CP + N);
                    expected_index = (LONG_CP + N) + (frame_byte >> 1);
                    expected_word = tx_long_expected[expected_index];
                end
                expected_byte = frame_byte[0]
                    ? expected_word[7:0] : expected_word[15:8];
                if (b !== expected_byte) begin
                    $display("STRESS TX mismatch byte %0d", k);
                    errors = errors + 1;
                end
                if (k == 2*(SHORT_CP + N))
                    boundary_gap = cycle_count - last_cycle;
                last_cycle = cycle_count;
            end
            $display("STRESS TX boundary_gap=%0d expected_pacing=%0d",
                boundary_gap, TEST_TX_BYTE_INTERVAL);
        end
    endtask
`endif

`ifdef BUTTERFOLD_SCHEDULED
    integer scheduled_accept_cycle [0:7];
    integer scheduled_input_done_cycle [0:7];
    logic [7:0] scheduled_accept_command [0:7];
    integer scheduled_accept_count;
    integer scheduled_input_done_count;
    always @(posedge clk) begin
        if (rst_n && (dut.ext_state == 0) && din_valid_i && din_ready_o &&
            ((din == CMD_RX_SHORT) || (din == CMD_RX_LONG) ||
             (din == CMD_TX_SHORT) || (din == CMD_TX_LONG)) &&
            scheduled_accept_count < 8) begin
            scheduled_accept_cycle[scheduled_accept_count] = cycle_count;
            scheduled_accept_command[scheduled_accept_count] = din;
            scheduled_accept_count = scheduled_accept_count + 1;
        end
        if (rst_n && dut.job_push && scheduled_input_done_count < 8) begin
            scheduled_input_done_cycle[scheduled_input_done_count] = cycle_count;
            scheduled_input_done_count = scheduled_input_done_count + 1;
        end
    end
`endif

    initial begin
        clk=1'b0; rst_n=1'b0; din=8'h00; din_valid_i=1'b0;
        errors=0; cycle_count=0;

        $readmemh("golden/vectors/two_point_commands.hex", two_point_commands);
        $readmemh("golden/vectors/two_point_inputs.hex", two_point_inputs);
        $readmemh("golden/vectors/two_point_expected.hex", two_point_expected);
        $readmemh("golden/vectors/fft3_inputs.hex", fft3_inputs);
        $readmemh("golden/vectors/fft3_expected.hex", fft3_expected);
        $readmemh("golden/vectors/dft12_inputs.hex", dft12_inputs);
        $readmemh("golden/vectors/dft12_expected.hex", dft12_expected);
        $readmemh("golden/vectors/fft64_inputs.hex", fft64_inputs);
        $readmemh("golden/vectors/fft64_expected.hex", fft64_expected);
        $readmemh("golden/vectors/ifft64_inputs.hex", ifft64_inputs);
        $readmemh("golden/vectors/ifft64_expected.hex", ifft64_expected);
        $readmemh("golden/vectors/ofdm_rx_normal_cp_inputs.hex", rx_short_inputs);
        $readmemh("golden/vectors/ofdm_rx_extended_cp_inputs.hex", rx_long_inputs);
        $readmemh("golden/vectors/ofdm_rx_normal_cp_expected.hex", rx_short_expected);
        $readmemh("golden/vectors/ofdm_rx_extended_cp_expected.hex", rx_long_expected);
        $readmemh("golden/vectors/ofdm_tx_normal_cp_inputs.hex", tx_short_inputs);
        $readmemh("golden/vectors/ofdm_tx_extended_cp_inputs.hex", tx_long_inputs);
        $readmemh("golden/vectors/ofdm_tx_normal_cp_expected.hex", tx_short_expected);
        $readmemh("golden/vectors/ofdm_tx_extended_cp_expected.hex", tx_long_expected);

        repeat(6) @(posedge clk);
        rst_n=1'b1;
        repeat(3) @(posedge clk);

        $display("============================================================");
        $display("ButterFold FINAL-PIN regression");
        $display("Only din/din_valid/din_ready and dout/dout_valid are used.");
        $display("============================================================");

        run_debug_protocol();

`ifdef BUTTERFOLD_SCHEDULED
        scheduled_accept_count = 0;
        scheduled_input_done_count = 0;
        run_rx(CMD_RX_SHORT,1'b0);
        run_rx(CMD_RX_LONG,1'b1);
        run_tx(CMD_TX_SHORT,1'b0);
        run_tx(CMD_TX_LONG,1'b1);
        run_rx(CMD_RX_SHORT,1'b0);
        run_rx(CMD_RX_LONG,1'b1);
        run_tx(CMD_TX_SHORT,1'b0);
        run_tx(CMD_TX_LONG,1'b1);
        for (integer si=1; si<8; si=si+1) begin
            $display("SCHEDULED command=%02h interval=%0d post_input_gap=%0d cycles",
                scheduled_accept_command[si-1],
                scheduled_accept_cycle[si]-scheduled_accept_cycle[si-1],
                scheduled_accept_cycle[si]-scheduled_input_done_cycle[si-1]);
            case (scheduled_accept_command[si-1])
              CMD_RX_SHORT: if ((scheduled_accept_cycle[si]-scheduled_accept_cycle[si-1]) !=
                                  ((TEST_TX_BYTE_INTERVAL==16) ? EXPECTED_RX_SHORT_PACED : EXPECTED_RX_SHORT_FAST)) begin
                  $display("SCHEDULED RX short acceptance mismatch"); errors=errors+1; end
              CMD_RX_LONG: if ((scheduled_accept_cycle[si]-scheduled_accept_cycle[si-1]) !=
                                 ((TEST_TX_BYTE_INTERVAL==16) ? EXPECTED_RX_LONG_PACED : EXPECTED_RX_LONG_FAST)) begin
                  $display("SCHEDULED RX long acceptance mismatch"); errors=errors+1; end
              CMD_TX_SHORT: if ((scheduled_accept_cycle[si]-scheduled_accept_cycle[si-1]) !=
                                  ((TEST_TX_BYTE_INTERVAL==16) ? EXPECTED_TX_SHORT_PACED : EXPECTED_TX_SHORT_FAST)) begin
                  $display("SCHEDULED TX short acceptance mismatch"); errors=errors+1; end
              CMD_TX_LONG: if ((scheduled_accept_cycle[si]-scheduled_accept_cycle[si-1]) !=
                                 ((TEST_TX_BYTE_INTERVAL==16) ? EXPECTED_TX_LONG_PACED : EXPECTED_TX_LONG_FAST)) begin
                  $display("SCHEDULED TX long acceptance mismatch"); errors=errors+1; end
              default: begin end
            endcase
        end
`elsif BUTTERFOLD_STRESS
        stress_feeder_count = 0;
        fork
            begin
                stress_send_rx(1'b0, 0);
                stress_send_rx(1'b1, 1);
            end
            stress_check_rx_pair();
        join
        $display("STRESS RX feeder_II=%0d cycles", stress_feeder_cycle[1]-stress_feeder_cycle[0]);
        wait (!dut.core_ofdm_active && !dut.drain_active);
        repeat (4) @(posedge clk);
        fork
            begin
                stress_send_tx(1'b0, 0);
                stress_send_tx(1'b1, 1);
            end
            stress_check_tx_pair();
        join
        $display("STRESS TX feeder_II=%0d cycles", stress_feeder_cycle[3]-stress_feeder_cycle[2]);
`else
        run_two_point(0); // FFT2
        run_two_point(1); // IFFT2
        run_fft3();
        run_block_standalone(CMD_DFT12,12,0,0);
        run_block_standalone(CMD_FFT64,N,0,0);
        run_block_standalone(CMD_IFFT64,N,0,0);
        run_rx(CMD_RX_SHORT,1'b0);
        run_rx(CMD_RX_LONG,1'b1);
        run_tx(CMD_TX_SHORT,1'b0);
        run_tx(CMD_TX_LONG,1'b1);
`endif

        $display("============================================================");
        if (errors==0)
            $display("FINAL-PIN OVERALL RESULT: PASS");
        else
            $display("FINAL-PIN OVERALL RESULT: FAIL (%0d errors)",errors);
        $display("============================================================");
        $finish;
    end

endmodule

`default_nettype wire
