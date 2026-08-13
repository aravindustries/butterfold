source [file join [file dirname [file normalize [info script]]] config.tcl]

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef
read_db "$result_dir/floorplan.odb"

# Yosys names constant-one/constant-zero nets one_/zero_.  The SRAM supply
# pins are connected to those nets in the mapped handoff, so they are the
# physical power-domain aliases used by this implementation database.
add_global_connection -net one_ -inst_pattern .* -pin_pattern {VDD|VNW} -power
add_global_connection -net zero_ -inst_pattern .* -pin_pattern {VSS|VPW} -ground
global_connect
set_voltage_domain -name CORE -power one_ -ground zero_

define_pdn_grid -name core_grid -voltage_domains CORE -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal1 -followpins -width 0.48
add_pdn_stripe -grid core_grid -layer Metal4 -width 3.0 -pitch 80.0 \
  -offset 20.0 -starts_with POWER
add_pdn_stripe -grid core_grid -layer Metal5 -width 3.0 -pitch 80.0 \
  -offset 20.0 -starts_with GROUND
add_pdn_connect -grid core_grid -layers {Metal1 Metal4}
add_pdn_connect -grid core_grid -layers {Metal4 Metal5}

define_pdn_grid -name macro_grid -macro -cells gf180mcu_fd_ip_sram__sram256x8m8wm1 \
  -grid_over_pg_pins -voltage_domains CORE -starts_with POWER
add_pdn_connect -grid macro_grid -layers {Metal3 Metal4}

pdngen -failed_via_report "$result_dir/pdn_failed_vias.rpt"
check_power_grid -net one_ > "$result_dir/pdn_power_check.rpt"
check_power_grid -net zero_ > "$result_dir/pdn_ground_check.rpt"
write_db "$result_dir/pdn.odb"
write_def "$result_dir/pdn.def"
