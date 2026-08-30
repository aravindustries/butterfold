# Electrical ECO for resized ACH validation.
# Setup/hold are already extracted-closed. Do NOT run broad repair_timing.
# Insert buffers for slew/cap (including rst_n), legalize, then route fresh.
#
# PHASE=eco|drt
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/d03_ach_resized
file mkdir $out
file mkdir $out/drt
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
set src_odb $out/routed.odb
set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
set lib_ss $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
set lib_sram_ss $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib

set phase eco
if {[info exists env(PHASE)] && $env(PHASE) ne ""} { set phase $env(PHASE) }
puts "ELEC_PHASE $phase"

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

proc aoi221_2_mx {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    set m [[$inst getMaster] getName]
    if {$m eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
      set o [$inst getOrient]
      if {$o eq "MX" || $o eq "MY"} {
        incr n
        puts "AOI221_2_FAILORI [$inst getName] $o"
      }
    }
  }
  puts "AOI221_2_FAILORI_COUNT $n"
  return $n
}

proc load_ss {odb} {
  set c max_ss_125C_4v50
  define_corners $c
  read_liberty -corner $c $::lib_ss
  read_liberty -corner $c $::lib_sram_ss
  read_db $odb
  read_sdc $::sdc
  set_propagated_clock [all_clocks]
  set_wire_rc -signal -layer Metal2
  set_wire_rc -clock -layer Metal2
}

proc protect_specials {} {
  foreach inst [[ord::get_db_block] getInsts] {
    set n [$inst getName]
    set m [[$inst getMaster] getName]
    if {[regexp {^(clkbuf|delaybuf|clkload)} $n]} { catch {set_dont_touch $n} }
    if {[string match "*__antenna" $m]} {
      catch {set_dont_touch $n}
      $inst setPlacementStatus FIRM
    }
  }
}

proc destroy_signal_wires {} {
  set block [ord::get_db_block]
  foreach net [$block getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}

proc connect_pg {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}

if {$phase eq "eco"} {
  load_ss $src_odb
  if {[file exists $out/spef/butterfold_top.max.spef]} {
    read_spef -corner max_ss_125C_4v50 $out/spef/butterfold_top.max.spef
  }
  protect_specials
  catch {unset_case_analysis rst_n}
  catch {unset_case_analysis [get_ports rst_n]}
  set block [ord::get_db_block]
  puts "E_BEFORE_INST [llength [$block getInsts]]"
  puts "E_BEFORE_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  report_worst_slack -max -digits 6

  set exclude_file $pdk/libs.tech/librelane/gf180mcu_fd_sc_mcu9t5v0/drc_exclude.cells
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

  puts "E_REPAIR_DESIGN"
  if {[catch {
    repair_design -verbose -max_wire_length 0 -slew_margin 20 -cap_margin 20
  } rmsg]} {
    puts "E_REPAIR_DESIGN_CAUGHT $rmsg"
  }
  puts "E_AFTER_DESIGN_SLEW [sta::max_slew_violation_count] CAP [sta::max_capacitance_violation_count]"
  report_worst_slack -max -digits 6
  puts "E_AFTER_INST [llength [$block getInsts]]"

  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  catch {remove_fillers}
  if {[catch {detailed_placement -max_displacement {2000 400}} pmsg]} {
    puts "E_PLACE_RETRY $pmsg"
    detailed_placement -max_displacement {5000 800}
  }
  if {[catch {check_placement -verbose} cmsg]} { puts "E_PLACE $cmsg"; exit 1 }
  puts "E_CHECK_PLACEMENT_OK"
  connect_pg
  aoi221_2_mx
  write_db $out/elec_prelegal.odb

  destroy_signal_wires
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  set_thread_count 16
  puts "E_GRT"
  global_route -congestion_iterations 50 -verbose
  write_db $out/elec_grt.odb
  write_def $out/elec_grt.def
  puts "E_PHASE_ECO_DONE"
  exit 0
}

if {$phase eq "drt"} {
  read_db $out/elec_grt.odb
  aoi221_2_mx
  set_thread_count 16
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  puts "E_DRT"
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/elec.drc
  puts "E_ANT_BEFORE DIODE [diode_count]"
  check_antennas
  write_db $out/elec_routed.odb
  write_def $out/elec_routed.def
  puts "E_DRT_DONE DIODE [diode_count]"
  exit 0
}

puts "UNKNOWN_PHASE $phase"
exit 1
