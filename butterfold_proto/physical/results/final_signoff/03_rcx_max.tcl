read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file /foss/pdks/gf180mcuD/libs.tech/librelane/rules.openrcx.gf180mcuD.max -lef_res
file mkdir /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/spef
write_spef /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/spef/butterfold_top.max.spef
puts WROTE_MAX
