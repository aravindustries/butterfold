source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]
set stage [expr {[info exists ::env(PAD_ELECTRICAL_STAGE)] ? $::env(PAD_ELECTRICAL_STAGE) : "place"}]
set out "$phys_dir/results/padframe/electrical/$stage"
file mkdir $out
read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $cell_lib
read_liberty $sram_lib
read_liberty $io_lib
read_db "$pad_result/${stage}.odb"
read_sdc $pad_sdc
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
if {$stage ne "floorplan"} { estimate_parasitics -placement }
report_check_types -max_slew -violators > "$out/max_slew.rpt"
report_check_types -max_capacitance -violators > "$out/max_cap.rpt"
foreach pair {
  {clk clk_iso u_pad_clk/Y u_clk_iso/I}
  {rst rst_iso u_pad_rst_n/Y u_rst_iso/I}
  {valid core_din_valid_pad u_pad_din_valid/Y u_valid_iso/I}
  {din0 {core_din_pad[0]} u_pad_din0/Y u_din0_iso/I}
  {din1 {core_din_pad[1]} u_pad_din1/Y u_din1_iso/I}
  {din2 {core_din_pad[2]} u_pad_din2/Y u_din2_iso/I}
  {din3 {core_din_pad[3]} u_pad_din3/Y u_din3_iso/I}
  {din4 {core_din_pad[4]} u_pad_din4/Y u_din4_iso/I}
  {din5 {core_din_pad[5]} u_pad_din5/Y u_din5_iso/I}
  {din6 {core_din_pad[6]} u_pad_din6/Y u_din6_iso/I}
  {din7 {core_din_pad[7]} u_pad_din7/Y u_din7_iso/I}
} {
  lassign $pair label net from_pin to_pin
  report_net -verbose $net > "$out/${label}_net.rpt"
}
