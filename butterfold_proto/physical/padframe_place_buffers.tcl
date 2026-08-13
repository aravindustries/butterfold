# Keep the weak pad receiver output route short.  Coordinates are snapped to
# GF018hv5v_green_sc9 rows inside the west/north core boundary.
set y 498.96
foreach stem {valid din0 din1 din2 din3 din4 din5 din6 din7} {
  place_inst -name "u_${stem}_iso" -origin [list 375.20 $y] -orientation R0 -status FIRM
  place_inst -name "u_${stem}_drive" -origin [list 400.40 $y] -orientation R0 -status FIRM
  set y [expr {$y + 75.60}]
}
place_inst -name u_clk_iso  -origin {900.48 1854.72} -orientation R0 -status FIRM
place_inst -name u_rst_iso  -origin {1000.16 1854.72} -orientation R0 -status FIRM
place_inst -name u_rst_root -origin {1025.36 1854.72} -orientation R0 -status FIRM
