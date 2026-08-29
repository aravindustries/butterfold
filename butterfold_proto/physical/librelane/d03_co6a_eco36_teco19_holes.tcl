set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco23/butterfold_top_co6a36_teco19_preroute.odb
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
foreach name {teco19_rst_root wire413 load_slew414 load_slew415 load_slew416} {
  set i [$block findInst $name]
  set b [$i getBBox]
  puts "CELL $name [[$i getMaster] getName] w=[expr ([$b xMax]-[$b xMin])*1.0/$dbu] bbox=[expr [$b xMin]*1.0/$dbu] [expr [$b yMin]*1.0/$dbu] [expr [$b xMax]*1.0/$dbu] [expr [$b yMax]*1.0/$dbu]"
  set hits 0
  foreach o [$block getInsts] {
    if {$o eq $i} continue
    set ob [$o getBBox]
    if {[$ob yMax] <= [$b yMin] || [$ob yMin] >= [$b yMax]} continue
    if {[$ob xMax] <= [$b xMin] || [$ob xMin] >= [$b xMax]} continue
    incr hits
    if {$hits <= 5} {
      puts "  OV [$o getName] [[$o getMaster] getName] [expr [$ob xMin]*1.0/$dbu]..[expr [$ob xMax]*1.0/$dbu]"
    }
  }
  puts "  OVERLAPS $hits"
}
puts "MASTER buf_16 w=[expr [[$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_16] getWidth]*1.0/$dbu]"
puts "MASTER buf_20 w=[expr [[$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_20] getWidth]*1.0/$dbu]"
# holes on wire413 row
set i [$block findInst wire413]
set y [[$i getBBox] yMin]
# snap y
set y [expr {int(928.6405/$dbu)*1}]
puts "wire413 yMin raw [expr [[$i getBBox] yMin]*1.0/$dbu]"
exit
