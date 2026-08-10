`timescale 1ns/1ps
`default_nettype none

// Deterministic physical-half-word FFT controller.  The SRAM port performs
// four operand reads in phases 0..3 and four pending-result writes in phases
// 4..7.  Request and response counts are independent so delayed synchronous
// responses cannot be reclassified when result ownership advances.
module fft128_modulo_controller (
    input logic clk, input logic rst_n,
    input logic start_i, input logic inverse_i,
    input logic ofdm_i, input logic tx_i,
    output logic active_o, output logic done_o,
    output logic inverse_o, output logic ofdm_o, output logic tx_o,

    output logic half_req_o, output logic half_write_o,
    output logic [7:0] half_addr_o, output logic [15:0] half_wdata_o,
    input logic half_ready_i, input logic [15:0] half_rdata_i,
    input logic half_rvalid_i,

    output logic issue_valid_o, input logic issue_ready_i,
    output logic signed [15:0] x0_i_o, x0_q_o, x1_i_o, x1_q_o,
    output logic signed [7:0] twiddle_re_o, twiddle_im_o,

    input logic result_valid_i, output logic result_ready_o,
    input logic signed [15:0] X0_i_i, X0_q_i, X1_i_i, X1_q_i,

    output logic diag_valid_o, input logic diag_ready_i,
    output logic signed [15:0] diag_X0_i_o, diag_X0_q_o,
    output logic signed [15:0] diag_X1_i_o, diag_X1_q_o,
    output logic [6:0] diag_addr0_o, diag_addr1_o,
    output logic diag_last_o
);
    localparam logic signed [7:0] UNITY_PROXY_RE = -8'sd128;
    localparam logic signed [7:0] UNITY_PROXY_IM = 8'sd0;

    typedef enum logic [1:0] {M_IDLE, M_RUN, M_DRAIN, M_DIAG} mstate_t;
    mstate_t state;
    logic [2:0] slot_phase;
    logic inverse_reg, ofdm_reg, tx_reg;
    assign inverse_o=inverse_reg; assign ofdm_o=ofdm_reg; assign tx_o=tx_reg;

    // Fetch context: the operation whose four half words are being read.
    logic [2:0] fetch_stage;
    logic [6:0] fetch_group;
    logic [5:0] fetch_j;
    logic [2:0] read_issue_count, read_return_count;
    logic fetch_operands_valid;
    logic fetch_issued;
    logic signed [15:0] fetch_x0_i, fetch_x0_q, fetch_x1_i, fetch_x1_q;

    // Result context advances only when an ordered butterfly result is
    // captured.  It is independent of the fetch context.
    logic [2:0] result_stage;
    logic [6:0] result_group;
    logic [5:0] result_j;

    // Exactly one result/address slot decouples arithmetic completion from
    // the four physical writes.
    logic pending_valid;
    logic signed [15:0] pending_X0_i, pending_X0_q;
    logic signed [15:0] pending_X1_i, pending_X1_q;
    logic [6:0] pending_addr0, pending_addr1;
    logic pending_stage_last, pending_transform_last;
    logic pending_diag;
    logic diag_due;
    logic pending_writes_done;

    logic [6:0] fetch_half_size, result_half_size;
    logic [7:0] fetch_group_size, result_group_size;
    logic [6:0] fetch_addr0, fetch_addr1;
    logic [6:0] result_addr0, result_addr1;
    logic [5:0] fetch_twiddle_index;
    logic signed [7:0] rom_re, rom_im;
    logic fetch_last_in_stage, result_last_in_stage;
    logic result_last_transform;
    logic read_fire, write_fire, issue_fire, result_fire;

    function automatic logic signed [7:0] negate8(input logic signed [7:0] v);
        negate8 = -v;
    endfunction
    function automatic logic signed [15:0] negate16(input logic signed [15:0] v);
        negate16 = -v;
    endfunction

    assign fetch_half_size = 7'd1 << fetch_stage;
    assign fetch_group_size = 8'd2 << fetch_stage;
    assign fetch_addr0 = fetch_group + fetch_j;
    assign fetch_addr1 = fetch_addr0 + fetch_half_size;
    assign fetch_twiddle_index = fetch_j << (6-fetch_stage);
    assign fetch_last_in_stage =
        (fetch_group + fetch_group_size >= 8'd128) &&
        (fetch_j == fetch_half_size-1'b1);

    assign result_half_size = 7'd1 << result_stage;
    assign result_group_size = 8'd2 << result_stage;
    assign result_addr0 = result_group + result_j;
    assign result_addr1 = result_addr0 + result_half_size;
    assign result_last_in_stage =
        (result_group + result_group_size >= 8'd128) &&
        (result_j == result_half_size-1'b1);
    assign result_last_transform = result_last_in_stage && result_stage==3'd6;

    fft128_twiddle_rom u_twiddle(.addr_i(fetch_twiddle_index),.re_o(rom_re),.im_o(rom_im));

    always @* begin
        x0_i_o = fetch_x0_i; x0_q_o = fetch_x0_q;
        x1_i_o = fetch_x1_i; x1_q_o = fetch_x1_q;
        if (fetch_twiddle_index == 0) begin
            x1_i_o = negate16(fetch_x1_i);
            x1_q_o = negate16(fetch_x1_q);
            twiddle_re_o = UNITY_PROXY_RE; twiddle_im_o = UNITY_PROXY_IM;
        end else if (inverse_reg && rom_im == 8'sh80) begin
            x1_i_o = negate16(fetch_x1_i);
            x1_q_o = negate16(fetch_x1_q);
            twiddle_re_o = rom_re; twiddle_im_o = rom_im;
        end else begin
            twiddle_re_o = rom_re;
            twiddle_im_o = inverse_reg ? negate8(rom_im) : rom_im;
        end
    end

    assign issue_valid_o = active_o && fetch_operands_valid;
    assign issue_fire = issue_valid_o && issue_ready_i;
    // A new result may replace a result whose fourth write commits on this
    // edge. This is the key one-entry-slot modulo handoff.
    assign result_ready_o = active_o && !diag_due && (state != M_DIAG) &&
        (!pending_valid || (ofdm_reg && (slot_phase==3'd7) &&
            pending_valid && half_ready_i));
    assign result_fire = result_valid_i && result_ready_o;

    always @* begin
        half_req_o = 1'b0; half_write_o = 1'b0;
        half_addr_o = 8'd0; half_wdata_o = 16'd0;
        if (active_o && state != M_DIAG && half_ready_i) begin
            if (slot_phase < 3'd4 && state == M_RUN && read_issue_count < 3'd4) begin
                half_req_o = 1'b1;
                case (read_issue_count[1:0])
                    2'd0: half_addr_o = {fetch_addr0,1'b0};
                    2'd1: half_addr_o = {fetch_addr0,1'b1};
                    2'd2: half_addr_o = {fetch_addr1,1'b0};
                    default: half_addr_o = {fetch_addr1,1'b1};
                endcase
            end else if (slot_phase >= 3'd4 && pending_valid && !pending_writes_done) begin
                half_req_o = 1'b1; half_write_o = 1'b1;
                case (slot_phase)
                    3'd4: begin half_addr_o={pending_addr0,1'b0}; half_wdata_o=pending_X0_i; end
                    3'd5: begin half_addr_o={pending_addr0,1'b1}; half_wdata_o=pending_X0_q; end
                    3'd6: begin half_addr_o={pending_addr1,1'b0}; half_wdata_o=pending_X1_i; end
                    default: begin half_addr_o={pending_addr1,1'b1}; half_wdata_o=pending_X1_q; end
                endcase
            end
        end
    end
    assign read_fire = half_req_o && !half_write_o && half_ready_i;
    assign write_fire = half_req_o && half_write_o && half_ready_i;

    assign diag_valid_o = diag_due;
    assign diag_X0_i_o=pending_X0_i; assign diag_X0_q_o=pending_X0_q;
    assign diag_X1_i_o=pending_X1_i; assign diag_X1_q_o=pending_X1_q;
    assign diag_addr0_o=pending_addr0; assign diag_addr1_o=pending_addr1;
    assign diag_last_o=pending_transform_last;

    task automatic advance_fetch;
        begin
            if (fetch_j == fetch_half_size-1'b1) begin
                fetch_j <= 6'd0;
                if (fetch_group + fetch_group_size >= 8'd128)
                    fetch_group <= 7'd0;
                else fetch_group <= fetch_group + fetch_group_size[6:0];
            end else fetch_j <= fetch_j + 1'b1;
        end
    endtask
    task automatic advance_result;
        begin
            if (result_j == result_half_size-1'b1) begin
                result_j <= 6'd0;
                if (result_group + result_group_size >= 8'd128)
                    result_group <= 7'd0;
                else result_group <= result_group + result_group_size[6:0];
            end else result_j <= result_j + 1'b1;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=M_IDLE; active_o<=1'b0; done_o<=1'b0; slot_phase<=3'd0;
            inverse_reg<=1'b0; ofdm_reg<=1'b0; tx_reg<=1'b0;
            fetch_stage<=0; fetch_group<=0; fetch_j<=0;
            result_stage<=0; result_group<=0; result_j<=0;
            read_issue_count<=0; read_return_count<=0; fetch_operands_valid<=0; fetch_issued<=0;
            fetch_x0_i<=0; fetch_x0_q<=0; fetch_x1_i<=0; fetch_x1_q<=0;
            pending_valid<=0; pending_writes_done<=0;
            pending_X0_i<=0; pending_X0_q<=0; pending_X1_i<=0; pending_X1_q<=0;
            pending_addr0<=0; pending_addr1<=0;
            pending_stage_last<=0; pending_transform_last<=0;
            pending_diag<=0;
            diag_due<=0;
        end else begin
            done_o <= 1'b0;
            if (start_i && !active_o) begin
                state<=M_RUN; active_o<=1'b1; slot_phase<=0;
                inverse_reg<=inverse_i; ofdm_reg<=ofdm_i; tx_reg<=tx_i;
                fetch_stage<=0; fetch_group<=0; fetch_j<=0;
                result_stage<=0; result_group<=0; result_j<=0;
                read_issue_count<=0; read_return_count<=0; fetch_operands_valid<=0; fetch_issued<=0;
                pending_valid<=0; pending_writes_done<=0;
                diag_due<=0;
            end else if (active_o) begin
                if (read_fire) read_issue_count <= read_issue_count + 1'b1;
                if (half_rvalid_i && read_return_count < 3'd4) begin
                    case (read_return_count[1:0])
                        2'd0: fetch_x0_i <= half_rdata_i;
                        2'd1: fetch_x0_q <= half_rdata_i;
                        2'd2: fetch_x1_i <= half_rdata_i;
                        default: fetch_x1_q <= half_rdata_i;
                    endcase
                    read_return_count <= read_return_count + 1'b1;
                    if (read_return_count == 2'd3)
                        fetch_operands_valid <= 1'b1;
                end
                if (issue_fire) begin fetch_operands_valid <= 1'b0; fetch_issued<=1'b1; end

                if (result_fire) begin
`ifdef BUTTERFOLD_PERF
                    if (result_last_in_stage)
                        $display("MOD PERF result-stage-last stage=%0d time=%0t",result_stage,$time);
`endif
                    pending_valid <= 1'b1; pending_writes_done <= 1'b0;
                    pending_X0_i <= (inverse_reg && result_stage==3'd6) ? ($signed(X0_i_i)>>>7) : X0_i_i;
                    pending_X0_q <= (inverse_reg && result_stage==3'd6) ? ($signed(X0_q_i)>>>7) : X0_q_i;
                    pending_X1_i <= (inverse_reg && result_stage==3'd6) ? ($signed(X1_i_i)>>>7) : X1_i_i;
                    pending_X1_q <= (inverse_reg && result_stage==3'd6) ? ($signed(X1_q_i)>>>7) : X1_q_i;
                    pending_addr0 <= result_addr0; pending_addr1 <= result_addr1;
                    pending_stage_last <= result_last_in_stage;
                    pending_transform_last <= result_last_transform;
                    pending_diag <= !ofdm_reg && (result_stage==3'd6);
                    // Results are strictly ordered.  Advance the result
                    // context at capture, including directly into the next
                    // stage.  The preceding stage's last result remains
                    // identified by the pending descriptor until writeback.
                    if (result_last_in_stage && !result_last_transform) begin
                        result_stage <= result_stage + 1'b1;
                        result_group <= 7'd0;
                        result_j <= 6'd0;
                    end else begin
                        advance_result();
                    end
                end

                if (write_fire && slot_phase==3'd7) begin
`ifdef BUTTERFOLD_PERF
                    if (pending_stage_last)
                        $display("MOD PERF write-stage-last stage=%0d transform=%0b diag=%0b time=%0t",
                            result_stage,pending_transform_last,pending_diag,$time);
`endif
                    pending_writes_done <= 1'b1;
                    if (!result_fire) pending_valid <= 1'b0;
                    if (pending_diag) begin
                        state<=M_DIAG; diag_due<=1'b1;
                    end else if (pending_transform_last) begin
                        active_o<=1'b0; state<=M_IDLE; done_o<=1'b1;
                    end
                end

                if (diag_due) begin
                    if (diag_valid_o && diag_ready_i) begin
`ifdef BUTTERFOLD_PERF
                        $display("MOD PERF diag-consume transform=%0b addr=%0d time=%0t",
                            pending_transform_last,pending_addr0,$time);
`endif
                        pending_valid<=1'b0; pending_writes_done<=1'b0;
                        diag_due<=1'b0;
                        if (pending_transform_last) begin
                            active_o<=1'b0; state<=M_IDLE; done_o<=1'b1;
                        end else begin state<=M_RUN; slot_phase<=3'd0; end
                    end
                end else if (slot_phase==3'd7) begin
                    slot_phase <= 3'd0;
                    if (state==M_RUN && fetch_issued) begin
                        if (fetch_last_in_stage) begin
                            // The first pair of stage S+1 is disjoint from
                            // the final pair of stage S and was committed
                            // earlier in S.  Prefetch it while the final S
                            // result is computed/written; only the final
                            // transform stage must drain.
                            if (fetch_stage == 3'd6) begin
                                state <= M_DRAIN;
                            end else begin
                                fetch_stage <= fetch_stage + 1'b1;
                                fetch_group <= 7'd0;
                                fetch_j <= 6'd0;
                                read_issue_count <= 0;
                                read_return_count <= 0;
                                fetch_issued <= 0;
                            end
                        end else begin
                            advance_fetch();
                            read_issue_count<=0; read_return_count<=0; fetch_issued<=0;
                        end
                    end
                end else slot_phase <= slot_phase + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
