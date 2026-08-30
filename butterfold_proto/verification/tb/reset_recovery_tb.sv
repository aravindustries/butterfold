`timescale 1ns/1ps
`default_nettype none

module reset_recovery_tb;
    logic clk=0, rst_n=0;
    logic [7:0] din=0;
    logic din_valid_i=0;
    wire stream_status_o;
    wire [7:0] dout;
    integer errors=0;
    integer k;
    logic [7:0] expected [0:9];

    butterfold_top dut(.*);
    always #5 clk=~clk;

    task automatic apply_reset;
        begin
            @(negedge clk); din_valid_i=0; din=0; rst_n=0;
            repeat(3) @(posedge clk);
            @(negedge clk); rst_n=1; repeat(3) @(posedge clk);
            if (!dut.stream_input_phase || !stream_status_o) begin
                $display("RESET stream_status not idle-ready"); errors=errors+1;
            end
            if (dut.top_state !== 0 || dut.debug_mode !== 0) begin
                $display("RESET ownership/state not idle"); errors=errors+1;
            end
        end
    endtask
    task automatic send(input logic [7:0] b);
        begin
            @(negedge clk); din=b; din_valid_i=1;
            do @(posedge clk); while(!stream_status_o);
            @(negedge clk); din_valid_i=0; din=0;
        end
    endtask
    task automatic check_fft2;
        begin
            send(8'h40); send(8'h40); send(8'he0); send(8'h20); send(8'h10);
            for(k=0;k<10;k=k+1) begin
                do @(posedge clk); while(!stream_status_o);
                if(dout!==expected[k]) begin
                    $display("RESET FFT2 mismatch byte %0d got=%02x exp=%02x",k,dout,expected[k]);
                    errors=errors+1;
                end
            end
        end
    endtask

    initial begin
        expected[0]=8'h00; expected[1]=8'h00; expected[2]=8'h60;
        expected[3]=8'hff; expected[4]=8'hf0; expected[5]=8'h01;
        expected[6]=8'h00; expected[7]=8'h20; expected[8]=8'hff; expected[9]=8'hd0;

        apply_reset(); check_fft2();
        apply_reset(); check_fft2();
        send(8'h41); apply_reset(); check_fft2();
        send(8'h41); send(8'h01); send(8'h02); send(8'h03);
        apply_reset(); check_fft2();

        send(8'h46); repeat(12) send(8'h00);
        apply_reset(); check_fft2();

        send(8'h41); repeat(128) send(8'h00);
        wait(dut.u_transform_scheduler_core.mod_active);
        apply_reset(); check_fft2();

        send(8'h48); repeat(24) send(8'h00);
        wait(stream_status_o);
        apply_reset(); check_fft2();

        send(8'h4d); send(8'h55); send(8'haa);
        apply_reset(); check_fft2();
        send(8'h4c); send(8'h55);
        apply_reset(); check_fft2();

        send(8'h4a); send(8'ha5); apply_reset(); check_fft2();
        send(8'h4b); wait(stream_status_o); apply_reset(); check_fft2();

        if(errors==0) $display("RESET-RECOVERY RESULT: PASS");
        else $display("RESET-RECOVERY RESULT: FAIL errors=%0d",errors);
        $finish;
    end
endmodule

`default_nettype wire
