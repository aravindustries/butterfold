`default_nettype none
module complex_mul (
    input  wire [7:0] a_re,
    input  wire [7:0] a_im,
    input  wire [7:0] b_re,
    input  wire [7:0] b_im,
    output wire [7:0] p_re,
    output wire [7:0] p_im
);

    // Intermediate signals for computation
    wire signed [17:0] accr;
    wire signed [17:0] acci;
    wire signed [8:0] rounded_re;
    wire signed [8:0] rounded_im;

    // Complex Multiply
    assign accr = $signed(a_re) * $signed(b_re) - $signed(a_im) * $signed(b_im);
    assign acci = $signed(a_re) * $signed(b_im) + $signed(a_im) * $signed(b_re);

    // Rounding
    assign rounded_re = (accr + 64) >>> 7;
    assign rounded_im = (acci + 64) >>> 7;

    // Saturation function
    function [7:0] sat8;
        input signed [8:0] in;
        begin
            if (in > 127) begin
                sat8 = 127;
            end else if (in < -128) begin
                sat8 = -128;
            end else begin
                sat8 = in[7:0];
            end
        end
    endfunction

    // Assign output with saturation
    assign p_re = sat8(rounded_re);
    assign p_im = sat8(rounded_im);

endmodule
`default_nettype wire
