module subcarrier_map_extract (
    input wire rst_n,
    input wire clk,
    input wire start,
    input wire map_not_extract,
    input wire [6:0] first_subcarrier,
    output reg busy,
    output reg done,
    output reg config_error,
    input wire [15:0] in_data,
    input wire in_valid,
    output reg in_ready,
    input wire in_last,
    output reg [15:0] out_data,
    output reg out_valid,
    input wire out_ready,
    output reg out_last,
    output reg [6:0] mem_addr,
    output reg mem_write,
    output reg [15:0] mem_wdata,
    input wire [15:0] mem_rdata,
    input wire mem_rvalid
);

    // Internal reg definitions
    reg [3:0] state; // state machine
    reg [3:0] load_counter; // counter for loading samples
    reg [6:0] emit_counter; // counter for emitting data
    reg [15:0] buffer[11:0]; // buffer for the subcarrier samples

    localparam IDLE = 0,
               LOAD = 1,
               EMIT = 2,
               DONE = 3;

    // Tie memory interface to zero for mapping mode
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr <= 7'b0;
            mem_write <= 1'b0;
            mem_wdata <= 16'b0;
        end else begin
            mem_addr <= 7'b0;
            mem_write <= 1'b0;
            mem_wdata <= 16'b0;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_counter <= 4'b0;
            emit_counter <= 7'b0;
            busy <= 1'b0;
            done <= 1'b0;
            config_error <= 1'b0;
            in_ready <= 1'b0;
            out_data <= 16'b0;
            out_valid <= 1'b0;
            out_last <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    config_error <= 1'b0;
                    if (start) begin
                        if (map_not_extract) begin
                            // Check configuration
                            if (first_subcarrier + 12 <= 128) begin
                                state <= LOAD;
                                busy <= 1'b1;
                            end else begin
                                config_error <= 1'b1;
                                state <= DONE;
                            end
                        end
                    end
                end
                LOAD: begin
                    in_ready <= 1'b1;
                    if (in_valid && in_ready) begin
                        buffer[load_counter] <= in_data;
                        load_counter <= load_counter + 1;
                        if (load_counter == 11 || in_last) begin
                            state <= EMIT;
                            in_ready <= 1'b0;
                        end
                    end
                end
                EMIT: begin
                    out_valid <= 1'b1;
                    out_data <= 16'b0;
                    if (emit_counter >= first_subcarrier &&
                        emit_counter < first_subcarrier + 12) begin
                        out_data <= buffer[emit_counter - first_subcarrier];
                    end
                    emit_counter <= emit_counter + 1;
                    if (emit_counter == 127) begin
                        out_last <= 1'b1;
                        state <= DONE;
                    end else begin
                        out_last <= 1'b0;
                    end
                end
                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule