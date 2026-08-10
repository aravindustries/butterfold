source [file join [file dirname [file normalize [info script]]] padframe_config.tcl]
read_lef $tech_lef
read_lef $io_site_lef
read_lef $cell_lef
read_lef $sram_lef
foreach lef $io_lefs {read_lef $lef}
read_liberty $cell_lib
read_liberty $sram_lib
read_liberty $io_lib
read_verilog $mapped_core
read_verilog $wrapper
link_design butterfold_padframe_top
read_sdc $pad_sdc
report_checks -path_delay max -group_path_count 2
