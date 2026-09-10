# Apply the generated ACH integration shell to a hardened core.
# Creates 112 BTerms (102 pad-control ties + 10 disabled-receiver loads) and
# their driver cells, then legalizes.  Routing is NOT done here.
read_db $::env(BASE_ODB)
set block [ord::get_db_block]
puts "X_IN_BTERMS  [llength [$block getBTerms]]"
puts "X_IN_INST    [llength [$block getInsts]]"

# Tie cells are all emitted at one coordinate; fillers must go first so the
# legalizer has sites to spread them into.
catch {remove_fillers}
puts "X_AFTER_REMOVE_FILLERS_INST [llength [$block getInsts]]"

source $::env(SHELL_TCL)

puts "X_OUT_BTERMS [llength [$block getBTerms]]"
puts "X_OUT_INST   [llength [$block getInsts]]"

set_placement_padding -global -left 1 -right 1
foreach m {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_1
           gf180mcu_fd_sc_mcu9t5v0__fill_2 gf180mcu_fd_sc_mcu9t5v0__endcap} {
  catch {set_placement_padding -masters $m -left 0 -right 0}
}
detailed_placement -max_displacement {500 100}
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
write_db  $::env(OUT_DIR)/shell_placed.odb
write_def $::env(OUT_DIR)/shell_placed.def
puts "X_WROTE $::env(OUT_DIR)/shell_placed.odb"
if {[catch {check_placement -verbose} m]} { puts "X_PLACE_WARN $m" } else { puts "X_PLACE_OK" }
