set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set bt [$block findBTerm rst_n]
set box [$bt getBBox]
puts "BTERM rst_n [expr [$box xMin]*1.0/$dbu] [expr [$box yMin]*1.0/$dbu] [expr [$box xMax]*1.0/$dbu] [expr [$box yMax]*1.0/$dbu]"
set pin [$bt getBPin]
if {$pin ne "NULL"} {
  foreach box [$pin getBoxes] {
    puts "PINBOX [expr [$box xMin]*1.0/$dbu] [expr [$box yMin]*1.0/$dbu] [expr [$box xMax]*1.0/$dbu] [expr [$box yMax]*1.0/$dbu] layer=[[$box getTechLayer] getName]"
  }
}
# core die
puts "DIE [[$block getDieArea] xMin]..[[$block getDieArea] xMax]"
exit
