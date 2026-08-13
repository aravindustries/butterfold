(* blackbox *)
module gf180mcu_fd_ip_sram__sram256x8m8wm1 (
    input CLK, CEN, GWEN,
    input [7:0] WEN,
    input [7:0] A,
    input [7:0] D,
    output [7:0] Q,
    input VDD, VSS
);
endmodule

// Explicit local SRAM-pin drivers used by the synthesizable wrapper.  Keeping
// these cells at the macro boundary prevents the two byte macros (and the
// eight WEN pins on each macro) from being collapsed onto one weak,
// high-capacitance control driver after flattening.
(* blackbox *)
module gf180mcu_fd_sc_mcu9t5v0__clkinv_4 (input I, output ZN);
endmodule

(* blackbox *)
module gf180mcu_fd_sc_mcu9t5v0__nand2_4 (input A1, input A2, output ZN);
endmodule

(* blackbox *)
module gf180mcu_fd_sc_mcu9t5v0__buf_4 (input I, output Z);
endmodule
