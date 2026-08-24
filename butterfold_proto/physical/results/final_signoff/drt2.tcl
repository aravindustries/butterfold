read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_grt_diodes2.odb
set t0 [clock milliseconds]
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_diodes.drc
puts "DRT_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"
write_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.odb
write_def /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_routed.def
puts "WROTE_DRT"
