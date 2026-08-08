# Basic parasitic extraction script
# Extract the layout
extract all

# Optional: Set extraction parameters
ext2spice hierarchy on         ;# Keeps subcircuit hierarchy (or 'off' for flat netlist)
ext2spice scale off            ;# Use real unit scaling
ext2spice cthresh 0.01f        ;# Extract capacitances > 0.01f 
ext2spice rthresh "infinity"   ;# Don't extract resistors	

# Output the SPICE file, in ngspice format, with a chosen output filename
ext2spice -o inv1-pex.spice -f ngspice

