# Pre-DRT timing closure on ACH-integrated native-PDN design.
# Start: ach_applied.odb (135 BTerms, 102 ties, native ring).
# Destroy signal wires only. Never regenerate PDN. Never touch ACH geometry.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach/predrt
set pdk /foss/pdks/gf180mcuD
file mkdir $out
file mkdir $out/drt
set phase prep
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
set odb_tag odb_buf
if {[info exists env(ODB_TAG)] && $env(ODB_TAG) ne ""} { set odb_tag $env(ODB_TAG) }
puts "PREDRT_PHASE $phase"

proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
proc inst_count {} { return [llength [[ord::get_db_block] getInsts]] }
proc destroy_signal_wires {} {
  foreach net [[ord::get_db_block] getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}
proc rename_ach_output_nets {} {
  set block [ord::get_db_block]
  set n 0
  foreach pair {
    {din_ready_o din_ready_o_OUT}
    {dout_valid_o dout_valid_o_OUT}
    {dout[0] dout_OUT[0]} {dout[1] dout_OUT[1]} {dout[2] dout_OUT[2]} {dout[3] dout_OUT[3]}
    {dout[4] dout_OUT[4]} {dout[5] dout_OUT[5]} {dout[6] dout_OUT[6]} {dout[7] dout_OUT[7]}
  } {
    lassign $pair old new
    set net [$block findNet $old]
    if {$net ne "NULL" && $net ne ""} {
      $net rename $new
      incr n
      puts "RENAME_NET $old -> $new"
    }
  }
  puts "NETS_RENAMED $n BTERMS [llength [$block getBTerms]]"
}
proc ensure_m2_obs {} {
  set block [ord::get_db_block]
  set layer [[[ord::get_db] getTech] findLayer Metal2]
  set dbu [$block getDefUnits]
  set x2 [expr {int(2.0 * $dbu)}]
  set y2 [expr {int(65.0 * $dbu)}]
  foreach o [$block getObstructions] {
    set b [$o getBBox]
    if {[$b getTechLayer] eq $layer && [$b xMin]==0 && [$b yMin]==0 && [$b xMax]==$x2 && [$b yMax]==$y2} { return }
  }
  odb::dbObstruction_create $block $layer 0 0 $x2 $y2
}
proc ensure_pad_spacing_obs {} {
  set organizer "$::proto/physical/reports/native_power_ring_ach/evidence/D03_ACH.def"
  set intended {
    VSS clk rst_n din_valid_i din[7] din[6] din[5] din[4] din[3] din[2] din[1] din[0]
    din_ready_o_OUT dout_valid_o_OUT dout_OUT[7] dout_OUT[6] dout_OUT[5] dout_OUT[4]
    dout_OUT[3] dout_OUT[2] dout_OUT[1] dout_OUT[0] VDD
  }
  set fh [open $organizer r]
  set text [read $fh]
  close $fh
  set block [ord::get_db_block]
  set layer [[[ord::get_db] getTech] findLayer Metal2]
  set dbu [$block getDefUnits]
  set scale [expr {$dbu / 200.0}]
  set die [$block getDieArea]
  set current ""
  set ::pad_spacing_obs {}
  set created 0
  foreach line [split $text "\n"] {
    if {[regexp {^- ([^ ]+) } $line -> name]} { set current $name }
    if {$current eq "" || [lsearch -exact $intended $current] >= 0} { continue }
    if {[regexp {^[[:space:]]*\+ LAYER Metal2 \( (-?[0-9]+) (-?[0-9]+) \) \( (-?[0-9]+) (-?[0-9]+) \)} $line -> ax1 ay1 ax2 ay2]} {
      set x1 [expr {max([$die xMin], int($ax1*$scale))}]
      set y1 [expr {max([$die yMin], int($ay1*$scale))}]
      set x2 [expr {min([$die xMax], int($ax2*$scale))}]
      set y2 [expr {min([$die yMax], int($ay2*$scale))}]
      lappend ::pad_spacing_obs [odb::dbObstruction_create $block $layer $x1 $y1 $x2 $y2]
      incr created
    }
  }
  puts "PAD_SPACING_OBSTRUCTIONS $created"
}
proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  foreach obs $::pad_spacing_obs { catch {odb::dbObstruction_destroy $obs} }
  set ::pad_spacing_obs {}
}
proc apply_dont_use {} {
  set exclude_file $::pdk/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
  if {[file exists $exclude_file]} {
    set ef [open $exclude_file r]
    while {[gets $ef line] >= 0} {
      set line [string trim $line]
      if {$line eq "" || [string match "#*" $line]} { continue }
      set cells [get_lib_cells -quiet $line]
      if {[llength $cells]} { set_dont_use $cells }
    }
    close $ef
  }
  catch {set_dont_use [get_lib_cells *bufz_*]}
  catch {set_dont_use [get_lib_cells *antenna]}
  catch {set_dont_use [get_lib_cells {*/*aoi221_2}]}
}
proc protect_specials {} {
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    if {[regexp {^(clkbuf|delaybuf|clkload|cts)} $n]} { catch {set_dont_touch $n} }
    if {[string match "ach_tie_*" $n] || [string match "ach_rx_load_*" $n]} {
      catch {set_dont_touch $n}
    }
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { catch {set_dont_touch $n} }
  }
}
proc load_ss {odb} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $::pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
  read_liberty -corner $c $::pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
  read_db $odb
  read_sdc $::proto/physical/constraints.sdc
  set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
  set_propagated_clock [all_clocks]
  pg_connect
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
}
proc legalize {} {
  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap gf180mcu_fd_sc_mcu9t5v0__antenna} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  if {[catch {detailed_placement -max_displacement {2000 400}} m]} {
    puts "DPL_RETRY $m"
    detailed_placement -max_displacement {5000 800}
  }
  if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
  puts "CHECK_PLACEMENT_OK"
  pg_connect
}

if {$phase eq "prep"} {
  read_db $proto/physical/results/native_power_ring_ach/ach_applied.odb
  pg_connect
  ensure_m2_obs
  rename_ach_output_nets
  destroy_signal_wires
  puts "BTERMS [llength [[ord::get_db_block] getBTerms]] INST [inst_count]"
  write_db $out/ach_preroute.odb
  write_def $out/ach_preroute.def
  puts "WROTE_ACH_PREROUTE"
  exit 0
}

if {$phase eq "grt"} {
  load_ss $out/ach_preroute.odb
  apply_dont_use
  protect_specials
  estimate_parasitics -placement
  puts "PLACE_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  puts "GRT1"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 25
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "GRT1_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/grt1.odb
  write_guides $out/grt1.guide
  puts "WROTE_GRT1"
  exit 0
}

if {$phase eq "repair"} {
  load_ss $out/grt1.odb
  apply_dont_use
  protect_specials
  estimate_parasitics -global_routing
  puts "REPAIR_BEFORE INST [inst_count]"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "REPAIR_DESIGN"
  if {[catch {repair_design -verbose -max_wire_length 250 -slew_margin 40 -cap_margin 40} m]} {
    puts "REPAIR_DESIGN_CAUGHT $m"
  }
  puts "AFTER_DESIGN INST [inst_count]"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  puts "REPAIR_TIMING_SETUP"
  # GRT WNS is already +2.16 ns; extracted DRT previously lost several ns.
  # Ask repair_timing for +3 ns estimated slack as DRT headroom.
  if {[catch {
    repair_timing -setup -verbose -setup_margin 3.0 -repair_tns 100 \
      -max_buffer_percent 40 -max_utilization 85 -sequence buffer \
      -skip_vt_swap
  } m]} { puts "REPAIR_BUFFER_CAUGHT $m" }
  if {[catch {
    repair_timing -setup -verbose -setup_margin 3.0 -repair_tns 100 \
      -max_buffer_percent 40 -max_utilization 85 -sequence sizeup \
      -skip_vt_swap
  } m]} { puts "REPAIR_SIZEUP_CAUGHT $m" }
  puts "AFTER_REPAIR INST [inst_count]"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  legalize
  write_db $out/repaired.odb
  puts "WROTE_REPAIRED"
  exit 0
}

if {$phase eq "grt2"} {
  load_ss $out/repaired.odb
  apply_dont_use
  protect_specials
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  puts "GRT2"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 25
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "GRT2_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/grt2.odb
  write_guides $out/grt2.guide
  puts "WROTE_GRT2"
  exit 0
}

if {$phase eq "drt"} {
  load_ss $out/grt2.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  puts "DRT DIODE [diode_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/final.drc
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "ANT_AFTER $ant DIODE [diode_count]"
  if {$ant} {
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
    puts "REPAIR_ANTENNAS $inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/ant.drc
    remove_pad_spacing_obs
    set ant [check_antennas]
    puts "ANT_AFTER2 $ant DIODE [diode_count]"
  }
  write_db $out/routed.odb
  write_def $out/routed.def
  puts "WROTE_ROUTED"
  exit 0
}

if {$phase eq "antdump"} {
  read_db $out/routed.odb
  pg_connect
  file mkdir $out/antenna
  set ant [check_antennas -verbose -report_file $out/antenna/remaining.rpt]
  puts "ANT $ant DIODE [diode_count] BTERMS [llength [[ord::get_db_block] getBTerms]] INST [inst_count]"
  exit 0
}

if {$phase eq "ant"} {
  load_ss $out/routed.odb
  pg_connect
  ensure_m2_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  file mkdir $out/antenna
  puts "ANT_BEFORE DIODE [diode_count]"
  set ant [check_antennas -verbose -report_file $out/antenna/before_ant2.rpt]
  puts "ANT_BEFORE_RC $ant"
  if {$ant} {
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 20]
    puts "REPAIR_ANTENNAS2 $inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed 43 -verbose 1 -output_drc $out/drt/ant2.drc
    remove_pad_spacing_obs
    set ant [check_antennas -verbose -report_file $out/antenna/after_ant2.rpt]
    puts "ANT_AFTER3 $ant DIODE [diode_count]"
  }
  write_db $out/routed_ant.odb
  write_def $out/routed_ant.def
  puts "WROTE_ROUTED_ANT"
  exit 0
}

if {$phase eq "spefrepair"} {
  set src $out/filled.odb
  if {[info exists env(SPEF_SRC)] && $env(SPEF_SRC) ne ""} { set src $env(SPEF_SRC) }
  set spef_in $out/spef/final.max.spef
  if {[info exists env(SPEF_IN)] && $env(SPEF_IN) ne ""} { set spef_in $env(SPEF_IN) }
  puts "SPEF_REPAIR_SRC $src"
  puts "SPEF_IN $spef_in"
  load_ss $src
  apply_dont_use
  protect_specials
  catch {remove_fillers}
  pg_connect
  if {![file exists $spef_in]} { puts "MISSING_SPEF $spef_in"; exit 1 }
  # Guides + SPEF repair SIGSEGVs this OpenROAD (GRouteDbCbk). The proven
  # +0.437 ns experiment cleared guides first.
  foreach net [[ord::get_db_block] getNets] { catch {$net clearGuides} }
  read_spef -corner max_ss_125C_4v50 $spef_in
  puts "SPEF_BEFORE INST [inst_count] DIODE [diode_count]"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  set bufcell gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  foreach pin {
    _20041_/Q
    _09461_/ZN
    _09462_/ZN
    rebuffer40/Z
    _09511_/ZN
    _15855_/ZN
    _15987_/ZN
    rebuffer46/Z
    _16112_/ZN
    clone22/ZN
  } {
    set loads [get_pins -quiet -of_objects [get_nets -of_objects [get_pins -quiet $pin]] -filter "direction == input"]
    puts "MANUAL_BUF $pin loads=[llength $loads]"
    if {[llength $loads] >= 2} {
      if {[catch {insert_buffer -buffer_cell $bufcell -load_pins $loads} m]} {
        puts "MANUAL_BUF_CAUGHT $pin $m"
      }
    }
  }
  if {[catch {
    repair_timing -setup -verbose -setup_margin 1.5 -repair_tns 100 \
      -max_buffer_percent 40 -max_utilization 85 -sequence buffer \
      -skip_vt_swap
  } m]} { puts "SPEF_BUFFER_CAUGHT $m" }
  puts "SPEF_AFTER_REPAIR INST [inst_count]"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  legalize
  destroy_signal_wires
  write_db $out/spef_repaired.odb
  puts "WROTE_SPEF_REPAIRED"
  exit 0
}

if {$phase eq "odbgrt"} {
  set src $out/odb_buf.odb
  if {[info exists env(ODBGRT_SRC)] && $env(ODBGRT_SRC) ne ""} { set src $env(ODBGRT_SRC) }
  puts "ODBGRT_SRC $src"
  load_ss $src
  apply_dont_use
  protect_specials
  pg_connect
  puts "ODBBUF_BEFORE_LEGAL INST [inst_count] DIODE [diode_count] BTERMS [llength [[ord::get_db_block] getBTerms]]"
  legalize
  destroy_signal_wires
  estimate_parasitics -placement
  puts "ODBBUF_PLACE_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set adj 0.3
  if {[info exists env(LAYER_ADJ)] && $env(LAYER_ADJ) ne ""} { set adj $env(LAYER_ADJ) }
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer $adj }
  set_thread_count 16
  puts "ODBBUF_GRT ADJ $adj"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 50 -resistance_aware
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "ODBBUF_GRT_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/${odb_tag}_grt.odb
  write_guides $out/${odb_tag}_grt.guide
  puts "WROTE_ODBBUF_GRT"
  exit 0
}

if {$phase eq "odbdrt"} {
  load_ss $out/${odb_tag}_grt.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  set seed 13
  if {[info exists env(OR_SEED)] && $env(OR_SEED) ne ""} { set seed $env(OR_SEED) }
  puts "ODBBUF_DRT DIODE [diode_count] INST [inst_count] SEED $seed"
  detailed_route -droute_end_iter 64 -or_seed $seed -verbose 1 -output_drc $out/drt/${odb_tag}.drc
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "ODBBUF_ANT_AFTER $ant DIODE [diode_count]"
  set pass 0
  while {$ant && $pass < 3} {
    incr pass
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
    puts "ODBBUF_REPAIR_ANT pass=$pass inserted=$inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed [expr {13 + $pass}] -verbose 1 -output_drc $out/drt/odbbuf_ant${pass}.drc
    remove_pad_spacing_obs
    set ant [check_antennas]
    puts "ODBBUF_ANT_AFTER_PASS$pass $ant DIODE [diode_count]"
  }
  write_db $out/${odb_tag}_routed.odb
  write_def $out/${odb_tag}_routed.def
  puts "WROTE_ODBBUF_ROUTED ANT $ant"
  exit 0
}

if {$phase eq "spefgrt"} {
  load_ss $out/spef_repaired.odb
  apply_dont_use
  protect_specials
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  puts "SPEF_GRT"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 50 -resistance_aware
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "SPEF_GRT_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/spef_grt.odb
  write_guides $out/spef_grt.guide
  puts "WROTE_SPEF_GRT"
  exit 0
}

if {$phase eq "spefdrt"} {
  load_ss $out/spef_grt.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  puts "SPEF_DRT DIODE [diode_count] INST [inst_count]"
  detailed_route -droute_end_iter 64 -or_seed 11 -verbose 1 -output_drc $out/drt/spef.drc
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "SPEF_ANT_AFTER $ant DIODE [diode_count]"
  set pass 0
  while {$ant && $pass < 3} {
    incr pass
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
    puts "SPEF_REPAIR_ANT pass=$pass inserted=$inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed [expr {11 + $pass}] -verbose 1 -output_drc $out/drt/spef_ant${pass}.drc
    remove_pad_spacing_obs
    set ant [check_antennas]
    puts "SPEF_ANT_AFTER_PASS$pass $ant DIODE [diode_count]"
  }
  write_db $out/spef_routed.odb
  write_def $out/spef_routed.def
  puts "WROTE_SPEF_ROUTED ANT $ant"
  exit 0
}

proc destroy_antenna_diodes {} {
  set doomed {}
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} {
      lappend doomed $inst
    }
  }
  foreach inst $doomed {
    catch {$inst setDoNotTouch 0}
    catch {unset_dont_touch [$inst getName]}
    if {[catch {odb::dbInst_destroy $inst} m]} {
      puts "DIODE_DESTROY_FAIL [$inst getName] $m"
    }
  }
  puts "DESTROYED_DIODES [llength $doomed] REMAINING [diode_count]"
}

# Recreate the proven 25-buffer topology by routing setup_buf_pre_drt.odb
# from scratch (destroy signal wires, keep PDN/ACH/buffers). Do NOT
# incremental-DRT those buffers onto an already-finished route.
if {$phase eq "buf25grt"} {
  load_ss $proto/physical/results/native_power_ring_ach/setup_buf_pre_drt.odb
  apply_dont_use
  protect_specials
  puts "BUF25_INST_BEFORE_FILLER [inst_count] DIODE [diode_count]"
  catch {remove_fillers}
  pg_connect
  destroy_signal_wires
  puts "BUF25_INST_AFTER_FILLER [inst_count] DIODE [diode_count] BTERMS [llength [[ord::get_db_block] getBTerms]]"
  estimate_parasitics -placement
  puts "BUF25_PLACE_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  puts "BUF25_GRT"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 25
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "BUF25_GRT_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/buf25_grt.odb
  write_guides $out/buf25_grt.guide
  puts "WROTE_BUF25_GRT"
  exit 0
}

if {$phase eq "buf25clean"} {
  load_ss $proto/physical/results/native_power_ring_ach/setup_buf_pre_drt.odb
  apply_dont_use
  catch {remove_fillers}
  destroy_antenna_diodes
  protect_specials
  pg_connect
  destroy_signal_wires
  puts "BUF25CLEAN_INST [inst_count] DIODE [diode_count] BTERMS [llength [[ord::get_db_block] getBTerms]]"
  estimate_parasitics -placement
  puts "BUF25CLEAN_PLACE_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
  set_thread_count 16
  puts "BUF25CLEAN_GRT"
  global_route -congestion_iterations 80 -verbose -critical_nets_percentage 25
  remove_pad_spacing_obs
  estimate_parasitics -global_routing
  puts "BUF25CLEAN_GRT_SETUP_WNS"
  report_worst_slack -max -digits 6
  report_tns -max -digits 6
  write_db $out/buf25clean_grt.odb
  write_guides $out/buf25clean_grt.guide
  puts "WROTE_BUF25CLEAN_GRT"
  exit 0
}

if {$phase eq "buf25cleandrt"} {
  load_ss $out/buf25clean_grt.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  puts "BUF25CLEAN_DRT DIODE [diode_count] INST [inst_count]"
  detailed_route -droute_end_iter 64 -or_seed 7 -verbose 1 -output_drc $out/drt/buf25clean.drc
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "BUF25CLEAN_ANT_AFTER $ant DIODE [diode_count]"
  set pass 0
  while {$ant && $pass < 3} {
    incr pass
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
    puts "BUF25CLEAN_REPAIR_ANT pass=$pass inserted=$inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed [expr {7 + $pass}] -verbose 1 -output_drc $out/drt/buf25clean_ant${pass}.drc
    remove_pad_spacing_obs
    set ant [check_antennas]
    puts "BUF25CLEAN_ANT_AFTER_PASS$pass $ant DIODE [diode_count]"
  }
  write_db $out/buf25clean_routed.odb
  write_def $out/buf25clean_routed.def
  puts "WROTE_BUF25CLEAN_ROUTED ANT $ant"
  exit 0
}

if {$phase eq "buf25drt"} {
  load_ss $out/buf25_grt.odb
  pg_connect
  ensure_m2_obs
  ensure_pad_spacing_obs
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  set_thread_count 16
  puts "BUF25_DRT DIODE [diode_count] INST [inst_count]"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/buf25.drc
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "BUF25_ANT_AFTER $ant DIODE [diode_count]"
  set pass 0
  while {$ant && $pass < 3} {
    incr pass
    set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
    puts "BUF25_REPAIR_ANTENNAS pass=$pass inserted=$inserted DIODE [diode_count]"
    catch {detailed_placement -max_displacement {500 100}}
    ensure_pad_spacing_obs
    detailed_route -droute_end_iter 64 -or_seed [expr {42 + $pass}] -verbose 1 -output_drc $out/drt/buf25_ant${pass}.drc
    remove_pad_spacing_obs
    set ant [check_antennas]
    puts "BUF25_ANT_AFTER_PASS$pass $ant DIODE [diode_count]"
  }
  write_db $out/buf25_routed.odb
  write_def $out/buf25_routed.def
  puts "WROTE_BUF25_ROUTED ANT $ant"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
