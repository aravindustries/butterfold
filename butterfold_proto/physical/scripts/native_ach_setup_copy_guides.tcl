# Export GRT guides from the clean checkpoint (existing wires).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/native_power_ring_ach
read_db $out/pre_timing_checkpoint/filled.odb
write_guides $out/checkpoint.guide
puts "WROTE_CHECKPOINT_GUIDE"
exit
