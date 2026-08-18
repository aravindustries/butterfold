// SystemVerilog Universal Shift Register
// Supports 4 operational modes controlled by select lines (mode):
//   2'b00 : Hold (No change)
//   2'b01 : Shift Right (Serial In Right -> MSB)
//   2'b10 : Shift Left  (Serial In Left -> LSB)
//   2'b11 : Parallel Load

module universal_shift_register #(
    parameter int DATA_WIDTH = 8
) (
    input  wire                   clk,       // Clock signal
    input  wire                   rst_n,     // Active-low asynchronous reset
    input  wire [1:0]             mode,      // Mode select [1:0]
    input  wire                   s_in_left, // Serial input for shifting left (enters LSB)
    input  wire                   s_in_right,// Serial input for shifting right (enters MSB)
    input  wire [DATA_WIDTH-1:0]  d_in,      // Parallel data input
    output logic [DATA_WIDTH-1:0] q_out      // Parallel data output
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_out <= '0;
        end else begin
            case (mode)
                2'b00: begin
                    // Hold current state
                    q_out <= q_out;
                end
                2'b01: begin
                    // Shift Right: serial bit enters MSB, content shifts down
                    q_out <= {s_in_right, q_out[DATA_WIDTH-1:1]};
                end
                2'b10: begin
                    // Shift Left: serial bit enters LSB, content shifts up
                    q_out <= {q_out[DATA_WIDTH-2:0], s_in_left};
                end
                2'b11: begin
                    // Parallel Load
                    q_out <= d_in;
                end
                default: begin
                    q_out <= q_out;
                end
            endcase
        end
    end

endmodule
