# Intentionally bind each top-level logical signal terminal to the conductive
# Metal5 PAD port of its instantiated GF180 I/O cell.  The old flow let
# place_pins create unrelated die-edge shapes; signal routing then skipped the
# special pad nets, leaving most external terminals electrically isolated.

proc connect_signal_bterm_to_pad {bterm_name inst_name} {
  set block [ord::get_db_block]
  set bterm [$block findBTerm $bterm_name]
  set inst [$block findInst $inst_name]
  if {$bterm eq "NULL"} { error "missing BTerm $bterm_name" }
  if {$inst eq "NULL"} { error "missing pad instance $inst_name" }

  set pad_iterm [$inst findITerm PAD]
  if {$pad_iterm eq "NULL"} { error "$inst_name has no PAD ITerm" }
  set pad_box [$pad_iterm getBBox]
  if {[$pad_box area] == 0} { error "$inst_name/PAD has no placed geometry" }

  # PAD is a Metal5 port in both selected GF180 I/O masters.  Recreate the
  # external terminal on exactly that transformed access rectangle.  This is
  # intentional terminal ownership of the bond-pad conductor, not incidental
  # overlap with an independently placed die-edge pin.
  set layer [[[ord::get_db] getTech] findLayer Metal5]
  if {$layer eq "NULL"} { error "technology has no Metal5 layer" }
  foreach bpin [$bterm getBPins] { odb::dbBPin_destroy $bpin }
  set bpin [odb::dbBPin_create $bterm]
  odb::dbBox_create $bpin $layer \
      [$pad_box xMin] [$pad_box yMin] [$pad_box xMax] [$pad_box yMax]
  $bpin setPlacementStatus FIRM

  # No signal router escape is required: the BTerm is the I/O cell PAD metal.
  # Keep these nets special so TritonRoute does not reject the bond-pad port as
  # an ordinary core-routing access point.
  set net [$bterm getNet]
  if {$net eq "NULL"} { error "$bterm_name is not connected to a net" }
  $net setSpecial
  puts "PAD_BOUNDARY $bterm_name $inst_name Metal5 [$pad_box xMin] [$pad_box yMin] [$pad_box xMax] [$pad_box yMax]"
}

connect_signal_bterm_to_pad pad_clk u_pad_clk
connect_signal_bterm_to_pad pad_rst_n u_pad_rst_n
connect_signal_bterm_to_pad pad_din_valid_i u_pad_din_valid
connect_signal_bterm_to_pad pad_din_ready_o u_pad_din_ready
connect_signal_bterm_to_pad pad_dout_valid_o u_pad_dout_valid
for {set i 0} {$i < 8} {incr i} {
  connect_signal_bterm_to_pad "pad_din\[$i\]" "u_pad_din$i"
  connect_signal_bterm_to_pad "pad_dout\[$i\]" "u_pad_dout$i"
}
