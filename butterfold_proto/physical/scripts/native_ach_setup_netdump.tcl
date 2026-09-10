# Cap/fanout of the shared setup-trunk pins.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
set pdk /foss/pdks/gf180mcuD
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $out/filled.odb
read_sdc $proto/physical/constraints.sdc
set_output_delay 0.0 -clock core_clk [get_ports {din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]}]
set_propagated_clock [all_clocks]
read_spef -corner $c $out/spef/final.max.spef
set pins {
  _20041_/Q _09396_/ZN _09416_/ZN _09456_/ZN _09461_/ZN _09462_/ZN
  _09472_/ZN rebuffer40/Z _09511_/ZN _09513_/ZN _09519_/ZN _09541_/ZN
  _15855_/ZN _15942_/ZN _15987_/ZN _16106_/ZN rebuffer46/Z _16112_/ZN
  clone22/ZN _16180_/Z
}
foreach pin $pins {
  if {[catch {
    set p [get_pins $pin]
    set n [get_nets -of_objects $p]
    set nn [get_property $n full_name]
    set loads [get_pins -quiet -of_objects $n -filter "direction == input"]
    puts "NET $nn pin=$pin nloads=[llength $loads]"
    report_net $n
  } m]} {
    puts "PIN_FAIL $pin $m"
  }
}
puts "NETDUMP_DONE"
exit
