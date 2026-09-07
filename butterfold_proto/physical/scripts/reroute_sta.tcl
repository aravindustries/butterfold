# Re-extract and re-STA the routed post-ECO database, max-SS setup and
# min-FF hold, the two signoff corners of record.
set odb $::env(OUT_DIR)/route/routed.odb
file mkdir $::env(OUT_DIR)/spef_final

read_db $odb
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file $::env(RCX_MAX) -lef_res
write_spef $::env(OUT_DIR)/spef_final/butterfold_top.max.spef
extract_parasitics -ext_model_file $::env(RCX_MIN) -lef_res
write_spef $::env(OUT_DIR)/spef_final/butterfold_top.min.spef
puts "X_SPEF_WRITTEN"
