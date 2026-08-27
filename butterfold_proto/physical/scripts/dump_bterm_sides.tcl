# Query top-level terminal sides from the current OpenROAD database.
# Usage: ECO_SRC=path/to.odb openroad -no_init -exit physical/scripts/dump_bterm_sides.tcl
set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
set pdk /foss/pdks/gf180mcuD
if {![info exists env(ECO_SRC)] || $env(ECO_SRC) eq ""} {
    puts "ERROR set ECO_SRC to an ODB or DEF"
    exit 1
}
set src $env(ECO_SRC)
set out "-"
if {[info exists env(PIN_REPORT)] && $env(PIN_REPORT) ne ""} {
    set out $env(PIN_REPORT)
}

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
if {[string match *.def $src]} {
    read_def $src
} else {
    read_db $src
}

set block [ord::get_db_block]
set die [$block getDieArea]
set units [$block getDefUnits]
set x0 [$die xMin]
set y0 [$die yMin]
set x1 [$die xMax]
set y1 [$die yMax]
set eps [expr {int(2.0 * $units)}]

proc classify_side {x y x0 y0 x1 y1 eps} {
    set dw [expr {abs($x - $x0)}]
    set de [expr {abs($x - $x1)}]
    set ds [expr {abs($y - $y0)}]
    set dn [expr {abs($y - $y1)}]
    set m $dw
    set side WEST
    if {$de < $m} { set m $de; set side EAST }
    if {$ds < $m} { set m $ds; set side SOUTH }
    if {$dn < $m} { set m $dn; set side NORTH }
    if {$m > $eps} { return [list INTERIOR $m] }
    return [list $side $m]
}

set rows {}
set counts [dict create NORTH 0 WEST 0 EAST 0 SOUTH 0 INTERIOR 0]
foreach bterm [$block getBTerms] {
    set name [$bterm getName]
    set use [$bterm getSigType]
    set best_side INTERIOR
    set best_m 1e99
    set layer "?"
    set cx 0
    set cy 0
    foreach bpin [$bterm getBPins] {
        foreach box [$bpin getBoxes] {
            set lx [$box xMin]
            set ly [$box yMin]
            set ux [$box xMax]
            set uy [$box yMax]
            set mx [expr {($lx + $ux) / 2}]
            set my [expr {($ly + $uy) / 2}]
            foreach cand [list [list $lx $my] [list $ux $my] [list $mx $ly] [list $mx $uy] [list $mx $my]] {
                lassign $cand px py
                lassign [classify_side $px $py $x0 $y0 $x1 $y1 $eps] side dist
                set prefer 0
                if {$side eq "NORTH" || $side eq "WEST"} { set prefer 1 }
                if {$best_side eq "INTERIOR" && $side ne "INTERIOR"} {
                    set best_side $side
                    set best_m $dist
                    set cx $px
                    set cy $py
                    set layer [[$box getTechLayer] getName]
                } elseif {$prefer && ($best_side eq "EAST" || $best_side eq "SOUTH" || $best_side eq "INTERIOR")} {
                    set best_side $side
                    set best_m $dist
                    set cx $px
                    set cy $py
                    set layer [[$box getTechLayer] getName]
                } elseif {$dist < $best_m && $side ne "INTERIOR"} {
                    set best_side $side
                    set best_m $dist
                    set cx $px
                    set cy $py
                    set layer [[$box getTechLayer] getName]
                }
            }
        }
    }
    dict incr counts $best_side
    set cx_um [format %.3f [expr {$cx / double($units)}]]
    set cy_um [format %.3f [expr {$cy / double($units)}]]
    lappend rows [list $name $best_side $cx_um $cy_um $layer $use]
}

set lines {}
lappend lines [format "DIE_UM %.3f x %.3f" [expr {$x1 / double($units)}] [expr {$y1 / double($units)}]]
lappend lines [format "AREA_MM2 %.6f" [expr {($x1 - $x0) * ($y1 - $y0) / double($units) / double($units) / 1e6}]]
lappend lines [format "TOTAL %d" [llength $rows]]
foreach s {NORTH WEST EAST SOUTH INTERIOR} {
    lappend lines [format "%s %s" $s [dict get $counts $s]]
}
lappend lines "terminal side x_um y_um layer use"
foreach r [lsort -dictionary $rows] {
    lappend lines [format "%s %s %s %s %s %s" {*}$r]
}

set text [join $lines "\n"]
puts $text
if {$out ne "-"} {
    set f [open $out w]
    puts $f $text
    close $f
    puts "WROTE $out"
}

set n [dict get $counts NORTH]
set w [dict get $counts WEST]
set e [dict get $counts EAST]
set s [dict get $counts SOUTH]
set tot [llength $rows]
if {$tot == 23 && $n == 12 && $w == 11 && $e == 0 && $s == 0} {
    puts "PIN_SIDES_PASS"
    exit 0
}
puts "PIN_SIDES_FAIL tot=$tot N=$n W=$w E=$e S=$s"
exit 1
