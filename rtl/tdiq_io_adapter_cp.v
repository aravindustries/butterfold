// tdiq_io_adapter_cp - ports from butterfold_module_io.md (TDIQ I/O ADAPTER WITH CP)
// Synchronous FSM for RX CP-removal path
`default_nettype none
module tdiq_io_adapter_cp (
    input  wire rst_n,
    input  wire clk,
    input  wire [7:0] tdiq_in_data,
    input  wire tdiq_in_valid,
    output wire tdiq_in_ready,
    output wire [7:0] tdiq_out_data,
    output wire tdiq_out_valid,
    input  wire tdiq_out_ready,
    input  wire cp_start,
    input  wire cp_insert,
    input  wire [3:0] cp_len,
    output wire [15:0] rx_symbol_data,
    output wire rx_symbol_valid,
    input  wire rx_symbol_ready,
    output wire rx_symbol_last,
    output wire [6:0] tx_symbol_rd_addr,
    output wire tx_symbol_rd_req,
    input  wire [15:0] tx_symbol_rd_data,
    input  wire tx_symbol_rd_valid,
    output wire busy,
    output wire done,
    output wire cp_error,
    output wire sample_count_error,
    output wire iq_alignment_error
);

    reg [7:0] scount;
    reg active;
    reg have_i;
    reg [7:0] i_data;
    reg [15:0] internal_rx_symbol_data;
    reg internal_rx_symbol_valid;
    reg internal_rx_symbol_last;
    reg internal_busy;
    reg internal_done;

    assign tdiq_in_ready = active;
    assign tdiq_out_data = 8'b0;
    assign tdiq_out_valid = 1'b0;
    assign rx_symbol_data = internal_rx_symbol_data;
    assign rx_symbol_valid = internal_rx_symbol_valid;
    assign rx_symbol_last = internal_rx_symbol_last;
    assign tx_symbol_rd_addr = 7'b0;
    assign tx_symbol_rd_req = 1'b0;
    assign busy = internal_busy;
    assign done = internal_done;
    assign cp_error = 1'b0;
    assign sample_count_error = 1'b0;
    assign iq_alignment_error = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scount <= 8'b0;
            active <= 1'b0;
            have_i <= 1'b0;
            i_data <= 8'b0;
            internal_rx_symbol_data <= 16'b0;
            internal_rx_symbol_valid <= 1'b0;
            internal_rx_symbol_last <= 1'b0;
            internal_busy <= 1'b0;
            internal_done <= 1'b0;
        end else begin
            internal_rx_symbol_valid <= 1'b0;
            internal_rx_symbol_last <= 1'b0;
            internal_done <= 1'b0;

            if (cp_start && !cp_insert && !active) begin
                active <= 1'b1;
                internal_busy <= 1'b1;
                scount <= 8'b0;
            end else if (active && tdiq_in_valid && tdiq_in_ready) begin
                if (!have_i) begin
                    i_data <= tdiq_in_data;
                    have_i <= 1'b1;
                end else begin
                    if (scount >= cp_len) begin
                        internal_rx_symbol_data <= {i_data, tdiq_in_data};
                        internal_rx_symbol_valid <= 1'b1;
                        if (scount == 136) begin
                            internal_rx_symbol_last <= 1'b1;
                            internal_done <= 1'b1;
                            active <= 1'b0;
                            internal_busy <= 1'b0;
                        end
                    end
                    scount <= scount + 1;
                    have_i <= 1'b0;
                end
            end
        end
    end

endmodule
`default_nettype wire
