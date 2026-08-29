set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco9_routed.odb
set block [ord::get_db_block]
proc dump_buf {block name} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "NO $name"; return }
  puts "INST $name [[$i getMaster] getName]"
  foreach pin {I Z} {
    set t [$i findITerm $pin]
    if {$t eq "NULL" || $t eq ""} { continue }
    set n [$t getNet]
    if {$n eq "NULL"} { continue }
    set terms [$n getITerms]
    puts "  $pin net=[$n getName] terms=[llength $terms]"
    set k 0
    foreach it $terms {
      incr k
      if {$k > 12} { puts "    ..."; break }
      puts "    [[$it getInst] getName]/[[$it getMTerm] getName]"
    }
  }
}
foreach n {wire33 fanout249 max_cap32 fanout242 _16404_ _16403_ _16198_ _15970_ _15936_ _11576_} {
  dump_buf $block $n
}
exit
