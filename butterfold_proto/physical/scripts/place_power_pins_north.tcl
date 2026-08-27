# Add NORTH-edge access on existing VDD/VSS ports after PDN exists.
# Overlaps the northernmost Metal4 PDN stripe so the pin is not an island.
# Usage: ECO_SRC=in.odb ECO_DST=out.odb openroad -no_init -exit physical/scripts/place_power_pins_north.tcl
set pdk /foss/pdks/gf180mcuD
if {![info exists env(ECO_SRC)] || $env(ECO_SRC) eq ""} {
    puts "ERROR set ECO_SRC"
    exit 1
}
set src $env(ECO_SRC)
set dst $src
if {[info exists env(ECO_DST)] && $env(ECO_DST) ne ""} { set dst $env(ECO_DST) }

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src

set block [ord::get_db_block]
set die [$block getDieArea]
set units [$block getDefUnits]
set yMax [$die yMax]
set xMax [$die xMax]
set yMax_um [expr {$yMax / double($units)}]

proc northernmost_metal4_x {bterm_name units} {
    set block [ord::get_db_block]
    set bterm [$block findBTerm $bterm_name]
    if {$bterm eq "" || $bterm eq "NULL"} { error "missing $bterm_name" }
    set best_y -1
    set best_x 0
    foreach bpin [$bterm getBPins] {
        foreach box [$bpin getBoxes] {
            set layer [[$box getTechLayer] getName]
            if {$layer ne "Metal4"} { continue }
            set uy [$box yMax]
            set mx [expr {([$box xMin] + [$box xMax]) / 2.0}]
            if {$uy > $best_y} {
                set best_y $uy
                set best_x $mx
            }
        }
    }
    if {$best_y < 0} { error "no Metal4 pin boxes on $bterm_name" }
    puts [format "NORTHMOST_M4 %s y_um=%.3f x_um=%.3f" $bterm_name [expr {$best_y / double($units)}] [expr {$best_x / double($units)}]]
    return [expr {$best_x / double($units)}]
}

foreach netname {VDD VSS} {
    set x_um [northernmost_metal4_x $netname $units]
    # Height 50 um down from north edge to overlap PDN stripes (~40 um below die).
    if {[catch {place_pin -pin_name $netname -layer Metal4 -location [list $x_um $yMax_um] -pin_size {1.6 50.0} -force_to_die_boundary} e]} {
        puts "PLACE_PIN_FAIL $netname $e"
        exit 1
    }
    puts "PLACED_NORTH $netname x_um=$x_um y_um=$yMax_um"
}

write_db $dst
puts "WROTE $dst"
exit
