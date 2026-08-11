# Physically realize pad configuration constants.  Connecting SIGNAL control
# pins directly to special PG nets left them unrouted and floating in GDS.
# One local TIEL is used per input pad; each output pad gets local TIEL/TIEH.

proc connect_iterm_to_net {iterm net} {
  if {$iterm eq "NULL"} { error "missing ITerm" }
  if {[$iterm getNet] ne "NULL"} { $iterm disconnect }
  $iterm connect $net
}

proc create_pad_tie {pad_name value x y pins} {
  set block [ord::get_db_block]
  set suffix [expr {$value ? "hi" : "lo"}]
  set inst_name "${pad_name}_tie_${suffix}"
  if {[$block findInst $inst_name] ne "NULL"} { return }
  set master_name [expr {$value ?
      "gf180mcu_fd_sc_mcu9t5v0__tieh" :
      "gf180mcu_fd_sc_mcu9t5v0__tiel"}]
  set master [[ord::get_db] findMaster $master_name]
  if {$master eq "NULL"} { error "missing tie master $master_name" }
  set inst [odb::dbInst_create $block $master $inst_name]
  place_inst -name $inst_name -origin [list $x $y] -orientation R0 -status PLACED

  set net_name "${inst_name}_net"
  set net [odb::dbNet_create $block $net_name]
  set out_pin [expr {$value ? "Z" : "ZN"}]
  connect_iterm_to_net [$inst findITerm $out_pin] $net

  set vdd [$block findNet one_]
  set vss [$block findNet zero_]
  if {$vdd eq "NULL" || $vss eq "NULL"} { error "missing padframe supply nets" }
  foreach pin {VDD VNW} {
    set it [$inst findITerm $pin]
    if {$it ne "NULL"} { connect_iterm_to_net $it $vdd }
  }
  foreach pin {VSS VPW} {
    set it [$inst findITerm $pin]
    if {$it ne "NULL"} { connect_iterm_to_net $it $vss }
  }

  set pad [$block findInst $pad_name]
  if {$pad eq "NULL"} { error "missing pad $pad_name" }
  foreach pin $pins {
    set it [$pad findITerm $pin]
    if {$it eq "NULL"} { error "$pad_name missing control pin $pin" }
    connect_iterm_to_net $it $net
  }
  puts "PAD_CONTROL $pad_name $suffix $inst_name [join $pins ,]"
}

# West-side inputs: disable pull-up and pull-down.
set y 500
foreach pad {u_pad_din_valid u_pad_din0 u_pad_din1 u_pad_din2 u_pad_din3 u_pad_din4 u_pad_din5 u_pad_din6 u_pad_din7 u_pad_clk u_pad_rst_n} {
  create_pad_tie $pad 0 420 $y {PU PD}
  set y [expr {$y + 75}]
}

# Output-capable pads: disable input, pulls, slew/CS options; enable output and
# retain the selected maximum PDRV setting.
set y 500
foreach pad {u_pad_din_ready u_pad_dout0 u_pad_dout1 u_pad_dout2 u_pad_dout3 u_pad_dout4 u_pad_dout5 u_pad_dout6 u_pad_dout7 u_pad_dout_valid} {
  create_pad_tie $pad 0 1780 $y {CS IE PD PU SL}
  create_pad_tie $pad 1 1790 $y {OE PDRV0 PDRV1}
  set y [expr {$y + 75}]
}

# Legalize only the newly inserted local cells and their immediate neighbors.
detailed_placement -incremental -max_displacement {100 100}
