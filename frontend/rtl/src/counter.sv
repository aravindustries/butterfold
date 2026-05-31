// 4-bit synchronous up-counter with active-high reset.
// Tiny on purpose: the full LibreLane flow runs in ~1-2 minutes.
//

package abc_pkg;
    parameter int WIDTH = 4;
endpackage: abc_pkg

module counter (
    input  wire                         clk,
    input  wire                         rst,
    output logic [abc_pkg::WIDTH-1 : 0] q
);
    logic [3:0] cnt;

    always_ff @(posedge clk) begin
        if (rst)
            cnt <= 4'b0;
        else
            cnt <= cnt + 4'b1;
    end

    assign q = cnt;
endmodule

