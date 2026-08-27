# Standard-cell filler insertion on the final ECO ODB (LibreLane FillInsertion).
set pdk /foss/pdks/gf180mcuD
set eco /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/nw_pins_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
if {[info exists env(FILL_ODB)] && $env(FILL_ODB) ne ""} {
  set src_odb $env(FILL_ODB)
} else {
  set src_odb $eco/hold_eco/routed.odb
}
puts "FILL_SRC $src_odb"
read_db $src_odb
set fillers {
  gf180mcu_fd_sc_mcu9t5v0__fillcap_64
  gf180mcu_fd_sc_mcu9t5v0__fillcap_32
  gf180mcu_fd_sc_mcu9t5v0__fillcap_16
  gf180mcu_fd_sc_mcu9t5v0__fillcap_8
  gf180mcu_fd_sc_mcu9t5v0__fillcap_4
  gf180mcu_fd_sc_mcu9t5v0__fill_64
  gf180mcu_fd_sc_mcu9t5v0__fill_32
  gf180mcu_fd_sc_mcu9t5v0__fill_16
  gf180mcu_fd_sc_mcu9t5v0__fill_8
  gf180mcu_fd_sc_mcu9t5v0__fill_4
  gf180mcu_fd_sc_mcu9t5v0__fill_2
  gf180mcu_fd_sc_mcu9t5v0__fill_1
}
filler_placement $fillers
if {[catch {global_connect} gcmsg]} { puts "GLOBAL_CONNECT $gcmsg" }
if {[info exists env(FILL_OUT)] && $env(FILL_OUT) ne ""} {
  set fill_out $env(FILL_OUT)
} else {
  set fill_out $eco/hold_eco
}
file mkdir $fill_out
set nfill 0
foreach inst [[ord::get_db_block] getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match *fill* $m] || [string match *fillcap* $m]} { incr nfill }
}
puts "N_FILLISH $nfill"
write_db $fill_out/routed_filled.odb
write_def $fill_out/routed_filled.def
write_verilog -include_pwr_gnd $fill_out/butterfold_top.filled.pnl.v
puts "FILL_OUT $fill_out"
puts "FILL_DONE"
exit
