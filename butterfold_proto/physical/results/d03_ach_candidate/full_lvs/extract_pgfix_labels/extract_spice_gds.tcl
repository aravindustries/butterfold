# Copyright 2025 LibreLane Contributors
#
# Adapted from OpenLane
#
# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set f [open $::env(STEP_DIR)/cif_scale.txt "w"]
puts $f [expr {((round([magic::cif scale output] * 10000)) / 10000.0) * 1}]
close $f

source $::env(SCRIPTS_DIR)/magic/common/read.tcl

if { $::env(MAGIC_EXT_USE_GDS) } {
    # Same GDS import flags as LibreLane read_pdk_gds / read_macro_gds.
    gds rescale false
    gds readonly true
    gds read $::env(CURRENT_GDS)
    # SRAM hard-macro: LEF pins so MAGIC_EXT_ABSTRACT_CELLS LEFview is valid.
    read_macro_lef
} else {
    read_tech_lef
    read_pdk_lef
    read_macro_lef
    read_extra_lef
    read_pad_lef
    read_def
}

# annotate stdcell port order
read_pdk_spice

if { [info exists ::env(MAGIC_EXT_ABSTRACT_CELLS)] } {
    set cells [cellname list allcells]
    set matching_cells ""
    foreach expression $::env(MAGIC_EXT_ABSTRACT_CELLS) {
        set matched 0
        foreach cell $cells {
            if { [regexp $expression $cell] } {
                puts "$cell matched with the expression '$expression'"
                set matching_cells "$cell $matching_cells"
                set matched 1
            }
        }
        if { $matched == 0 } {
            puts "\[WARNING\] Failed to match the expression '$expression' with cells in the design"
        }
    }
    foreach cell $matching_cells {
        load $cell
        property LEFview true
    }
}

if { [info exists ::env(MAGIC_EXT_ABSTRACT_CELLS_RX)] } {
    set cells [cellname list allcells]
    set matching_cells ""
    foreach expression $::env(MAGIC_EXT_ABSTRACT_CELLS_RX) {
        foreach cell $cells {
            if { [regexp $expression $cell] } {
                puts "$cell matched with $expression"
                set matching_cells "$cell $matching_cells"
            }
        }
    }
    foreach cell $matching_cells {
        load $cell
        property LEFview true
    }
}

load $::env(DESIGN_NAME) -dereference

# Label SRAM LEF pins on the top cell so extract unique can split Mag-shorted WEN/GWEN.
load $::env(DESIGN_NAME)
set sram_pins {
  {GWEN 202.940 0.000 204.060 5.000}
  {{WEN[0]} 12.695 0.000 13.815 5.000}
  {{WEN[1]} 63.020 0.000 64.140 5.000}
  {{WEN[2]} 65.270 0.000 66.390 5.000}
  {{WEN[3]} 117.020 0.000 118.140 5.000}
  {{WEN[4]} 310.575 0.000 311.695 5.000}
  {{WEN[5]} 360.900 0.000 362.020 5.000}
  {{WEN[6]} 363.150 0.000 364.270 5.000}
  {{WEN[7]} 413.475 0.000 414.595 5.000}
}
set sram_xy {{51.120 720.560} {531.120 720.560}}
foreach xy $sram_xy {
  set ox [lindex $xy 0]
  set oy [lindex $xy 1]
  foreach pin $sram_pins {
    set n [lindex $pin 0]
    set x1 [expr {$ox + [lindex $pin 1]}]
    set y1 [expr {$oy + [lindex $pin 2]}]
    set x2 [expr {$ox + [lindex $pin 3]}]
    set y2 [expr {$oy + [lindex $pin 4]}]
    box ${x1}um ${y1}um ${x2}um ${y2}um
    catch {label $n} err
    puts "LABEL $n $x1 $y1 $x2 $y2"
  }
}


set backup $::env(PWD)
set extdir $::env(STEP_DIR)/extraction
set netlist $::env(STEP_DIR)/$::env(DESIGN_NAME).spice

file mkdir $extdir
cd $extdir

extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust

if { $::env(MAGIC_EXT_UNIQUE) != "none" } {
    extract unique $::env(MAGIC_EXT_UNIQUE)
}

# extract warn all
extract

ext2spice lvs

# For designs where more than one top-level pin is connected to the same net
if { $::env(MAGIC_EXT_SHORT_RESISTOR) } {
    ext2spice short resistor
}

ext2spice -o $netlist $::env(DESIGN_NAME).ext

cd $backup
feedback save $::env(STEP_DIR)/feedback.txt
