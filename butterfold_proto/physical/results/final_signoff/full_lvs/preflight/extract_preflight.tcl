# Cheap Magic GDS device-extraction preflight on the authoritative team GDS.
# Native Magic 8.3 + gf180mcuD.magicrc. Not a homemade extractor.
drc off
locking off
gds readonly true
gds rescale false

set gds $::env(CURRENT_GDS)
puts "PREFLIGHT_GDS $gds"
gds read $gds

# Annotate stdcell port order from official PDK spice (LibreLane extract_spice.tcl).
if {[info exists ::env(CELL_SPICE_MODELS)]} {
    foreach spice_file $::env(CELL_SPICE_MODELS) {
        puts "> spice read $spice_file"
        readspice $spice_file
    }
}

set cells {
    gf180mcu_fd_sc_mcu9t5v0__and2_1
    gf180mcu_fd_sc_mcu9t5v0__inv_1
    gf180mcu_fd_sc_mcu9t5v0__nand2_1
    gf180mcu_fd_sc_mcu9t5v0__nor2_1
    gf180mcu_fd_sc_mcu9t5v0__aoi21_1
    gf180mcu_fd_sc_mcu9t5v0__oai21_1
    gf180mcu_fd_sc_mcu9t5v0__dffrnq_1
    gf180mcu_fd_sc_mcu9t5v0__buf_1
    gf180mcu_fd_sc_mcu9t5v0__clkbuf_1
    gf180mcu_fd_sc_mcu9t5v0__antenna
    gf180mcu_fd_sc_mcu9t5v0__fill_1
    gf180mcu_fd_sc_mcu9t5v0__fillcap_8
}

puts "PREFLIGHT_CELL_LIST"
foreach c [cellname list allcells] {
    if {[string match *gf180mcu_fd_sc_mcu9t5v0__and2_1* $c] ||
        [string match *gf180mcu_fd_ip_sram__sram256x8m8wm1* $c] ||
        [string match *butterfold_top* $c]} {
        puts "PRESENT $c"
    }
}

foreach cell $cells {
    puts "PREFLIGHT_EXTRACT $cell"
    if {[catch {load $cell} err]} {
        puts "PREFLIGHT_LOAD_FAIL $cell $err"
        continue
    }
    select top cell
    extract do local
    extract no capacitance
    extract no coupling
    extract no resistance
    extract no adjust
    extract unique all
    extract
    ext2spice lvs
    ext2spice -o ${cell}.spice $cell
    puts "PREFLIGHT_WROTE ${cell}.spice"
}

puts "PREFLIGHT_DONE"
quit -noprompt
