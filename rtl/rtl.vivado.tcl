namespace eval rtl {
    variable dir [file dirname [info script]];

    #################### Begin ##############################

    set ip_dir {}
    set macro {}
    set rtl {}

    # lappend ip_dir "ip/clk_wiz_0"
    # lappend ip_dir "ip/ila_0"
    # lappend ip_dir "ip/ila_1"

    lappend macro "macros/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram64x8m8wm1.v"

    # lappend rtl "src/core_periph/mac_interface.sv"
    lappend rtl "src/counter.sv"
    # lappend rtl "src/board_top/zynq_top.sv"

    # # Set top file & module
    # reset_property top_file [get_filesets sources_1]
    # set_property top_file [lindex $rtl end] [get_filesets sources_1]
    # reset_property top [get_filesets sources_1]
    # set_property top async_fifo [get_filesets sources_1]

    ################### End #################################

    # Register Vivado IP (.xci)
    foreach ip $ip_dir {
        set xci_files [glob -nocomplain -directory [file join $dir $ip] -types {f} *.xci]
        if {[llength $xci_files] > 0} {
            add_files -norecurse -fileset sources_1 $xci_files
        }
    }
    foreach macro_file $macro {
        add_files -fileset sources_1 [file normalize [file join $dir $macro_file]]
    }
    foreach src_file $rtl {
        add_files -fileset sources_1 [file normalize [file join $dir $src_file]]
    }
}

