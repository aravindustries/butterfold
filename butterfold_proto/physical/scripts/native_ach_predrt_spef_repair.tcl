# SPEF-driven setup repair, then destroy signal wires so the repaired
# topology can be global+detail routed from scratch. Never incremental DRT.
# Invoked as: PHASE=spefrepair via native_ach_predrt_timing.tcl
# This wrapper exists so operators can find the strategy by name.
puts "Use PHASE=spefrepair on native_ach_predrt_timing.tcl"
exit 0
