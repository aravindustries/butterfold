`default_nettype none
module twiddle_source (
    input  wire rst_n,
    input  wire clk,
    input  wire tw_req,
    input  wire [6:0] tw_addr,
    input  wire tw_conjugate,
    output reg [7:0] tw_re,
    output reg [7:0] tw_im,
    output reg tw_valid
);

    reg signed [7:0] base_re, base_im;

    // Combinational logic to set base values for twiddle factors
    always @* begin
        case (tw_addr)
            7'd0:  {base_re, base_im} = 16'sb01111111_00000000; // 127, 0
            7'd1:  {base_re, base_im} = 16'sb01101110_11000001; // 110, -63
            7'd2:  {base_re, base_im} = 16'sb01000000_10010010; // 64, -110
            7'd3:  {base_re, base_im} = 16'sb00000000_10000001; // 0, -127
            7'd4:  {base_re, base_im} = 16'sb11000001_10010010; // -63, -110
            7'd5:  {base_re, base_im} = 16'sb10010010_11000000; // -110, -64
            7'd6:  {base_re, base_im} = 16'sb10000001_00000000; // -127, 0
            7'd7:  {base_re, base_im} = 16'sb10010010_00111111; // -110, 63
            7'd8:  {base_re, base_im} = 16'sb11000000_01101110; // -64, 110
            7'd9:  {base_re, base_im} = 16'sb00000000_01111111; // 0, 127
            7'd10: {base_re, base_im} = 16'sb00111111_01101110; // 63, 110
            7'd11: {base_re, base_im} = 16'sb01101110_01000000; // 110, 64
            default: {base_re, base_im} = 16'sb00000000_00000000; // 0, 0
        endcase
    end

    // Sequential logic with clock and reset handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tw_re <= 8'b0;
            tw_im <= 8'b0;
            tw_valid <= 1'b0;
        end else begin
            tw_re <= base_re;
            tw_im <= tw_conjugate ? (~base_im + 8'd1) : base_im;
            tw_valid <= tw_req;
        end
    end

endmodule
`default_nettype wire
