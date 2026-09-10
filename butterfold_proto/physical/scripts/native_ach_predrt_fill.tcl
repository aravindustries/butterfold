# Stdcell fill on the pre-DRT timing-repair routed ODB.
# Writes ONLY under predrt/. Never overwrites the 80ef23f6 checkpoint.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach/predrt
set src $out/routed.odb
if {[info exists env(FILL_SRC)] && $env(FILL_SRC) ne ""} { set src $env(FILL_SRC) }
puts "FILL_SRC $src"
read_db $src
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
set db [ord::get_db]
set fills {}
set decaps {}
foreach lib [$db getLibs] {
  foreach m [$lib getMasters] {
    set n [$m getName]
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
    if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
  }
}
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
puts "FILL_LIST $fill_list"
catch {set_placement_padding -masters gf180mcu_fd_ip_sram__sram256x8m8wm1 -left 4 -right 4}
set block [ord::get_db_block]
set dbu [$block getDefUnits]
set halo [expr {int(4.48 * $dbu)}]
set bi 0
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match "*sram256x8*" $mn]} {
    set bb [$inst getBBox]
    incr bi
    catch {
      create_placement_blockage -name sram_halo_$bi -area [list \
        [expr {[$bb xMin] - $halo}] [expr {[$bb yMin] - $halo}] \
        [expr {[$bb xMax] + $halo}] [expr {[$bb yMax] + $halo}]]
    }
    puts "SRAM_HALO $mn [$bb xMin] [$bb yMin] [$bb xMax] [$bb yMax] halo_um 4.48"
  }
}
puts "SRAM_HALOS $bi"
set n0 [llength [[ord::get_db_block] getInsts]]
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
set n1 [llength [[ord::get_db_block] getInsts]]
puts "INST_BEFORE $n0 INST_AFTER $n1 ADDED [expr {$n1-$n0}]"
if {[catch {check_placement -verbose} m]} { puts "PLACE $m"; exit 1 }
puts "BTERMS [llength [[ord::get_db_block] getBTerms]]"
set ant [check_antennas]
puts "ANTENNA_CHECK $ant"
set tag filled
if {[info exists env(FILL_TAG)] && $env(FILL_TAG) ne ""} { set tag $env(FILL_TAG) }
write_db $out/${tag}.odb
write_def $out/${tag}.def
write_verilog -include_pwr_gnd $out/${tag}.pnl.v
write_verilog $out/${tag}.v
puts "FILL_TAG $tag"
puts "FILL_DONE"
exit
