`default_nettype none
module scheduler_addr_control (
    input  wire rst_n,
    input  wire clk,
    input  wire cmd_valid,
    output reg  cmd_ready,
    input  wire [2:0] cmd_op,
    input  wire long_cp,
    output reg  uop_valid,
    input  wire uop_ready,
    output reg [1:0] uop_radix,
    output reg  uop_inverse,
    output reg [2:0] uop_scale_shift,
    output reg  uop_last,
    output reg [6:0] src_addr_0,
    output reg [6:0] src_addr_1,
    output reg [6:0] src_addr_2,
    output reg [6:0] dst_addr_0,
    output reg [6:0] dst_addr_1,
    output reg [6:0] dst_addr_2,
    output wire tw_req,
    output reg [6:0] tw_addr,
    output reg tw_conjugate,
    input  wire tw_valid,
    output wire map_start,
    output wire map_direction,
    output wire [6:0] first_subcarrier,
    input  wire map_done,
    output wire cp_start,
    output wire cp_insert,
    output wire [3:0] cp_len,
    input  wire cp_done,
    output wire input_bank_select,
    output wire output_bank_select,
    output wire busy,
    output wire done,
    output wire error,
    output reg [15:0] cycle_count
);

    reg [2:0] stage;
    reg [6:0] grp;
    reg [6:0] kk;
    reg [8:0] cnt;
    reg active;

    wire [6:0] half = 7'd1 << stage;
    wire [7:0] m = 8'd1 << (stage + 1);

    assign first_subcarrier = 7'd58;
    assign cp_len = 4'd9;
    assign map_start = 1'b0;
    assign map_direction = 1'b0;
    assign cp_start = 1'b0;
    assign cp_insert = 1'b0;
    assign input_bank_select = 1'b0;
    assign output_bank_select = 1'b0;
    assign busy = active;
    assign done = (cnt == 9'd447);
    assign error = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage <= 3'd0;
            grp <= 7'd0;
            kk <= 7'd0;
            cnt <= 9'd0;
            active <= 1'b0;
            cmd_ready <= 1'b1;
        end else begin
            if (cmd_valid && cmd_ready && cmd_op == 3'b010) begin
                active <= 1'b1;
                cmd_ready <= 1'b0;
            end
            
            if (active && uop_ready) begin
                if (kk == half - 1) begin
                    kk <= 7'd0;
                    if (grp + m >= 128) begin
                        grp <= 7'd0;
                        if (stage == 3'd6) begin
                            active <= 1'b0;
                            stage <= 3'd0;
                        end else begin
                            stage <= stage + 1;
                        end
                    end else begin
                        grp <= grp + m;
                    end
                end else begin
                    kk <= kk + 1;
                end
                
                cnt <= cnt + 1;
            end
        end
    end

    always @(*) begin
        uop_valid = active;
        src_addr_0 = grp + kk;
        src_addr_1 = grp + half + kk;
        dst_addr_0 = grp + kk;
        dst_addr_1 = grp + half + kk;
        tw_addr = kk << (6 - stage);
        uop_inverse = 1'b1;
        uop_radix = 2'b10;
        uop_scale_shift = 3'b001;
        uop_last = (cnt == 9'd447);
        tw_conjugate = 1'b1;
    end

endmodule
`default_nettype wire
