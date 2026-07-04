// unified_mixed_radix_core - RTL implementation
`default_nettype none
module unified_mixed_radix_core (
    input  wire rst_n,
    input  wire clk,
    input  wire uop_valid,
    output wire uop_ready,
    input  wire [1:0] uop_radix,
    input  wire uop_inverse,
    input  wire [2:0] uop_scale_shift,
    input  wire uop_last,
    input  wire [6:0] src_addr_0,
    input  wire [6:0] src_addr_1,
    input  wire [6:0] src_addr_2,
    input  wire [6:0] dst_addr_0,
    input  wire [6:0] dst_addr_1,
    input  wire [6:0] dst_addr_2,
    input  wire [7:0] twiddle_re,
    input  wire [7:0] twiddle_im,
    input  wire twiddle_valid,
    input  wire [6:0] load_addr,
    input  wire [15:0] load_data,
    input  wire load_valid,
    output wire load_ready,
    input  wire [6:0] read_addr,
    input  wire read_req,
    output wire [15:0] read_data,
    output wire read_valid,
    output wire uop_done,
    output wire overflow,
    output wire saturation_occurred
);

    // Memories declaration
    reg signed [15:0] mre[0:127], mim[0:127];
    
    // Intermediate variables for signed calculations
    reg signed [15:0] topr, topi, botr, boti;
    reg signed [31:0] tr, ti;
    reg uop_done_r, read_valid_r;

    // Assignments
    assign load_ready = 1'b1;
    assign uop_ready = 1'b1;
    assign read_data = {narrow(mre[read_addr]), narrow(mim[read_addr])};
    assign read_valid = read_valid_r;
    assign uop_done = uop_done_r;
    assign overflow = 1'b0;
    assign saturation_occurred = 1'b0;

    // Saturation functions
    function signed [15:0] sat16(input signed [31:0] x);
        begin
            if (x > 32767)
                sat16 = 16'sd32767;
            else if (x < -32768)
                sat16 = -16'sd32768;
            else
                sat16 = x[15:0];
        end
    endfunction

    function signed [7:0] narrow(input signed [15:0] v);
        reg signed [31:0] r;
        begin
            r = (v + 8) >>> 4;
            if (r > 127)
                narrow = 8'sd127;
            else if (r < -128)
                narrow = -8'sd128;
            else
                narrow = r[7:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uop_done_r <= 1'b0;
            read_valid_r <= 1'b0;
        end else begin
            uop_done_r <= 1'b0;
            read_valid_r <= 1'b0;
            
            if (load_valid && load_ready) begin
                mre[load_addr] <= $signed(load_data[15:8]) <<< 4;
                mim[load_addr] <= $signed(load_data[7:0])  <<< 4;
            end

            if (uop_valid && uop_ready) begin
                topr = mre[src_addr_0];
                topi = mim[src_addr_0];
                botr = mre[src_addr_1];
                boti = mim[src_addr_1];

                tr = ($signed(botr)*$signed(twiddle_re) - $signed(boti)*$signed(twiddle_im) + 64) >>> 7;
                ti = ($signed(botr)*$signed(twiddle_im) + $signed(boti)*$signed(twiddle_re) + 64) >>> 7;

                mre[dst_addr_0] <= sat16(($signed(topr) + tr + 1) >>> 1);
                mim[dst_addr_0] <= sat16(($signed(topi) + ti + 1) >>> 1);
                mre[dst_addr_1] <= sat16(($signed(topr) - tr + 1) >>> 1);
                mim[dst_addr_1] <= sat16(($signed(topi) - ti + 1) >>> 1);

                uop_done_r <= 1'b1;
            end

            if (read_req) begin
                read_valid_r <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire
