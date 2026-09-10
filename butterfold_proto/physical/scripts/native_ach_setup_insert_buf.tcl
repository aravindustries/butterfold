# Targeted insert_buffer on the shared fft128_active cone, using incremental GRT.
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
proc buf_driver {drv_pin bufcell} {
  set p [get_pins $drv_pin]
  if {$p eq ""} { puts "MISSING_PIN $drv_pin"; return 0 }
  set loads [get_pins -quiet -of_objects [get_nets -of_objects $p] -filter "direction == input"]
  puts "INSERT $drv_pin loads=[llength $loads] cell=$bufcell"
  if {[llength $loads] < 2} { return 0 }
  if {[catch {
    insert_buffer -buffer_cell $bufcell -load_pins $loads
  } m]} {
    puts "INSERT_CAUGHT $drv_pin $m"
    return 0
  }
  return 1
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
catch {remove_fillers}
pg_connect
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal2
read_spef -corner $c $out/pre_timing_checkpoint/final.max.spef
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
set_thread_count 16
puts "GRT_START_INCREMENTAL"
if {[catch {global_route -start_incremental} m]} { puts "GRT_START_CAUGHT $m" }
puts "SETUP_BEFORE"
report_worst_slack -max -digits 6
report_tns -max -digits 6
set nbuf 0
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
  incr nbuf [buf_driver $pin $bufcell]
}
puts "BUFFERS_INSERTED $nbuf"
puts "SETUP_AFTER_INSERT"
report_worst_slack -max -digits 6
report_tns -max -digits 6
set_placement_padding -global -left 1 -right 1
if {[catch {detailed_placement -max_displacement {40 8}} m]} { puts "DPL_CAUGHT $m" }
if {[catch {check_placement -verbose} m]} { puts "PLACE_WARN $m" } else { puts "CHECK_PLACEMENT_OK" }
pg_connect
puts "GRT_END_INCREMENTAL"
if {[catch {global_route -end_incremental -verbose} m]} { puts "GRT_END_CAUGHT $m" }
ensure_pad_spacing_obs
puts "DRT_INCR DIODE [diode_count]"
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/setup_insert.drc
remove_pad_spacing_obs
set ant [check_antennas]
puts "ANT_AFTER $ant DIODE [diode_count]"
write_db $out/setup_buf_routed.odb
write_def $out/setup_buf_routed.def
puts "WROTE_SETUP_BUF_ROUTED"
exit
