namespace eval src {
    variable dir [file dirname [info script]];
}

# Init
set src_files {}

#################### Begin ##############################

# lappend src_files "core_periph/mac_interface.sv"

lappend src_files "counter.sv"
# no other option at the moment
lappend src_files "../macros/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram64x8m8wm1.v"

# # Default Top File
# lappend src_files "board_top/zynq_top.sv"

################### End #################################

foreach src_file $src_files {
    add_files -fileset sources_1 [file join $src::dir $src_file]
}

