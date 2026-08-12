source padframe_config.tcl

read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {
    read_lef $lef
}

read_db results/padframe/route/route.odb

set block [ord::get_db_block]
set core [$block getCoreArea]
set dbu [$block getDbUnitsPerMicron]

puts "DBU_PER_MICRON = $dbu"
puts "CORE_XMIN = [expr {double([$core xMin]) / $dbu}] um"
puts "CORE_YMIN = [expr {double([$core yMin]) / $dbu}] um"
puts "CORE_XMAX = [expr {double([$core xMax]) / $dbu}] um"
puts "CORE_YMAX = [expr {double([$core yMax]) / $dbu}] um"

set w [expr {double([$core xMax] - [$core xMin]) / $dbu}]
set h [expr {double([$core yMax] - [$core yMin]) / $dbu}]

puts "CORE_WIDTH  = $w um"
puts "CORE_HEIGHT = $h um"
puts "CORE_AREA   = [expr {$w * $h / 1000000.0}] mm^2"
