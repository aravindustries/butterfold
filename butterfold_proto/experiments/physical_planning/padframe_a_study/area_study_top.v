// AREA STUDY ONLY -- NOT FUNCTIONAL RTL.
// Three hard macros plus one token standard cell for OpenROAD row validation.
module area_study_top;
  gf180mcu_fd_ip_sram__sram256x8m8wm1 u_fft_lo();
  gf180mcu_fd_ip_sram__sram256x8m8wm1 u_fft_hi();
  gf180mcu_fd_ip_sram__sram512x8m8wm1 u_wave();
  gf180mcu_fd_sc_mcu9t5v0__fill_1 u_row_token();
endmodule

