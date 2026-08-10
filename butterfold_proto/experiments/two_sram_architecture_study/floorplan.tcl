# AREA STUDY ONLY -- NOT FUNCTIONAL RTL.
set here [file dirname [file normalize [info script]]]
set tech /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cells /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set macro /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_lef $tech
read_lef $cells
read_lef $macro
read_verilog $here/floorplan_top.v
link_design two_sram_floorplan_top
set halo [expr {[info exists ::env(STUDY_HALO)] ? $::env(STUDY_HALO) : 20.0}]
initialize_floorplan -die_area {0 0 1117.5 1117.5} -core_area {0 0 1117.5 1117.5} -site GF018hv5v_green_sc9
place_inst -name u_fft_lo -origin [list $halo $halo] -orientation R0 -status FIRM
place_inst -name u_fft_hi -origin [list [expr {$halo+431.86+2*$halo}] $halo] -orientation R0 -status FIRM
place_inst -name u_row_token -origin {1116.64 1108.80} -orientation R0 -status PLACED
check_placement -verbose -report_file_name $here/results/floorplan_h[format %.0f $halo].rpt
write_def $here/results/floorplan_h[format %.0f $halo].def
puts "TWO_SRAM_STUDY halo=$halo adjacent_macros=R0"
