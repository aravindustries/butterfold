# Targeted setup ECO: buffer the shared fft128_active cone. No PDN change,
# no ACH BTerm change, no destroy_signal_wires / full GRT.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set pdk /foss/pdks/gf180mcuD
set src $out/pre_timing_checkpoint/filled.odb
puts "ECO_SRC $src"

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
    set m [[$inst getMaster] getName]
    if {[string match "*__antenna" $m]} { catch {set_dont_touch $n} }
  }
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
  foreach line [split $text "\n"] {
    if {[regexp {^- ([^ ]+) } $line -> name]} { set current $name }
    if {$current eq "" || [lsearch -exact $intended $current] >= 0} { continue }
    if {[regexp {^[[:space:]]*\+ LAYER Metal2 \( (-?[0-9]+) (-?[0-9]+) \) \( (-?[0-9]+) (-?[0-9]+) \)} $line -> ax1 ay1 ax2 ay2]} {
      set x1 [expr {max([$die xMin], int($ax1*$scale))}]
      set y1 [expr {max([$die yMin], int($ay1*$scale))}]
      set x2 [expr {min([$die xMax], int($ax2*$scale))}]
      set y2 [expr {min([$die yMax], int($ay2*$scale))}]
      lappend ::pad_spacing_obs [odb::dbObstruction_create $block $layer $x1 $y1 $x2 $y2]
    }
  }
}
proc remove_pad_spacing_obs {} {
  if {![info exists ::pad_spacing_obs]} { return }
  foreach obs $::pad_spacing_obs { catch {odb::dbObstruction_destroy $obs} }
}

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
pg_connect
puts "INST_BEFORE_FILLER_REMOVAL [inst_count]"
catch {remove_fillers}
pg_connect
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $c $out/pre_timing_checkpoint/final.max.spef
apply_dont_use
protect_specials
puts "SETUP_BEFORE"
report_worst_slack -max -digits 6
report_tns -max -digits 6
puts "INST_BEFORE_REPAIR [inst_count] DIODE [diode_count]"
puts "REPAIR_TIMING_BUFFER"
if {[catch {
  repair_timing -setup -verbose -setup_margin 0.40 -repair_tns 100 \
    -max_buffer_percent 40 -max_utilization 85 -sequence buffer \
    -skip_vt_swap -skip_size_down
} m]} { puts "REPAIR_BUFFER_CAUGHT $m" }
puts "SETUP_AFTER_BUFFER"
report_worst_slack -max -digits 6
report_tns -max -digits 6
puts "INST_AFTER_REPAIR [inst_count] DIODE [diode_count]"
set_placement_padding -global -left 1 -right 1
foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap gf180mcu_fd_sc_mcu9t5v0__antenna} {
  catch {set_placement_padding -masters $wildcard -right 0 -left 0}
}
if {[catch {detailed_placement -max_displacement {40 8}} m]} {
  puts "DPL_SMALL_CAUGHT $m"
}
if {[catch {check_placement -verbose} m]} { puts "PLACE_WARN $m" } else { puts "CHECK_PLACEMENT_OK" }
pg_connect
write_db $out/setup_buf_pre_drt.odb
ensure_pad_spacing_obs
set_thread_count 16
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
puts "DRT_INCR DIODE [diode_count]"
if {[catch {
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/setup_buf.drc
} m]} {
  puts "DRT_CAUGHT $m"
  remove_pad_spacing_obs
  write_db $out/setup_buf_pre_drt.odb
  exit 1
}
remove_pad_spacing_obs
set ant [check_antennas]
puts "ANT_AFTER $ant DIODE [diode_count]"
if {$ant} {
  set inserted [repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -ratio_margin 10]
  puts "REPAIR_ANTENNAS $inserted DIODE [diode_count]"
  catch {detailed_placement -max_displacement {40 8}}
  ensure_pad_spacing_obs
  if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/setup_buf_ant.drc} m]} {
    puts "DRT_ANT_CAUGHT $m"
    remove_pad_spacing_obs
    exit 1
  }
  remove_pad_spacing_obs
  set ant [check_antennas]
  puts "ANT_AFTER2 $ant DIODE [diode_count]"
}
write_db $out/setup_buf_routed.odb
write_def $out/setup_buf_routed.def
puts "WROTE_SETUP_BUF_ROUTED"
exit
