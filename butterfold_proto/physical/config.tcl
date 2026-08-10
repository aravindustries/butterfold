set phys_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize "$phys_dir/.."]
set pdk_root /foss/pdks/gf180mcuD

set tech_lef "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef"
set cell_lef "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef"
set cell_lib "$pdk_root/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib"
set sram_lef "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
set sram_lib "$pdk_root/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib"
set rc_rules "$pdk_root/libs.tech/librelane/rules.openrcx.gf180mcuD.nom"
set netlist "$root_dir/timing/results/butterfold_mapped.v"
set sdc "$phys_dir/constraints.sdc"

set core_w 1117.20
set core_h 1113.84
set macro_w 431.86
set macro_h 340.88
set macro_halo 20.0
set site GF018hv5v_green_sc9
set target_density 0.55

set lo_inst {u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram}
set hi_inst {u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram}
set arrangement [expr {[info exists ::env(MACRO_ARRANGEMENT)] ? $::env(MACRO_ARRANGEMENT) : "A"}]
set stage [expr {[info exists ::env(PHYS_STAGE)] ? $::env(PHYS_STAGE) : "route"}]
set result_dir "$phys_dir/results/$arrangement"
file mkdir $result_dir
