module pad_delay_netlist(
    input  wire input_pad,
    output wire input_core,
    input  wire output_core,
    output wire output_pad
);
    gf180mcu_fd_io__in_c u_input (
        .PAD(input_pad), .Y(input_core), .PU(1'b0), .PD(1'b0),
        .DVDD(1'b1), .DVSS(1'b0), .VDD(1'b1), .VSS(1'b0)
    );
    gf180mcu_fd_io__bi_24t u_output (
        .A(output_core), .PAD(output_pad), .OE(1'b1), .IE(1'b0),
        .SL(1'b0), .CS(1'b0), .PU(1'b0), .PD(1'b0),
        .DVDD(1'b1), .DVSS(1'b0), .VDD(1'b1), .VSS(1'b0)
    );
endmodule
