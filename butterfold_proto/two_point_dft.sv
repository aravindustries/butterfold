`timescale 1ns/1ps

module two_point_dft.sv (
    input logic [7:0] x0, 
    input logic [7:0] x1,
    output logic [7:0] X0,
    output logic [7:0] X1
  );

  assign X0 = x0 + x1;
  assign X1 = x1 - x0;

endmodule


module two_point_dft_tb;

  reg x0, x1;
  wire X0, X1;

  two_point_dft tpd(.x0(a), .x1(b), .X0(X0), .X1(X1));

  initial begin
    #1 display("x0: %d, x1: %d, X0: %d, X1: %d", x0, x1, X0, X1);

    #6 
    
  end

endmodule
