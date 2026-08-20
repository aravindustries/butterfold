`default_nettype none

// Two parallel 256x8 macros form one 256x16 physical single port.  A logical
// 128x32 complex word occupies consecutive addresses:
//   {sample,0} = I[15:0], {sample,1} = Q[15:0].
module gf180_sram_256x16_complex (
    input logic clk, input logic rst_n,
    input logic req_i, input logic write_i, input logic [6:0] addr_i,
    input logic [31:0] wdata_i,
    output logic ready_o, output logic [31:0] rdata_o, output logic rvalid_o,

    // Direct physical 16-bit port used by the deterministic FFT modulo
    // scheduler.  Exactly one of half_mode_i and the complex transaction
    // interface may own the macros at a time.
    input logic half_mode_i,
    input logic half_req_i, input logic half_write_i,
    input logic [7:0] half_addr_i, input logic [15:0] half_wdata_i,
    output logic half_ready_o, output logic [15:0] half_rdata_o,
    output logic half_rvalid_o
`ifdef USE_POWER_PINS
    , inout wire VDD
    , inout wire VSS
`endif
);
    typedef enum logic [1:0] {IDLE, READ_Q, READ_Q_WAIT, WRITE_Q} state_t;
    state_t state;
    logic [6:0] saved_addr;
    logic [31:0] saved_wdata;
    logic [15:0] i_half;
    logic macro_req, macro_write;
    logic [7:0] macro_addr;
    logic [15:0] macro_wdata, macro_rdata;
    logic rv_lo, rv_hi;

    assign ready_o = !half_mode_i && ((state == IDLE) ||
        ((state == READ_Q_WAIT) && rv_lo && rv_hi));
    assign half_ready_o = half_mode_i && (state == IDLE);
    assign half_rdata_o = macro_rdata;
    assign half_rvalid_o = half_mode_i && rv_lo && rv_hi;
    always @* begin
        macro_req = 1'b0; macro_write = 1'b0; macro_addr = 8'd0; macro_wdata = 16'd0;
        // Ownership guarantees that the complex and half-word request sources
        // are mutually exclusive.  Qualify the physical port by an actual
        // request rather than the broader owner/busy signal so inactive TX and
        // debug modes do not lie in the SRAM control timing cone.
        if (half_req_i && state == IDLE) begin
            macro_req = half_req_i; macro_write = half_write_i;
            macro_addr = half_addr_i; macro_wdata = half_wdata_i;
        end else if ((state == IDLE || state == READ_Q_WAIT) && req_i) begin
            macro_req = 1'b1; macro_write = write_i;
            macro_addr = {addr_i,1'b0}; macro_wdata = wdata_i[15:0];
        end else if (state == READ_Q) begin
            macro_req = 1'b1; macro_addr = {saved_addr,1'b1};
        end else if (state == WRITE_Q) begin
            macro_req = 1'b1; macro_write = 1'b1;
            macro_addr = {saved_addr,1'b1}; macro_wdata = saved_wdata[31:16];
        end
    end

    gf180_sram_256x8_wrapper u_lo (
        .clk(clk),.rst_n(rst_n),.req_i(macro_req),.write_i(macro_write),
        .addr_i(macro_addr),.wdata_i(macro_wdata[7:0]),.wmask_i(8'hff),
        .rdata_o(macro_rdata[7:0]),.rvalid_o(rv_lo)
`ifdef USE_POWER_PINS
        , .VDD(VDD), .VSS(VSS)
`endif
    );
    gf180_sram_256x8_wrapper u_hi (
        .clk(clk),.rst_n(rst_n),.req_i(macro_req),.write_i(macro_write),
        .addr_i(macro_addr),.wdata_i(macro_wdata[15:8]),.wmask_i(8'hff),
        .rdata_o(macro_rdata[15:8]),.rvalid_o(rv_hi)
`ifdef USE_POWER_PINS
        , .VDD(VDD), .VSS(VSS)
`endif
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; saved_addr <= 7'd0; saved_wdata <= 32'd0;
            i_half <= 16'd0; rdata_o <= 32'd0; rvalid_o <= 1'b0;
        end else begin
            rvalid_o <= 1'b0;
            if (!half_mode_i) case (state)
                IDLE: if (req_i) begin
                    saved_addr <= addr_i; saved_wdata <= wdata_i;
                    if (write_i) state <= WRITE_Q;
                    else state <= READ_Q;
                end
                WRITE_Q: state <= IDLE;
                READ_Q: if (rv_lo && rv_hi) begin
                    i_half <= macro_rdata; state <= READ_Q_WAIT;
                end
                READ_Q_WAIT: if (rv_lo && rv_hi) begin
                    rdata_o <= {macro_rdata,i_half}; rvalid_o <= 1'b1;
                    if (req_i) begin
                        saved_addr <= addr_i; saved_wdata <= wdata_i;
                        if (write_i) state <= WRITE_Q;
                        else state <= READ_Q;
                    end else state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
