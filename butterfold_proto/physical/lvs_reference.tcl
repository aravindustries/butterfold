source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]

set lvs_dir "$phys_dir/results/padframe/lvs"
file mkdir $lvs_dir
set physical_verilog "$phys_dir/results/padframe/route/butterfold_padframe_physical.v"
if {![file exists $physical_verilog]} {
  error "missing authoritative physical Verilog: $physical_verilog"
}

read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs { read_lef $lef }
read_verilog $physical_verilog
link_design butterfold_padframe_top
set block [ord::get_db_block]
if {[$block getName] ne "butterfold_padframe_top"} {
  error "unexpected routed top: [$block getName]"
}

set masters [list \
  "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/spice/gf180mcu_fd_sc_mcu9t5v0.spice" \
  "$pdk_root/libs.ref/gf180mcu_fd_io/spice/gf180mcu_fd_io.spice" \
  "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/spice/gf180mcu_fd_ip_sram__sram256x8m8wm1.spice"]
foreach master $masters {
  if {![file exists $master]} { error "missing LVS master CDL: $master" }
}

# OpenDB's CDL writer preserves the physical-Verilog connectivity, including
# CTS, timing-repair, pad, filler, tap, and macro instances.  The listed PDK
# CDL files supply authoritative leaf pin order and circuit definitions.
write_cdl -include_fillers -masters $masters "$lvs_dir/reference_physical.cdl"
