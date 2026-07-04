`default_nettype none
module fdiq_io_adapter (
    input  wire rst_n,
    input  wire clk,
    input  wire [7:0] fdiq_in_data,
    input  wire fdiq_in_valid,
    output reg fdiq_in_ready,
    output reg [7:0] fdiq_out_data,
    output reg fdiq_out_valid,
    input  wire fdiq_out_ready,
    output reg [15:0] fd_in_data,
    output reg fd_in_valid,
    input  wire fd_in_ready,
    output reg fd_in_last,
    input  wire [15:0] fd_out_data,
    input  wire fd_out_valid,
    output reg fd_out_ready,
    input  wire fd_out_last,
    input  wire start,
    input  wire direction,
    output reg busy,
    output reg done,
    output reg iq_alignment_error
);

    // Internal states for FSM
    reg [3:0] sample_count;
    reg [7:0] I_byte;
    reg expect_I;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fdiq_in_ready <= 1'b0;
            fdiq_out_data <= 8'b0;
            fdiq_out_valid <= 1'b0;
            fd_in_data <= 16'b0;
            fd_in_valid <= 1'b0;
            fd_in_last <= 1'b0;
            fd_out_ready <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            iq_alignment_error <= 1'b0;
            sample_count <= 4'b0;
            I_byte <= 8'b0;
            expect_I <= 1'b1;
        end else begin
            // Default outputs
            fd_in_valid <= 1'b0;
            fd_in_last <= 1'b0;
            fdiq_out_valid <= 1'b0;
            done <= 1'b0;
            iq_alignment_error <= 1'b0;
            
            if (start && direction) begin
                busy <= 1'b1;
                sample_count <= 4'b0;
                expect_I <= 1'b1;
                fdiq_in_ready <= 1'b1;
            end 

            if (busy) begin
                fdiq_in_ready <= 1'b1;
                if (fdiq_in_valid && fdiq_in_ready) begin
                    if (expect_I) begin
                        I_byte <= fdiq_in_data;
                        expect_I <= 1'b0;
                    end else begin
                        fd_in_data <= {I_byte, fdiq_in_data};
                        fd_in_valid <= 1'b1;
                        sample_count <= sample_count + 1;
                        expect_I <= 1'b1;
                        if (sample_count == 4'b1011) begin
                            fd_in_last <= 1'b1;
                            busy <= 1'b0;
                            done <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
`default_nettype wire
