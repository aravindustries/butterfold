# AREA STUDY ONLY -- NOT FUNCTIONAL RTL.
# The default geometry is a gross-quarter planning scenario, not Padframe A.

set study_dir [file dirname [file normalize [info script]]]
set result_dir "$study_dir/results"
file mkdir $result_dir

set tech_lef /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
set cell_lef /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
set sram_dir /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef

read_lef $tech_lef
read_lef $cell_lef
read_lef "$sram_dir/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef"
read_lef "$sram_dir/gf180mcu_fd_ip_sram__sram512x8m8wm1.lef"
read_verilog "$study_dir/area_study_top.v"
link_design area_study_top

set core_w [expr {[info exists ::env(STUDY_CORE_W)] ? $::env(STUDY_CORE_W) : 1117.5}]
set core_h [expr {[info exists ::env(STUDY_CORE_H)] ? $::env(STUDY_CORE_H) : 1117.5}]
set halo [expr {[info exists ::env(STUDY_HALO)] ? $::env(STUDY_HALO) : 20.0}]
set placement [expr {[info exists ::env(STUDY_PLACEMENT)] ? $::env(STUDY_PLACEMENT) : "A"}]

initialize_floorplan -die_area "0 0 $core_w $core_h" \
  -core_area "0 0 $core_w $core_h" -site GF018hv5v_green_sc9

# Coordinates include the selected geometric halo from the scenario boundary.
if {$placement eq "A"} {
  # Adjacent parallel FFT macros; waveform macro below the left FFT macro.
  set fft_lo_xy [list $halo $halo]
  set fft_hi_xy [list [expr {$halo + 431.86 + 2*$halo}] $halo]
  set wave_xy [list $halo [expr {$halo + 340.88 + 2*$halo}]]
  set fft_lo_or R0
  set fft_hi_or R0
  set wave_or R0
} elseif {$placement eq "B"} {
  # Vertically stacked FFT pair beside the waveform macro.
  set fft_lo_xy [list $halo $halo]
  set fft_hi_xy [list $halo [expr {$halo + 340.88 + 2*$halo}]]
  set wave_xy [list [expr {$halo + 431.86 + 2*$halo}] $halo]
  set fft_lo_or R0
  set fft_hi_or R0
  set wave_or R0
} elseif {$placement eq "C"} {
  # Rotated FFT pair stacked at left; waveform macro at right.
  # R90's DEF origin is the rotated macro's lower-right corner, so offset X
  # by the original macro height to keep the physical lower-left at $halo.
  set fft_lo_xy [list [expr {$halo + 340.88}] $halo]
  set fft_hi_xy [list [expr {$halo + 340.88}] [expr {$halo + 431.86 + 2*$halo}]]
  set wave_xy [list [expr {$halo + 340.88 + 2*$halo}] $halo]
  set fft_lo_or R90
  set fft_hi_or R90
  set wave_or R0
} else {
  error "Unknown STUDY_PLACEMENT '$placement'; use A, B, or C"
}

place_inst -name u_fft_lo -origin $fft_lo_xy -orientation $fft_lo_or -status FIRM
place_inst -name u_fft_hi -origin $fft_hi_xy -orientation $fft_hi_or -status FIRM
place_inst -name u_wave -origin $wave_xy -orientation $wave_or -status FIRM
# Keep the one standard-cell token on an exact GF018hv5v_green_sc9 site.
# These coordinates are valid for the default snapped 1117.20 x 1113.84 um
# scenario core and remain outside all macro/halo candidates.
place_inst -name u_row_token -origin {1116.64 1108.80} -orientation R0 -status PLACED

set tag "${placement}_h[format %.0f $halo]_[format %.1f $core_w]x[format %.1f $core_h]"
set check_report "$result_dir/check_${tag}.rpt"
file delete -force $check_report
check_placement -verbose -report_file_name $check_report
write_def "$result_dir/floorplan_${tag}.def"

puts "STUDY_ONLY placement=$placement halo_um=$halo core=${core_w}x${core_h}"
puts "FFT_LO origin=$fft_lo_xy orient=$fft_lo_or"
puts "FFT_HI origin=$fft_hi_xy orient=$fft_hi_or"
puts "WAVE origin=$wave_xy orient=$wave_or"
puts "NOTE: halo is planning geometry only; no routing blockage is asserted."
