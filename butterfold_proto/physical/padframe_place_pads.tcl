# Deterministic Padframe-A logical assignment.  Requires make_io_sites first.
#
# Pad SIDE and ORDER come from the official ACH pad map (see
# D03.def/D03/project_defs/ACH/D03_ACH_pad_map.yaml, never hand-edited) via
# gen_pad_positions.py -> padframe_pad_positions.generated.tcl. Re-run that
# generator (not this file) if the pad map changes.
#
# Per the official map: WEST carries VSS, clk, rst_n, din_valid_i, din[7:0]
# (descending), din_ready_o, dout_valid_o, dout[7], dout[6]. NORTH carries
# dout[5:0] (descending) then VDD. EAST and SOUTH have no real signals for
# our 23-pin slot (ACH reserves those for other participants / analog), so
# only fill cells go there.
place_corners gf180mcu_fd_io__cor

set phys_dir [file dirname [file normalize [info script]]]
source "$phys_dir/padframe_pad_positions.generated.tcl"

foreach entry $PAD_WEST_LIST {
  lassign $entry pad y
  place_pad -row IO_WEST -location $y $pad
}
foreach entry $PAD_NORTH_LIST {
  lassign $entry pad x
  place_pad -row IO_NORTH -location $x $pad
}

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
  manual_fill_side W $PAD_WEST_OCCUPIED
  manual_fill_side N $PAD_NORTH_OCCUPIED
  manual_fill_side E {}
  manual_fill_side S {}
}
