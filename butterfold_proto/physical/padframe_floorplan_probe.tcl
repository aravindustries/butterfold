source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]
read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $cell_lib
read_liberty $sram_lib
read_liberty $io_lib
read_verilog $mapped_core
read_verilog $wrapper
link_design butterfold_padframe_top
initialize_floorplan -die_area "0 0 $die_w $die_h" \
  -core_area "$core_x1 $core_y1 $core_x2 $core_y2" -site $site
make_io_sites -horizontal_site GF_IO_Site -vertical_site GF_IO_Site -corner_site GF_COR_Site -offset 0
place_corners gf180mcu_fd_io__cor
set y 500
foreach pad {u_pad_din_valid u_pad_din0 u_pad_din1 u_pad_din2 u_pad_din3 u_pad_din4 u_pad_din5 u_pad_din6 u_pad_din7 u_pad_din_ready} {
  place_pad -row IO_WEST -location $y $pad
  set y [expr {$y + 75}]
}
set y 500
foreach pad {u_pad_dout0 u_pad_dout1 u_pad_dout2 u_pad_dout3 u_pad_dout4 u_pad_dout5 u_pad_dout6 u_pad_dout7 u_pad_dout_valid} {
  place_pad -row IO_EAST -location $y $pad
  set y [expr {$y + 75}]
}
place_pad -row IO_NORTH -location 900 u_pad_clk
place_pad -row IO_NORTH -location 975 u_pad_rst_n
place_pad -row IO_NORTH -location 1050 u_pad_dvdd
place_pad -row IO_SOUTH -location 1050 u_pad_dvss
proc manual_fill_side {side occupied} {
  set block [ord::get_db_block]
  set master [[ord::get_db] findMaster gf180mcu_fd_io__fill5]
  for {set p 355} {$p < 1880} {set p [expr {$p + 5}]} {
    set blocked 0
    foreach range $occupied {
      lassign $range lo hi
      if {$p >= $lo && $p < $hi} { set blocked 1; break }
    }
    if {!$blocked} {
      set name "IO_FILL_${side}_[format %04d $p]"
      odb::dbInst_create $block $master $name
      if {$side eq "S"} { place_inst -name $name -origin [list $p 0] -orientation R0 -status FIRM }
      if {$side eq "N"} { place_inst -name $name -origin [list $p 2235] -orientation MX -status FIRM }
      if {$side eq "W"} { place_inst -name $name -origin [list 350 $p] -orientation R90 -status FIRM }
      if {$side eq "E"} { place_inst -name $name -origin [list 1885 $p] -orientation R270 -status FIRM }
    }
  }
}
manual_fill_side W {{500 1250}}
manual_fill_side E {{500 1175}}
manual_fill_side N {{900 1125}}
manual_fill_side S {{1050 1125}}
set row_names {}
foreach row [[ord::get_db_block] getRows] { lappend row_names [$row getName] }
puts "ROWS=$row_names"
puts "CELLS=[get_cells -hierarchical *u_pad*]"
puts "SRAMS=[get_cells -hierarchical *u_sram]"
write_def "$pad_result/probe.def"
