# Init GRT callbacks, then use extracted SPEF for repair_timing.
read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_pg_eco/butterfold_top.odb
read_liberty /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_sdc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/d03_ach_pnr_pad4_gds/08-openroad-fillinsertion/butterfold_top.sdc
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
# Drop stale guides so FastRoute actually builds trees.
set block [ord::get_db_block]
foreach net [$block getNets] {
  if {[$net isSpecial]} { continue }
  foreach guide [$net getGuides] {
    odb::dbGuide_destroy $guide
  }
}
global_route -congestion_iterations 50 -allow_congestion
read_spef /headless/aravindustries-repos/butterfold/butterfold_proto/physical/librelane/runs/d03_ach_pnr_pad4_gds/10-openroad-rcx/max/butterfold_top.max.spef
puts "ECO_SPEF_WNS"
report_wns
report_tns
repair_timing -setup -repair_tns 100 -skip_pin_swap -skip_gate_cloning
puts "ECO_POST_REPAIR"
report_wns
report_tns
file mkdir /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_setup_eco
write_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_setup_eco/repaired.odb
write_def /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_setup_eco/repaired.def
puts ECO_DONE
