set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco8/butterfold_top_co6a36_teco4.odb
set block [ord::get_db_block]
foreach n [$block getNets] {
  set nn [$n getName]
  if {[string match *dft12_base* $nn] || [string match *dft12_phase* $nn] || [string match *fft128_active* $nn]} {
    set nterm [llength [$n getITerms]]
    puts "NET $nn terms=$nterm"
  }
}
# also list high-fanout > 40
puts "HIGH_FO"
foreach n [$block getNets] {
  if {[$n isSpecial]} continue
  set nt [llength [$n getITerms]]
  if {$nt >= 40} { puts "FO $nt [$n getName]" }
}
exit
