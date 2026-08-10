# Deterministic Padframe-A logical assignment.  Requires make_io_sites first.
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

# OpenROAD 26Q2 place_io_fill crashes on the GF180 rotated pad rows.  Create
# the exact GF fill5 master directly at legal five-micron sites instead; no
# PDK geometry is synthesized or approximated.
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
if {[info exists ::env(PADFRAME_FILL)] && $::env(PADFRAME_FILL)} {
  manual_fill_side W {{500 1250}}
  manual_fill_side E {{500 1175}}
  manual_fill_side N {{900 1125}}
  manual_fill_side S {{1050 1125}}
}
