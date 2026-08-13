# Read-only inventory of top-level physical terminals in the authoritative ODB.
set phys_dir [file dirname [file normalize [info script]]]
set route_db "$phys_dir/results/padframe/route/route.odb"
if {![file exists $route_db]} { error "missing authoritative ODB: $route_db" }
read_db $route_db
set block [ord::get_db_block]
puts "TOP=[$block getName]"
set boundary_connected 0
foreach bterm [lsort -command {apply {{a b} {string compare [$a getName] [$b getName]}}} [$block getBTerms]] {
  set net [$bterm getNet]
  set wire [expr {$net eq "NULL" ? "NULL" : [$net getWire]}]
  set wire_state [expr {$wire eq "NULL" ? "NONE" : "PRESENT"}]
  set iterms {}
  if {$net ne "NULL"} {
    foreach iterm [$net getITerms] {
      lappend iterms "[[$iterm getInst] getName]/[[$iterm getMTerm] getName]"
    }
  }
  set bpin_box ""
  foreach bpin [$bterm getBPins] {
    foreach box [$bpin getBoxes] {
      set bpin_box "[[$box getTechLayer] getName]:[$box xMin],[$box yMin],[$box xMax],[$box yMax]"
    }
  }
  set pad_box ""
  foreach iterm [$net getITerms] {
    if {[[$iterm getMTerm] getName] eq "PAD"} {
      set box [$iterm getBBox]
      set pad_box "Metal5:[$box xMin],[$box yMin],[$box xMax],[$box yMax]"
    }
  }
  set connected [expr {$bpin_box ne "" && $bpin_box eq $pad_box}]
  if {$connected} { incr boundary_connected }
  set connected_text [expr {$connected ? "YES" : "NO"}]
  puts "BTERM=[$bterm getName]|DIRECTION=[$bterm getIoType]|USE=[$bterm getSigType]|WIRE=$wire_state|ITERM=[join $iterms ,]|BPIN=$bpin_box|PAD=$pad_box|BOUNDARY_CONNECTED=$connected_text"
}
puts "BOUNDARY_CONNECTED=$boundary_connected/21"
