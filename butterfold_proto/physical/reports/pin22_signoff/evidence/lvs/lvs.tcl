set circuit1 [readnet spice /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/pin22_signoff/lvs/butterfold_top.unique_fixed.spice]
set circuit2 [readnet verilog /dev/null]
puts "Reading SPICE netlist file '/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice'..."
readnet spice /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice $circuit2
puts "Reading Verilog netlist file '/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/pin22_signoff/butterfold_top.final.pnl.v'..."
readnet verilog /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/pin22_signoff/butterfold_top.final.pnl.v $circuit2
lvs "$circuit1 butterfold_top" "$circuit2 butterfold_top" /foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/pin22_signoff/lvs/netgen/lvs.netgen.rpt -blackbox -json
