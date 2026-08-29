set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
puts "NLIB [llength [get_lib_cells *]]"
set n 0
foreach c [get_lib_cells *] {
  incr n
  if {$n <= 15 || [string match "*clkbuf*" [get_full_name $c]] || [string match "*clkbuf*" [get_name $c]]} {
    puts "CELL name=[get_name $c] full=[get_full_name $c] object=$c"
  }
}
puts "CLKBUF [get_lib_cells *clkbuf*]"
puts "DONE"
exit
