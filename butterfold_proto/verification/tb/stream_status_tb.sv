`timescale 1ns/1ps
`default_nettype none

// Focused 22-pin stream_status_o protocol test.
module stream_status_tb;
    logic clk=0, rst_n=0;
    logic [7:0] din=0;
    logic din_valid_i=0;
    wire stream_status_o;
    wire [7:0] dout;
    integer errors=0;
    integer k;
    integer output_bytes;
    logic [7:0] b;

    butterfold_top dut(.*);
    always #5 clk=~clk;

    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.din_ready_int && dut.dout_valid_int) begin
                $display("FAIL simultaneous ready/valid t=%0t", $time);
                errors = errors + 1;
            end
            if (dut.stream_input_phase) begin
                if (stream_status_o !== dut.din_ready_int) begin
                    $display("FAIL input-phase mux t=%0t", $time);
                    errors = errors + 1;
                end
            end else if (stream_status_o !== dut.dout_valid_int) begin
                $display("FAIL output-phase mux t=%0t", $time);
                errors = errors + 1;
            end
        end
    end

    task automatic send(input logic [7:0] value);
        begin
            @(negedge clk); din=value; din_valid_i=1;
            do @(posedge clk); while (!stream_status_o);
            if (!dut.stream_input_phase) begin
                $display("FAIL send while not input-phase t=%0t", $time);
                errors = errors + 1;
            end
            @(negedge clk); din_valid_i=0; din=0;
        end
    endtask

    task automatic recv(output logic [7:0] value);
        begin
            do @(posedge clk); while (!stream_status_o);
            if (dut.stream_input_phase) begin
                $display("FAIL recv while input-phase t=%0t", $time);
                errors = errors + 1;
            end
            value = dout;
        end
    endtask

    task automatic wait_ready;
        integer n;
        begin
            n = 0;
            while (!(dut.stream_input_phase && stream_status_o)) begin
                @(posedge clk);
                n = n + 1;
                if (n > 200000) begin
                    $display("FAIL timeout waiting for input-ready");
                    errors = errors + 1;
                    disable wait_ready;
                end
            end
        end
    endtask

    initial begin
        @(negedge clk); rst_n=0; din_valid_i=0; din=0;
        repeat (4) @(posedge clk);
        @(negedge clk); rst_n=1;
        repeat (3) @(posedge clk);
        if (!stream_status_o || !dut.stream_input_phase) begin
            $display("FAIL idle not ready"); errors=errors+1;
        end

        // ECHO: command + payload, one output byte, return to ready.
        send(8'h4a); send(8'ha5);
        recv(b);
        if (b !== 8'ha5) begin $display("FAIL echo %02h", b); errors=errors+1; end
        wait_ready();

        // MAGIC: four output bytes then ready.
        send(8'h4b);
        recv(b); if (b!==8'h42) errors=errors+1;
        recv(b); if (b!==8'h46) errors=errors+1;
        recv(b); if (b!==8'h4c) errors=errors+1;
        recv(b); if (b!==8'h44) errors=errors+1;
        wait_ready();

        // FFT2: 1 command + 4 input bytes, 10 output bytes.
        send(8'h40); send(8'h40); send(8'he0); send(8'h20); send(8'h10);
        output_bytes=0;
        for (k=0;k<10;k=k+1) begin
            recv(b);
            output_bytes=output_bytes+1;
        end
        if (output_bytes!==10) errors=errors+1;
        wait_ready();

        // Back-to-back ECHO then MAGIC.
        send(8'h4a); send(8'h11); recv(b);
        send(8'h4b);
        recv(b); recv(b); recv(b); recv(b);
        wait_ready();

        // Reset during MAGIC output.
        send(8'h4b);
        wait(stream_status_o);
        @(negedge clk); rst_n=0; din_valid_i=0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n=1;
        repeat (3) @(posedge clk);
        if (!dut.stream_input_phase || !stream_status_o) begin
            $display("FAIL reset mid-output not idle-ready"); errors=errors+1;
        end
        send(8'h4a); send(8'h5a); recv(b);
        if (b!==8'h5a) begin $display("FAIL post-reset echo"); errors=errors+1; end

        if (errors==0) $display("STREAM-STATUS RESULT: PASS");
        else $display("STREAM-STATUS RESULT: FAIL errors=%0d", errors);
        $finish;
    end
endmodule

`default_nettype wire
