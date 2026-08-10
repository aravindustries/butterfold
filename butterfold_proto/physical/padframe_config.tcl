set phys_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize "$phys_dir/.."]
set pdk_root /foss/pdks/gf180mcuD
set tech_lef "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"
set cell_lef "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef"
set sram_lef "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
set io_root "$pdk_root/libs.ref/gf180mcu_fd_io"
set io_site_lef "$phys_dir/gf180_io_sites.lef"
set cell_lib "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib"
set sram_lib "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib"
set io_lib "$io_root/lib/gf180mcu_fd_io__ss_125C_4v50.lib"
set mapped_core "$root_dir/timing/results/butterfold_mapped.v"
set wrapper "$root_dir/butterfold_padframe_top.sv"
set pad_sdc "$phys_dir/padframe_constraints.sdc"
set pad_result "$phys_dir/results/padframe/route"
file mkdir $pad_result
set die_w 2235.0
set die_h 2235.0
set core_ll 370.0
set core_ur 1865.0
set site GF018hv5v_green_sc9
set target_density 0.40
set lo_inst {u_core/u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram}
set hi_inst {u_core/u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram}
set pad_stage [expr {[info exists ::env(PADFRAME_STAGE)] ? $::env(PADFRAME_STAGE) : "route"}]

set io_lefs {}
foreach master {in_c bi_t dvdd dvss cor fill10 fill5 fill1 fillnc brk2 brk5} {
  lappend io_lefs "$io_root/lef/gf180mcu_fd_io__${master}.lef"
}
