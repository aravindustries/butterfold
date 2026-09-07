# Extract max-corner parasitics from a post-DRT ODB (own session; OpenRCX
# must not share a session with the timing repair below).
read_db $::env(IN_ODB)
define_process_corner -ext_model_index 0 CURRENT_CORNER
extract_parasitics -ext_model_file $::env(RCX_RULES) -lef_res
file mkdir $::env(OUT_DIR)/spef
write_spef $::env(OUT_DIR)/spef/butterfold_top.max.spef
puts "WROTE_MAX_SPEF"
