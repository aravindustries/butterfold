// Yosys represents the wrapper's low-transparent latches as $_DLATCH_N_.
// Map them explicitly because dfflibmap does not map latch primitives.
module \$_DLATCH_N_ (input E, input D, output Q);
    wire enable_high;
    gf180mcu_fd_sc_mcu9t5v0__clkinv_1 u_enable_inverter (
        .I(E), .ZN(enable_high)
    );
    gf180mcu_fd_sc_mcu9t5v0__latq_1 u_latch (
        .D(D), .E(enable_high), .Q(Q)
    );
endmodule
