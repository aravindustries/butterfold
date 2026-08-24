# Native OpenROAD fill (LibreLane fill.tcl: filler_placement of DECAP then FILL).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/final_signoff
read_db $out/butterfold_top_routed.odb
set db [ord::get_db]
set fills {}
set decaps {}
foreach lib [$db getLibs] {
  foreach m [$lib getMasters] {
    set n [$m getName]
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
  }
}
# Largest first, matching typical LibreLane order
set decaps [lsort -decreasing $decaps]
set fills [lsort -decreasing $fills]
set fill_list [concat $decaps $fills]
puts "FILL_LIST $fill_list"
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
write_db $out/butterfold_top_filled.odb
write_def $out/butterfold_top_filled.def
write_verilog $out/butterfold_top.final.v
write_verilog -include_pwr_gnd $out/butterfold_top.final.pnl.v
puts "WROTE_FILL_VIEWS"
