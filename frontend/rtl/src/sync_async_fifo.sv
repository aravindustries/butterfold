`timescale 1ns / 1ps

// Create a folder: CDC under lib/ & break all of this into files & use
// a filelist.tcl to bring all of them together
// In the interface that encapsulates the signals to these fifos, add a task
// that can print out the content of the fifo when needed.
virtual class cdc_arithmetic #(
    parameter type T = logic [0 : 0] // WARN: must be a vector to work
);
    static function T binary2gray(input T binary_num); // WARN: maybe it should not be static
        foreach (binary_num[i])
            if (i == $high(binary_num))
                binary2gray[i] = binary_num[i];
            else
                binary2gray[i] = binary_num[i] ^^ binary_num[i+1];
    endfunction: binary2gray

    static function T gray2binary(input T gray_num);
        foreach (gray_num[i])
            if (i == $high(gray_num))
                gray2binary[i] = gray_num[i];
            else
                gray2binary[i] = gray_num[i] ^^ gray2binary[i+1];
    endfunction: gray2binary

    // // This needs to be in a different class - sv_essentials
    // static function T reverse_unpack(input T unreversed_unpack, int unsigned chunk_size = 1); // chunk size will group a range of elements together before shifting
    //     foreach (unreversed_unpack[i])
    //         reverse_unpack[i] = unreversed_unpack[$high(unreversed_unpack) - i];
    // endfunction: reverse_unpack

    // WARN: Need this inside tb utils class
    task automatic reset_sequence(
        output bit reset,
        input bit active_high = 1,
        input clk,
        input int unsigned cycles = 1
    );
        reset = (active_high)? '1 : '0;
        repeat(cycles) @(negedge clk);
        reset = (active_high)? '0 : '1;
    endtask:reset_sequence
endclass: cdc_arithmetic

module clk_dmn_sync #(
    parameter type          T                       = logic,
    parameter int  unsigned NUM_STABILIZATION_FLOPS = 2,
    parameter bit           INPUT_GRAY_ENCODED,
    parameter bit           RETAIN_GRAY_CODING // WARN: change to using 1 paramter since only 1 is used
)(
    input  uwire clk, rst_n,
    input  T     meta,
    output T     stable
);
    T meta_stable[NUM_STABILIZATION_FLOPS];
    
    always_ff @(posedge clk) begin
        if (!rst_n)
            meta_stable <= '{default: '0};
        else
            foreach (meta_stable[i]) begin
                case (i)
                    0 : begin
                        meta_stable[i] <= meta;
                    end
                    $high(meta_stable) : begin
                        if (INPUT_GRAY_ENCODED && !RETAIN_GRAY_CODING) begin
                            meta_stable[i] <= cdc_arithmetic
                                              #(.T(type(meta_stable[i-1])))
                                              ::gray2binary(meta_stable[i-1]);
                        end
                        else
                            meta_stable[i] <= meta_stable[i-1];
                    end
                    default : begin
                        meta_stable[i] <= meta_stable[i-1];
                    end
                endcase
            end
    end

    assign stable = meta_stable[$high(meta_stable)];
endmodule: clk_dmn_sync

// if the rd or write pointer abruptly changes to 0 cause the depth is not
// a power of 2, the gray coding fails & more than 1 bit changes
// WARN: ask AI for suggestions to this code
module circ_async_fifo #(
    parameter bit                                   SYNC_FIFO      = 1'b0,

    parameter int unsigned                          DATA_WIDTH = 8,
    parameter int unsigned                          FIFO_DEPTH = 4,

    parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_FILLED  = 0,
    parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_EMPTIED = 0
)(
    // Write Domain
    input  uwire                    write_clk, rst_n, // WARN: This reset cannot be here, it must be arst_n
    input  uwire                    write_enable,
    input  uwire [DATA_WIDTH-1 : 0] write_data,
    output uwire                    almost_full,
    output uwire                    full,

    // Read Domain
    input  uwire                    read_clk,
    input  uwire                    read_enable,
    output reg   [DATA_WIDTH-1 : 0] read_data,
    output uwire                    almost_empty,
    output uwire                    empty
);
    uwire                            wr_clk, rd_clk;

    uwire                            wr_phase_cdc, rd_phase_cdc;
    uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc, rd_ptr_cdc;

    uwire                            mem_wr_enable, mem_rd_enable;
    uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_addr, rd_addr;

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1 : 0] memory[FIFO_DEPTH];

    // Defaults
    generate
        assign wr_clk = write_clk;

        if (SYNC_FIFO)
            assign rd_clk = write_clk;
        else
            assign rd_clk = read_clk;
    endgenerate

    always_ff @(posedge wr_clk)
        if (mem_wr_enable)
            memory[wr_addr] <= write_data;

    always_ff @(posedge rd_clk)
        if (mem_rd_enable) // WARN: consider removing
            read_data <= memory[rd_addr];
        else
            read_data <= 'x;

    write_domain #(
        .SYNC_FIFO     (SYNC_FIFO),
        .FIFO_DEPTH    (FIFO_DEPTH),
        .ALMOST_FILLED (ALMOST_FILLED)
    ) wr_dmn (
        .wr_clk, .rst_n,

        .wr_enable (write_enable),

        // Interface
        .rd_phase_cdc,
        .rd_ptr_cdc,

        .wr_phase_cdc,
        .wr_ptr_cdc,
        // Interface

        .mem_wr_enable,
        .wr_addr,

        .almost_full,
        .full
    );

    read_domain #(
        .SYNC_FIFO      (SYNC_FIFO),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .ALMOST_EMPTIED (ALMOST_EMPTIED)
    ) rd_dmn (
        .rd_clk, .rst_n,

        .rd_enable (read_enable),

        // Interface
        .wr_phase_cdc,
        .wr_ptr_cdc,

        .rd_phase_cdc,
        .rd_ptr_cdc,
        // Interface

        .mem_rd_enable,
        .rd_addr,

        .almost_empty,
        .empty
    );

    module write_domain #(
        parameter bit                                   SYNC_FIFO,
        parameter int unsigned                          FIFO_DEPTH,
        parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_FILLED
    )(
        input  uwire                            wr_clk, rst_n,

        input  uwire                            wr_enable,

        // Interface
        input  uwire                            rd_phase_cdc,
        input  uwire [$clog2(FIFO_DEPTH)-1 : 0] rd_ptr_cdc,

        output reg                              wr_phase_cdc,
        output reg   [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc,
        // Interface

        output logic                            mem_wr_enable,
        output uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_addr,

        output logic                            almost_full,
        output logic                            full
    );
        parameter int unsigned CLK_DMN_CROSS_FLOPS = 2;

        reg                            wr_phase;
        reg [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr;

        uwire                            rd_phase;
        uwire [$clog2(FIFO_DEPTH)-1 : 0] rd_ptr;

        // Defaults
        assign wr_addr = wr_ptr;

        generate
            if (SYNC_FIFO)
                assign {rd_phase, rd_ptr} = {rd_phase_cdc, rd_ptr_cdc};
            else
                clk_dmn_sync #(
                    .T                       (type({rd_phase_cdc, rd_ptr_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (1),
                    .RETAIN_GRAY_CODING      (0) // seems to work even when this is high
                    // WARN: check why this isn't working by removing the
                    // conversion logic in this module
                ) rd2wr_dmn_sync (
                    .clk    (wr_clk), .rst_n,
                    .meta   ({rd_phase_cdc, rd_ptr_cdc}),
                    .stable ({rd_phase,     rd_ptr})
                );
        endgenerate

        always_comb
            mem_wr_enable = (wr_enable && !full);

        always_ff @(posedge wr_clk)
            if (!rst_n)
                {wr_phase, wr_ptr} <= '0;
            else
                if (mem_wr_enable)
                    if (wr_ptr == FIFO_DEPTH-1) // Explicit wrap if the depth is not a power of 2
                        {wr_phase, wr_ptr} <= {~wr_phase, {$bits(wr_ptr){1'b0}}};
                    else
                        {wr_phase, wr_ptr} <=  {wr_phase, wr_ptr} + 1'b1;

        always_comb begin
            almost_full = ({~rd_phase, rd_ptr} <= ({wr_phase, wr_ptr} + ALMOST_FILLED));
            full        = ({~rd_phase, rd_ptr} ==  {wr_phase, wr_ptr});
        end

        generate
            if (SYNC_FIFO)
                assign {wr_phase_cdc, wr_ptr_cdc} = {wr_phase, wr_ptr}; // pass directly
            else
                always_comb
                    {wr_phase_cdc, wr_ptr_cdc} = cdc_arithmetic
                                                 #(.T(type({wr_phase, wr_ptr})))
                                                 ::binary2gray({wr_phase, wr_ptr});
        endgenerate
    endmodule: write_domain

    module read_domain #(
        parameter bit                                   SYNC_FIFO,
        parameter int unsigned                          FIFO_DEPTH,
        parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_EMPTIED
    )(
        input  uwire                            rd_clk, rst_n,

        input  uwire                            rd_enable,

        // Interface
        input  uwire                            wr_phase_cdc,
        input  uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc,

        output reg                              rd_phase_cdc,
        output reg   [$clog2(FIFO_DEPTH)-1 : 0] rd_ptr_cdc,
        // Interface

        output logic                            mem_rd_enable,
        output uwire [$clog2(FIFO_DEPTH)-1 : 0] rd_addr,

        output logic                            almost_empty,
        output logic                            empty
    );
        parameter int unsigned CLK_DMN_CROSS_FLOPS = 2;

        reg                            rd_phase;
        reg [$clog2(FIFO_DEPTH)-1 : 0] rd_ptr;

        uwire                            wr_phase;
        uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr;

        // Defaults
        assign rd_addr = rd_ptr;

        generate
            if (SYNC_FIFO)
                assign {wr_phase, wr_ptr} = {wr_phase_cdc, wr_ptr_cdc};
            else
                clk_dmn_sync #(
                    .T                       (type({wr_phase_cdc, wr_ptr_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (1),
                    .RETAIN_GRAY_CODING      (0)
                ) wr2rd_dmn_sync (
                    .clk    (rd_clk), .rst_n,
                    .meta   ({wr_phase_cdc, wr_ptr_cdc}),
                    .stable ({wr_phase,     wr_ptr})
                );
        endgenerate

        always_comb
            mem_rd_enable = (rd_enable && !empty);

        always_ff @(posedge rd_clk)
            if (!rst_n)
                {rd_phase, rd_ptr} <= '0;
            else
                if (mem_rd_enable)
                    if (rd_ptr == FIFO_DEPTH-1) // Explicit wrap if the depth is not a power of 2
                        {rd_phase, rd_ptr} <= {~rd_phase, {$bits(rd_ptr){1'b0}}};
                    else
                        {rd_phase, rd_ptr} <=  {rd_phase, rd_ptr} + 1'b1;

        always_comb begin
            almost_empty = ({wr_phase, wr_ptr} <= ({rd_phase, rd_ptr} + ALMOST_EMPTIED));
            empty        = ({wr_phase, wr_ptr} ==  {rd_phase, rd_ptr});
        end

        generate
            if (SYNC_FIFO)
                assign {rd_phase_cdc, rd_ptr_cdc} = {rd_phase, rd_ptr};
            else
                always_comb
                    {rd_phase_cdc, rd_ptr_cdc} = cdc_arithmetic
                                                 #(.T(type({rd_phase, rd_ptr})))
                                                 ::binary2gray({rd_phase, rd_ptr});
        endgenerate
    endmodule: read_domain

    // assert property (@(posedge clk) !$isunknown(rd_data) |->##FIFO_DEPTH $isunknown(rd_data));
endmodule: circ_async_fifo

module circ_async_snapshot_fifo #(
    parameter bit                                   SYNC_FIFO     = 1'b0,

    parameter int unsigned                          DATA_WIDTH = 8,
    parameter int unsigned                          FIFO_DEPTH = 128,

    parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_FILLED = 0,
    parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_EOF    = 0
)(
    // Write Domain
    input  uwire                    write_clk, rst_n,
    input  uwire                    write_enable,
    input  uwire                    write_hold = 1'b0,
    input  uwire [DATA_WIDTH-1 : 0] write_data,
    output uwire                    peek_busy,
    output uwire                    almost_full,
    output uwire                    full,

    // Peek Domain
    input  uwire                    peek_clk,
    input  uwire                    peek_enable,
    input  uwire                    peek_hold = 1'b0,
    output reg   [DATA_WIDTH-1 : 0] peek_data,
    output uwire                    write_busy,
    output uwire                    almost_eof,
    output uwire                    eof
);
    uwire                            wr_clk, pk_clk;

    uwire                            wr_busy_cdc, pk_busy_cdc;

    uwire                            wr_phase_cdc, wr_phase_snap_cdc;
    uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc,   wr_ptr_snap_cdc;

    uwire                            mem_wr_enable, mem_pk_enable;
    uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_addr,    pk_addr;

    generate
        assign wr_clk = write_clk;

        if (SYNC_FIFO)
            assign pk_clk = write_clk;
        else
            assign pk_clk = peek_clk;
    endgenerate

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1 : 0] memory[FIFO_DEPTH];

    always_ff @(posedge wr_clk)
        if (mem_wr_enable)
            memory[wr_addr] <= write_data;

    always_ff @(posedge pk_clk)
        if (mem_pk_enable)
            peek_data <= memory[pk_addr];
        else
            peek_data <= 'x;

    write_domain #(
        .SYNC_FIFO     (SYNC_FIFO),
        .FIFO_DEPTH    (FIFO_DEPTH),
        .ALMOST_FILLED (ALMOST_FILLED)
    ) wr_dmn (
        .wr_clk, .rst_n,

        .wr_enable(write_enable),
        .wr_hold  (write_hold),

        // Interface
        .pk_busy_cdc,
        .wr_busy_cdc,

        .wr_phase_cdc, .wr_phase_snap_cdc,
        .wr_ptr_cdc,   .wr_ptr_snap_cdc,
        // Interface

        .mem_wr_enable,
        .wr_addr,

        .pk_busy(peek_busy),

        .almost_full,
        .full
    );

    peek_domain #(
        .SYNC_FIFO  (SYNC_FIFO),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ALMOST_EOF (ALMOST_EOF)
    ) pk_dmn (
        .pk_clk, .rst_n,

        .pk_enable(peek_enable),
        .pk_hold  (peek_hold),

        // Interface
        .wr_phase_cdc, .wr_phase_snap_cdc,
        .wr_ptr_cdc,   .wr_ptr_snap_cdc,

        .wr_busy_cdc,
        .pk_busy_cdc,
        // Interface

        .mem_pk_enable,
        .pk_addr,

        .wr_busy(write_busy),

        .almost_eof,
        .eof
    );

    module write_domain #(
        parameter bit                                   SYNC_FIFO,
        parameter int unsigned                          FIFO_DEPTH,
        parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_FILLED
    )(
        input  uwire                            wr_clk, rst_n,

        input  uwire                            wr_enable,
        input  uwire                            wr_hold,

        // Interface
        input  uwire                            pk_busy_cdc,
        output uwire                            wr_busy_cdc,
        
        output logic                            wr_phase_cdc, wr_phase_snap_cdc,
        output logic [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc,   wr_ptr_snap_cdc,
        // Interface

        output logic                            mem_wr_enable,
        output uwire [$clog2(FIFO_DEPTH)-1 : 0] wr_addr,

        output uwire                            pk_busy,

        output logic                            almost_full,
        output logic                            full
    );
        parameter int unsigned CLK_DMN_CROSS_FLOPS = 2;

        reg                            wr_phase;
        reg [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr;

        logic wr_enable_posedge;
        logic wr_busy;

        type(wr_enable) wr_enable_buf;
        type(wr_phase)  wr_phase_snap;
        type(wr_ptr)    wr_ptr_snap;

        // Defaults
        assign wr_addr = wr_ptr;

        generate
            if (SYNC_FIFO)
                assign pk_busy = pk_busy_cdc;
            else
                clk_dmn_sync #(
                    .T                       (type({pk_busy_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (0) // NOTE: single bit signal doesn't need to be encoded
                ) pk2wr_dmn_sync (
                    .clk    (wr_clk), .rst_n,
                    .meta   ({pk_busy_cdc}),
                    .stable ({pk_busy})
                );
        endgenerate

        always_ff @(posedge wr_clk)
            if (!rst_n)
                wr_enable_buf <= '0;
            else
                wr_enable_buf <= wr_enable;

        always_comb
            wr_enable_posedge = !wr_enable_buf && wr_enable;

        always_ff @(posedge wr_clk)
            if (!rst_n)
                {wr_phase_snap, wr_ptr_snap} <= '0;
            else
                if (wr_enable_posedge && !wr_hold)
                    {wr_phase_snap, wr_ptr_snap} <= {wr_phase, wr_ptr};

        always_comb
            mem_wr_enable = (wr_enable || (full && wr_enable_posedge));

        always_ff @(posedge wr_clk)
            if (!rst_n)
                {wr_phase, wr_ptr} <= '0;
            else
                if (mem_wr_enable)
                    if (wr_ptr == FIFO_DEPTH-1)
                        {wr_phase, wr_ptr} <= {~wr_phase, {$bits(wr_ptr){1'b0}}};
                    else
                        {wr_phase, wr_ptr} <=  {wr_phase, wr_ptr} + 1'b1;

        always_comb begin
            almost_full = ({~wr_phase_snap, wr_ptr_snap} <= ({wr_phase, wr_ptr} + ALMOST_FILLED));
            full        = ({~wr_phase_snap, wr_ptr_snap} ==  {wr_phase, wr_ptr});
        end

        always_comb
            wr_busy = mem_wr_enable || wr_hold; // NOTE: check this

        generate
            assign wr_busy_cdc = wr_busy; // No gray code for this

            if (SYNC_FIFO) begin
                assign {wr_phase_cdc,      wr_ptr_cdc}      = {wr_phase,      wr_ptr};
                assign {wr_phase_snap_cdc, wr_ptr_snap_cdc} = {wr_phase_snap, wr_ptr_snap};
            end
            else begin
                always_comb
                    {wr_phase_cdc,      wr_ptr_cdc}      = cdc_arithmetic
                                                           #(.T(type({wr_phase, wr_ptr})))
                                                           ::binary2gray({wr_phase, wr_ptr});
                always_comb
                    {wr_phase_snap_cdc, wr_ptr_snap_cdc} = cdc_arithmetic
                                                           #(.T(type({wr_phase_snap, wr_ptr_snap})))
                                                           ::binary2gray({wr_phase_snap, wr_ptr_snap});
            end
        endgenerate
    endmodule: write_domain

    module peek_domain #(
        parameter bit                                   SYNC_FIFO,
        parameter int unsigned                          FIFO_DEPTH,
        parameter bit          [$clog2(FIFO_DEPTH) : 0] ALMOST_EOF
    )(
        input  uwire                            pk_clk, rst_n,

        input  uwire                            pk_enable,
        input  uwire                            pk_hold,

        // Interface
        input  logic                            wr_phase_cdc, wr_phase_snap_cdc,
        input  logic [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr_cdc,   wr_ptr_snap_cdc,

        input  uwire                            wr_busy_cdc,
        output uwire                            pk_busy_cdc,
        // Interface

        output logic                            mem_pk_enable,
        output uwire [$clog2(FIFO_DEPTH)-1 : 0] pk_addr,
        
        output uwire                            wr_busy,

        output logic                            almost_eof,
        output logic                            eof
    );
        parameter int unsigned CLK_DMN_CROSS_FLOPS = 2;

        reg                            pk_phase;
        reg [$clog2(FIFO_DEPTH)-1 : 0] pk_ptr;

        wire                            wr_phase, wr_phase_snap;
        wire [$clog2(FIFO_DEPTH)-1 : 0] wr_ptr, wr_ptr_snap;

        logic pk_busy;

        type(pk_enable) pk_enable_buf;

        // Defaults
        assign pk_addr = pk_ptr;

        generate
            if (SYNC_FIFO) begin
                assign  wr_busy                     =  wr_busy_cdc;
                assign {wr_phase,      wr_ptr}      = {wr_phase_cdc,      wr_ptr_cdc};
                assign {wr_phase_snap, wr_ptr_snap} = {wr_phase_snap_cdc, wr_ptr_snap_cdc};
            end
            else begin
                clk_dmn_sync #(
                    .T                       (type({wr_busy_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (0)
                ) wr2pk_dmn_sync1 (
                    .clk    (pk_clk), .rst_n,
                    .meta   ({wr_busy_cdc}),
                    .stable ({wr_busy})
                );
                clk_dmn_sync #(
                    .T                       (type({wr_phase_cdc, wr_ptr_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (1),
                    .RETAIN_GRAY_CODING      (0)
                ) wr2pk_dmn_sync2 (
                    .clk    (pk_clk), .rst_n,
                    .meta   ({wr_phase_cdc, wr_ptr_cdc}),
                    .stable ({wr_phase, wr_ptr})
                );
                clk_dmn_sync #(
                    .T                       (type({wr_phase_snap_cdc, wr_ptr_snap_cdc})),
                    .NUM_STABILIZATION_FLOPS (CLK_DMN_CROSS_FLOPS),
                    .INPUT_GRAY_ENCODED      (1),
                    .RETAIN_GRAY_CODING      (0)
                ) wr2pk_dmn_sync3 (
                    .clk    (pk_clk), .rst_n,
                    .meta   ({wr_phase_snap_cdc, wr_ptr_snap_cdc}),
                    .stable ({wr_phase_snap, wr_ptr_snap})
                );
            end
        endgenerate

        always_ff @(pk_clk)
            if (!rst_n)
                pk_enable_buf <= '0;
            else
                pk_enable_buf <= pk_enable;
        
        always_comb
            mem_pk_enable = (pk_enable && !eof);

        always_ff @(posedge pk_clk)
            if (!rst_n)
                {pk_phase, pk_ptr} <= '0;
            else begin
                if (mem_pk_enable && !pk_hold)
                    if (pk_ptr == FIFO_DEPTH-1)
                        {pk_phase, pk_ptr} <= {~pk_phase, {$bits(pk_ptr){1'b0}}};
                    else
                        {pk_phase, pk_ptr} <=  {pk_phase, pk_ptr} + 1'b1;
                if (!pk_enable && pk_enable_buf) // TODO: create signal pk_enable_posedge
                    {pk_phase, pk_ptr} <= {wr_phase_snap, wr_ptr_snap};
            end

        always_comb begin
            almost_eof = ({wr_phase, wr_ptr} <= ({pk_phase, pk_ptr} + ALMOST_EOF));
            eof        = ({wr_phase, wr_ptr} ==  {pk_phase, pk_ptr});
        end

        always_comb
            pk_busy = mem_pk_enable || pk_hold; // NOTE: check this

        generate
            assign pk_busy_cdc = pk_busy;
        endgenerate
    endmodule: peek_domain
endmodule: circ_async_snapshot_fifo

