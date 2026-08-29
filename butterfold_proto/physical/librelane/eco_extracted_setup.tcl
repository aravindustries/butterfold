# Extracted-aware setup repair on the D03/ACH routed candidate.
# Same OpenROAD repair_timing used by LibreLane, but with OpenRCX SPEF
# (LibreLane post-GRT repair only saw global-route RC).
set ::env(PL_MAX_DISPLACEMENT_X) 500
set ::env(PL_MAX_DISPLACEMENT_Y) 100
set ::env(PL_OPTIMIZE_MIRRORING) 1
set ::env(SCRIPTS_DIR) /usr/local/lib/python3.12/dist-packages/librelane/scripts

set src /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_pg_eco/butterfold_top.odb
set outdir /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_setup_eco
file mkdir $outdir

# Fresh session from DEF so GRT callbacks are not registered (swapMaster
# SIGSEGV on a routed ODB that still has GRouteDbCbk attached).
foreach lef {
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
  /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
} { read_lef $lef }
read_def /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_pg_eco/butterfold_top.def
set block [ord::get_db_block]

read_liberty /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_sdc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/d03_ach_pnr_pad4_gds/08-openroad-fillinsertion/butterfold_top.sdc
read_spef /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/d03_ach_pnr_pad4_gds/10-openroad-rcx/max/butterfold_top.max.spef

puts "ECO_PRE_WNS"
report_wns
report_tns
report_checks -path_delay max -format end -digits 4

foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    $inst setDoNotTouch 1
    $inst setPlacementStatus FIRM
  }
}

remove_fillers

set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
puts "ECO_REPAIR_TIMING_SETUP"
# SizeUpMove hits GRT swapMaster SIGSEGV on this OpenROAD build.
repair_timing -setup -repair_tns 100 -sequence buffer -skip_pin_swap -skip_gate_cloning
estimate_parasitics -placement

puts "ECO_POST_REPAIR_PLACEMENT_WNS"
report_wns
report_tns

set_placement_padding -global -left 2 -right 2
set_placement_padding -masters gf180mcu_fd_sc_mcu9t5v0__filltie -left 0 -right 0
set_placement_padding -masters gf180mcu_fd_sc_mcu9t5v0__endcap -left 0 -right 0
detailed_placement -max_displacement {500 100}
optimize_mirroring
check_placement -verbose

set filler_cells [list \
  gf180mcu_fd_sc_mcu9t5v0__fillcap_64 \
  gf180mcu_fd_sc_mcu9t5v0__fillcap_32 \
  gf180mcu_fd_sc_mcu9t5v0__fillcap_16 \
  gf180mcu_fd_sc_mcu9t5v0__fillcap_8 \
  gf180mcu_fd_sc_mcu9t5v0__fillcap_4 \
  gf180mcu_fd_sc_mcu9t5v0__fill_64 \
  gf180mcu_fd_sc_mcu9t5v0__fill_32 \
  gf180mcu_fd_sc_mcu9t5v0__fill_16 \
  gf180mcu_fd_sc_mcu9t5v0__fill_8 \
  gf180mcu_fd_sc_mcu9t5v0__fill_4 \
  gf180mcu_fd_sc_mcu9t5v0__fill_2 \
  gf180mcu_fd_sc_mcu9t5v0__fill_1]
filler_placement $filler_cells
check_placement -verbose

write_db $outdir/pre_reroute.odb
write_def $outdir/pre_reroute.def
puts "ECO_WROTE $outdir/pre_reroute.odb"
report_wns
report_tns
