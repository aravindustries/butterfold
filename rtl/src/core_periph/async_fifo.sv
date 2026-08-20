// NOTE: maybe the mac layer might use information like eof to know when data is over
// this operates on the assumption that the outside clk is slower than the inside clk

module clk_dmn_sync #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned NUM_STABILIZATION_FLOPS = 2
)(
    input  uwire                    arst_n,

    input  uwire                    clk,
    input  uwire [DATA_WIDTH-1 : 0] meta,
    output uwire [DATA_WIDTH-1 : 0] stable
);
    (* ASYNC_REG = "TRUE" *)
    reg [DATA_WIDTH-1 : 0] meta_stable[NUM_STABILIZATION_FLOPS];

    always_ff @(posedge clk, negedge arst_n)
        if (!arst_n)
            meta_stable <= '{default: '0};
        else
            foreach(meta_stable[i])
                if (i == 0)
                    meta_stable[i] <= meta;
                else
                    meta_stable[i] <= meta_stable[i-1];

    assign stable = meta_stable[$high(meta_stable)];
endmodule: clk_dmn_sync

// Then, run simulation to check it works properly
module async_fifo #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned FIFO_DEPTH = 4
)(
    input  uwire                    arst_n,

    input  uwire                    write_clk,
    input  uwire                    write_enable,
    input  uwire [DATA_WIDTH-1 : 0] write_data,
    output logic                    full,

    input  uwire                    read_clk,
    input  uwire                    read_enable,
    output reg   [DATA_WIDTH-1 : 0] read_data,
    output logic                    empty
);
    localparam int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH);

    reg                      wr_phase, rd_phase;
    reg   [ADDR_WIDTH-1 : 0] wr_ptr, rd_ptr;

    logic                    wr_phase_gray, rd_phase_gray;
    logic [ADDR_WIDTH-1 : 0] wr_ptr_gray, rd_ptr_gray;

    logic                    wr_phase_next, wr_phase_next_gray;
    logic [ADDR_WIDTH-1 : 0] wr_ptr_next, wr_ptr_next_gray;

    logic                    mem_wr_enable, mem_rd_enable;

    uwire [ADDR_WIDTH-1 : 0] wr_addr, rd_addr;

    uwire                    wr_phase_gray_cdc, rd_phase_gray_cdc;
    uwire [ADDR_WIDTH-1 : 0] wr_ptr_gray_cdc, rd_ptr_gray_cdc;

    initial begin
        assert ((FIFO_DEPTH & (FIFO_DEPTH - 1)) == 0)
            else $fatal("FIFO_DEPTH must be power of two");
    end

    function logic [ADDR_WIDTH : 0] binary2gray(input logic [ADDR_WIDTH : 0] binary_num);
        foreach (binary_num[i])
            if (i == $high(binary_num))
                binary2gray[i] = binary_num[i];
            else
                binary2gray[i] = binary_num[i] ^^ binary_num[i+1];
    endfunction: binary2gray

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1 : 0] memory[FIFO_DEPTH];
    always_ff @(posedge write_clk)
        if (mem_wr_enable)
            memory[wr_addr] <= write_data;
    always_ff @(posedge read_clk)
        read_data <= memory[rd_addr];

    // write logic
    assign wr_addr = wr_ptr;

    clk_dmn_sync #(
        .DATA_WIDTH              (1+ADDR_WIDTH),
        .NUM_STABILIZATION_FLOPS (2)
    ) rd2wr_dmn_sync (
         .arst_n (arst_n),

        .clk    (write_clk),
        .meta   ({rd_phase_gray, rd_ptr_gray}),
        .stable ({rd_phase_gray_cdc, rd_ptr_gray_cdc})
    );

    always_comb
        mem_wr_enable = (write_enable && !full);

    always_ff @(posedge write_clk, negedge arst_n)
        if (!arst_n)
            {wr_phase, wr_ptr} <= '0;
        else
            if (mem_wr_enable)
                {wr_phase, wr_ptr} <=  {wr_phase, wr_ptr} + 1'b1;

    always_comb begin
        {wr_phase_next, wr_ptr_next}           = {wr_phase, wr_ptr} + 1'b1;
        {wr_phase_next_gray, wr_ptr_next_gray} = binary2gray({wr_phase_next, wr_ptr_next});
    end

    always_comb
        full = ({~rd_phase_gray_cdc, rd_ptr_gray_cdc} == {wr_phase_next_gray, wr_ptr_next_gray});

    always_comb
        {wr_phase_gray, wr_ptr_gray} = binary2gray({wr_phase, wr_ptr});

    // read logic
    assign rd_addr = rd_ptr;

    clk_dmn_sync #(
        .DATA_WIDTH              (1+ADDR_WIDTH),
        .NUM_STABILIZATION_FLOPS (2)
    ) wr2rd_dmn_sync (
         .arst_n (arst_n),
        .clk    (read_clk),
        .meta   ({wr_phase_gray, wr_ptr_gray}),
        .stable ({wr_phase_gray_cdc, wr_ptr_gray_cdc})
    );

    always_comb
        mem_rd_enable = (read_enable && !empty);

    always_ff @(posedge read_clk, negedge arst_n)
        if (!arst_n)
            {rd_phase, rd_ptr} <= '0;
        else
            if (mem_rd_enable)
                {rd_phase, rd_ptr} <=  {rd_phase, rd_ptr} + 1'b1;

    always_comb
        {rd_phase_gray, rd_ptr_gray} = binary2gray({rd_phase, rd_ptr});

    always_comb
        empty = ({wr_phase_gray_cdc, wr_ptr_gray_cdc} == {rd_phase_gray, rd_ptr_gray});
endmodule: async_fifo

// module mac_interface #(
//     parameter int DATA_WIDTH = 8 // share this in a pkg with the phy out layer as well
// )(
//     input  uwire         clk_core,
//     input  uwire [7 : 0] mac_dout,
//     input  uwire         mac_dout_wr,
//     output uwire [7 : 0] mac_din,
//     output uwire         mac_din_rd,
//
//     input  uwire         clk_mac_io,
//     input  uwire [7 : 0] sram_dout,
//     output uwire [7 : 0] sram_din,
//     output uwire [9 : 0] sram_addr,
//     output uwire [7 : 0] sram_rd_wr_en
// );
//     // it should be possible to get away with using just simple read logic to
//     // read from the SRAM with with a mac rd & eof signal
//
//     // Need a fifo from slow to fast if, the slow freq is too close to the fast freq
//     // then double flopping the valid signal will be too late to capture the data
// endmodule
