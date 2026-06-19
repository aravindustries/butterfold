// 4-bit synchronous up-counter with active-high reset.
// Tiny on purpose: the full LibreLane flow runs in ~1-2 minutes.
//

package abc_pkg;
    localparam int WIDTH = 4;
endpackage: abc_pkg

module counter (
    input  wire                         clk,
    input  wire                         rst,
    output logic [abc_pkg::WIDTH-1 : 0] q
);
    logic [3:0] cnt;
    wire [7:0] din;
    wire [7:0] dout;

    always_ff @(posedge clk) begin
        if (rst)
            cnt <= 4'b0;
        else
            cnt <= cnt + 4'b1;
    end

    assign q = dout;

    gf180mcu_fd_ip_sram__sram64x8m8wm1 u_sram (
          .CLK  (clk)
        , .CEN  (1'b0)
        , .GWEN (1'b1)
        , .WEN  (8'h00)
        , .A    (cnt[5:0])
        , .D    (1'b1)
        , .Q    (dout)
        `ifdef XILINX_SIMULATOR
        , .VDD  (1'b1)
        , .VSS  (1'b0)
        `endif
    );

    // initial $monitor("%x %x", cnt, dout);
endmodule

