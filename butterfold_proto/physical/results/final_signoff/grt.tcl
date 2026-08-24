read_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_clean_unrouted.odb
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
global_connect
set t0 [clock milliseconds]
global_route -congestion_iterations 50 -verbose -guide_file /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top.guide
puts "GRT_RUNTIME_MS [expr {[clock milliseconds]-$t0}]"
write_db /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_grt.odb
write_def /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/final_signoff/butterfold_top_grt.def
puts "WROTE_GRT"
