# Export a stream-out DEF from the immutable authoritative routed ODB.
# This script validates the database before handing geometry to KLayout.
set phys_dir [file dirname [file normalize [info script]]]
set route_odb [file normalize "$phys_dir/results/padframe/route/route.odb"]
set output_def [expr {[info exists ::env(STREAMOUT_DEF)] \
    ? [file normalize $::env(STREAMOUT_DEF)] \
    : [file normalize "$phys_dir/results/padframe/gds/route_for_streamout.def"]}]

proc streamout_fail {message} {
  puts stderr "CANDIDATE_GDS_ERROR: $message"
  exit 1
}

if {![file exists $route_odb]} {
  streamout_fail "authoritative routed ODB missing: $route_odb"
}
file mkdir [file dirname $output_def]
read_db $route_odb
set block [ord::get_db_block]
if {$block eq "NULL" || [$block getName] ne "butterfold_padframe_top"} {
  streamout_fail "unexpected top block; expected butterfold_padframe_top"
}

array set masters {}
set routed_nets 0
foreach inst [$block getInsts] {
  set master [[$inst getMaster] getName]
  if {![info exists masters($master)]} { set masters($master) 0 }
  incr masters($master)
}
foreach net [$block getNets] {
  if {[$net getWire] ne "NULL"} { incr routed_nets }
}

set sram256 gf180mcu_fd_ip_sram__sram256x8m8wm1
set sram512 gf180mcu_fd_ip_sram__sram512x8m8wm1
if {![info exists masters($sram256)] || $masters($sram256) != 2} {
  streamout_fail "expected exactly two $sram256 instances"
}
if {[info exists masters($sram512)] && $masters($sram512) != 0} {
  streamout_fail "obsolete 512x8 SRAM is present"
}
foreach required {gf180mcu_fd_io__in_c gf180mcu_fd_io__bi_t \
                  gf180mcu_fd_io__dvdd gf180mcu_fd_io__dvss} {
  if {![info exists masters($required)] || $masters($required) == 0} {
    streamout_fail "required pad master missing: $required"
  }
}
if {$routed_nets == 0} {
  streamout_fail "database contains no routed nets"
}

puts "CANDIDATE_GDS_SOURCE_ODB=$route_odb"
puts "TOP=[$block getName]"
puts "INSTANCES=[llength [$block getInsts]]"
puts "ROUTED_NETS=$routed_nets"
puts "SRAM256_INSTANCES=$masters($sram256)"
puts "SRAM512_INSTANCES=[expr {[info exists masters($sram512)] ? $masters($sram512) : 0}]"
write_def $output_def
puts "STREAMOUT_DEF=$output_def"
