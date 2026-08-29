set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco35
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src/butterfold_top_co6a36_teco31.odb
set block [ord::get_db_block]
set nnull 0
set nsig 0
foreach n [$block getNets] {
  if {[$n isSpecial]} continue
  set st [$n getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} continue
  incr nsig
  set w [$n getWire]
  if {$w eq "NULL" || $w eq ""} {
    incr nnull
    if {$nnull <= 15} { puts "NULLNET [$n getName] terms=[llength [$n getITerms]]" }
  }
}
puts "SIGNAL_NETS $nsig NULL_WIRES $nnull"
if {[catch {check_antennas -report_file $src/antenna.rpt} msg]} { puts "ANT_WARN $msg" }
write_def $src/butterfold_top_co6a36_teco31.def
puts "DEF_DONE"
exit
