# Open-Source EDA Tutorial

This page is companion page for two short video tutorials:
- [Video Tutorial Part-1][VideoXschemNgspice]: Design and Simulation using Xschem and ngspice
- [Video Tutorial Part-2][VideoMagic]: Layout using Magic 

The purpose of these tutorials is to get circuit designers quickly started on the end-to-end design flow from design to layout using the open-source EDA tools [xschem][XSchem], [ngspice][NGSpice], [Magic][Magic], and [Netgen][Netgen]. Note, although KLayout is not covered in this tutorial, it is very well supported for this project that you will find links to from other tracks.

More resources are provided in the [Resources](#Resources) section of this page for participants to deep dive as they comfortable using the tools. 

[GF180MCU Open-Source VLSI Repo](https://github.com/stineje/gf180mcu-open-source-vlsi) from [James E. Stine](https://github.com/stineje) and team is a very detail instructions and tutorials from installation to design. 

## Table of Contents

- [Open-Source EDA Tutorial](#open-source-eda-tutorial)
- [Design and Simulation using xschem and ngspice](#design-and-simulation-using-xschem-and-ngspice)
  - [xschem-ngspice Advanced Features](#xschem-ngspice-advanced-features)
- [Layout with Magic](#layout-with-magic)
  - [Advanced Features of Magic](#advanced-features-of-magic)
- [Resources](#resources)


# Design and Simulation using xschem and ngspice

- This section is a *companion* page for this [Video Tutorial Part-1][VideoXschemNgspice]: Design and SImulation using xschem and ngspice.

- Files used in the video tutorial:
  - [`xschem-ngspice-files/inv1.sch`](xschem-ngspice-files/inv1.sch): Inverter schematic.
  - [`xschem-ngspice-files/inv1.sym`](xschem-ngspice-files/inv1.sym): Inverter symbol.
  - [`xschem-ngspice-files/TB_inv1.sch`](xschem-ngspice-files/TB_inv1.sch): Testbench for Inverter.
 
It is assumed that you have already installed the opensource design tools using [IIC OSIC TOOLS](https://github.com/iic-jku/iic-osic-tools) container.

- Run Xscheme inside the OSIC-TOOLS docker image:
  - `$ xschem`
- Create a new instance by selecting `Tools -> Insert Symbol` or, `(Shift + i)`
- Two essential libraries:
  - `.../xschem_library/devices` : technology independent primitive devices eg.:
    - Linear elements: `res.sym`, `capa.sym`, `ind.sys`
    - Stimulus sources: `vsource.sym`, `isource.sym`
    - Controled sources: `vcvs.sym`, `vccs.sym`, etc. 
  - `/foss/pdks/gf180mcuD/libs.tech/xschem/symbols` : GF180MCUD devices:
    - FETS: `nfet_03v3.sym`, `pfet_03v3.sym`, `nfet_05v0.sym`, `pfet_05v0.sym`
- After instating devices, wire them, change properties and add ports.
  - To change properties: select the devices and press `q` and change the value.
  - Place pointer on the port to start *wiring*  press `w` to start a wire connection. To jog/bend the wire, press `w` Or, click and drag the end of the wire to continue wiring.
  - Select and press `c` to *copy* an instance and left click to place it.
  - Select and press `m` or *left-click* and drag to move an instance.
  - While moving an instance, you can rotate or flip by:
    - `Shift+r` to *rotate*
    - `Shift+f` to *flip*
- To view the waveform, *label* essential nodes by instatiating `lab_pin.sym` from the `.../xschem_library/devices` library. Place the pin on the wire, *double-click* or `q` the pin and add a succint but descriptive wire name.
- If this is a block you want to create a symbol, you need to add ports eg. `vin`, `vout`, etc.
  - Place ports from the `.../xschem_library/devices` library:
    - `ipin.sym` : Input port
    - `opin.sym` : Output port
    - `iopin.sym` : Input/Output port
  - *Note* that ngspice (or any spice) does not recognize port type. This is for schemtic level checks.

- **Create a symbol** by selecting `Symbol` >> `Make symbol from schematic`
  - Click `OK` on the dialog `Do you want to make symbol view`
  - A new file (say `inv1.sym`) will be create in the same directory
  - Edit the symbol:
    - Click on `File` >> `Open` then select `inv1.sym` in the open dialog

- You might need to choose the correct directory containing the symbol file first.

- **Draw your desired shape**
  - Delete the rectangle by selecting the lines and press `delete`.
  - Use the line/circle/etc to draw your shape
  - Move the pins to apprpirate place on the shape. 

- **Create a Testbench** 
  - Create a new schematic by selecting `File` >> `Create new window/tab`
  - Insert the new instance created (say `inv1.sym`)
  - Instatiate the voltage sources: `vsource.sym` from the `../devices` library. The *value* field of vsource.sym for the supply and the input are:
    - `PAR_VDD` : parameter for the fixed suply voltage .
    - `0 PULSE("PAR_VDD" 0 PAR_DEL PAR_SLEW PAR_SLEW "0.5*PAR_PER" "1.0*PAR_PER"` : *parameterized* pulse source for the input.
  - Instatiate a capacitance (`.../devices` -> `capa.sym`) and you can enter a fixed value or a parameter eg. `PAR_CLOAD`.
  - A global ground `..../devices -> gnd` is required.
  - After wiring up, we need to instatiate two blocks for spice code:
    - For model files:

``` spice
name=MODELS only_toplevel=true  
format="tcleval( @value )" 
value="
.include $::180MCU_MODELS/design.ngspice
.lib $::180MCU_MODELS/sm141064.ngspice typical
.lib $::180MCU_MODELS/smbb000149.ngspice typical
"
```


- For parameters, measure statements, and simulation commands:


``` spice
name=NGSPICE only_toplevel=true  
value="
** PARAMETERS
.PARAM PAR_VDD=3.3
.PARAM PAR_CLOAD=100f
.PARAM PAR_SLEW=100p
.PARAM PAR_PER=10n
.PARAM PAR_DEL='0.1*PAR_PER'

** Rise/Fall 10-90%
.MEASURE TRAN tr1090 TRIG v(vout) VAL='0.1*PAR_VDD' RISE=1 TARG v(vout) VAL='0.9*PAR_VDD' RISE=1
.MEASURE TRAN tf9010 TRIG v(vout) VAL='0.9*PAR_VDD' FALL=1 TARG v(vout) VAL='0.1*PAR_VDD' FALL=1

** Delay Rise Fall
.MEASURE TRAN tdrise TRIG v(vin)  VAL='0.5*PAR_VDD' FALL=1 TARG v(vout) VAL='0.5*PAR_VDD' RISE=1
.MEASURE TRAN tdfall TRIG v(vin)  VAL='0.5*PAR_VDD' RISE=1 TARG v(vout) VAL='0.5*PAR_VDD' FALL=1

**Leakage current and average current
.MEASURE TRAN iavg AVG vsup#branch FROM=PAR_DEL TO='PAR_DEL+PAR_PER'
.MEASURE TRAN ileak AVG vsup#branch FROM='PAR_DEL+0.4*PAR_PER' TO='PAR_DEL+0.45*PAR_PER'

.control
save all
OP
TRAN 1p 21n
write TB_inv1.raw
plot v(vin) v(vout)
.endc

"
```

- **Generate Netlist and Simulate**
  - Click on `Netlist` button to generate the netlist
  - Click on `Simulation` >> `Edit Netlist` to view the netlist
  - Click on `Simulate` button to start the simulation

- **View the Waveform**

  - Easiest way to plot is using the ngspice using the `plot` command in the simulation commands.
  - We can use `Xscheme-GAW` to view the waveform.
    - Click on `Waves` button and select `External viewer`
    - In `GAW GUI` opened, click on a panel first, then click on the signal you want to display
    - You can also use embedded plots in xschem. References can be found in the *resource* on top.


## xschem-ngspice Advanced Features 

**Back Annotation of Operating Point**

- Make sure you save the operating point (say for a transistor `XM1` on the top level):

``` spice
.option savecurrents
.save @m.xm1.m0[gm] @m.xm1.m0[id] 
```
- After simulation is complete, you can annotate the operating points in the schematic: `Simulationns` >> `Graphs` >> `Annotate Operating Point into schematic`

- You can calculate expressions from the operating point and print them. If you want to print the *gm/id* of a device, you can add the following code in the `.control` section:

``` spice
LET gmoverid=@m.xm1.m0[gm]/@m.xm1.m0[id]
print gmoverid
```

- **NOTE**: you can find the heierarchial name of the device by typing `display` in the `ngspice` shell after completetion of simulation. 


# Layout with Magic

This section is a *companion* page for this [Video Tutorial Part-2][VideoMagic]:  Layout using Magic

Files used in this video:
- [`magic-files/inv1.mag`](magic-files/inv1.mag): Inverter layout
- [`magic-files/inv1-layout.spice`](magic-files/inv1-layout.spice): Extracted netlist (for LVS) of the inverter layout.
- [`magic-files/inv1-pex.spice`](magic-files/inv1-pex.spice): Extracted netlist (for parasitics) of the inverter layout.
- [`magic-files/inv1-xschem.spice`](magic-files/inv1-xshem.spice): Extracted netlist (for LVS) of the inverter schematic.
- [`magic-files/extract-lvs.tcl`](magic-files/extract-lvs.tcl): tcl script for extracting netlist for LVS 
- [`magic-files/extract-pex.tcl`](magic-files/extract-pex.tcl): tcl script for extracting netlist for post-layout simulation.


**Basic Layout Layers**

![Basic Layout Layers](../pdk/media/magic-gf180-quickGuide.png)


**Quick Start Guide**

- After launching OSIC-TOOLS docker, launch `magic` from the container shell:
  - `magic -d OGL`
     - `-d <option>`: Optional option for better graphics. `OGL` for OpenGL and `XR` for Cairo graphics.
     - `-T <tech file>`: This is not required for chipathon container.
     - `-r <startup file>`: also not required for chipathon container.
- Follow the video tutorial or any of the links in the resources to draw and complete the layout.  
- Extract the netlist using the following basic set of `tcl` commands in the tk-console (tkcon):

``` tcl
extract all 
ext2spice lvs
ext2spice -o inv1-layout.spice -f ngspice
```  

- You can put the commands in a file and load it in the `tkcon` console using `File -> Load`. Useful when you have a long list of commands.

- Run Layout-vs-Schematic (LVS) using `netgen`:
  - `netgen -batch lvs "inv1-xschem.spice inv1" "inv1-layout.spice inv1" /foss/pdks/gf180mcuD/libs.tech/netgen/gf180mcuD_setup.tcl`

- To extract netlist with parasitics:

``` tcl
extract all
ext2spice hierarchy on         ;# Keeps subcircuit hierarchy (or 'off' for flat netlist)
ext2spice scale off            ;# Use real unit scaling
ext2spice cthresh 0.01f        ;# Extract capacitances > 0.01f 
ext2spice rthresh "infinity"   ;# Don't extract resistors	
ext2spice -o inv1-pex.spice -f ngspice

```

## Advanced Features of Magic

**Creating LEF & GDS**

Following instructions are from `https://github.com/subhransu-01/sky130-magic` :

- To set the prboundary box , select area where you want the bounding box to be and use  
- `box value` to get the value (eg. 0 0 60 100)  
- `property FIXED_BBOX [box values]` (eg. property FIXED_BBOX "0 0 60 100")  
- `select top cell`  
- `property LEFclass CORE`  
- `property LEFsymmetry "X Y"`  
- `property LEFsite [library name]`  
- `lef write` , to create lef file  
- `gds write` , to create gds file
- To check _property_ , `select top cell` then use `property`   

# Resources 

- **IIC-OSIC-TOOLS**
  - [OSIC-TOOLS GitHub Page](https://github.com/iic-jku/iic-osic-tools)

- **End-to-End Design-to-Layout Flow**
  - [Open Source VLSI](https://github.com/stineje/gf180mcu-open-source-vlsi): A great detail set of deep tutorials from [James Stine](https://github.com/stineje) and team at OSU.

  - [Analog design flow with opensource tools](https://unic-cass.github.io/training/analog-flow.html): Great set of schematic-to-layout tutorials from [IEEE UNIC-CASS](https://unic-cass.github.io/) using the IHP-SG13G2 PDK. 
  - [Drawing an inverter](https://docs.google.com/document/d/1hSLKsz9xcEJgAMmYYer5cDwvPqas9_JGRUAgEORx1Yw/edit#heading=h.j6gtadx04fb6): A google doc by Ryan Ridley, Teo Ene, and James E. Stine. Detail step-by-step guide for SKY-130nm process.
  - [Video: Xschem-to-Magic Flow](https://www.youtube.com/watch?v=ZZ5fIBwLZ0k&t=2s): Tiny Tapeout Analog Submission Guide | IEEE Open Silicon IC Design Bootcamp (Philippines) A good 19min succint guide.
  - [Analog Circuit Design Flow](https://analogicus.com/rply_ex0_sky130nm/tutorial) by Carsten Wulff
  - [Open-Source Analog Design Flowing using EFabless and SKY130nm (PDF)](docs/Thater-OpenSource-AnalogDesgnFlow-Efabless-SKY130.pdf): Detail end-to-end design flow by by Joshua Thater.

  
- **xschem-ngspice**:
  - [Xschem Official Site][XSchem]
  - [ngspice Official Site][NGSpice]
  - [ngspice Manual][NGSpiceMan]
  - [Analog (Integrated) Circuit Design](https://iic-jku.github.io/analog-circuit-design/aicd.html): An excellent analog course from Dr. Harald Pretl from Johannes Kepler University. The course uses xschem, ngspice and IHPSG13G2 for all exercises. 
  - [Tutorial: Run a simulation with xschem](https://xschem.sourceforge.io/stefan/xschem_man/tutorial_run_simulation.html): a quick step-by-step html guide from the creator Stefan Schippers.
  - [xschem displaying simulation waveform](https://www.youtube.com/watch?v=bP9w3zm1qv4): a 10min video on embedded graphs by Stephan Schippers.  
  - [Viewing Simulation Data with xschem](http://repo.hu/projects/xschem/xschem_man/graphs.html): html guide on the official site.
  - Three part *tutorial videos* using xschem and ngspice with GF180MCU
    - [Part-1](https://youtu.be/MdywD87-DVg) | [Part-2](https://youtu.be/DLvZSsLAbho) | [Part-3](https://youtu.be/nBnR8Nm_B_I)

- **Magic**

  - [Magic][Magic]: The official site of Magic at opencircuitdesign.com maintained by Tim Edwards. This site has everything you need: source-code/manuals/tutorials/etc
      - [Magic User Guide from OpenCircuitDesign](http://www.opencircuitdesign.com/magic/userguide.html)
  - [Magic cheaetsheet](https://github.com/iic-jku/osic-multitool/blob/main/magic-cheatsheet/magic_cheatsheet.pdf) by Harald Pretl.
  - **Videos**
    - [10min speedrun of a inverter layout by Matt Venn](https://www.youtube.com/watch?v=IQ_DcWT_cbc)
    - [Tutorial: Analog Layout of an OpAmp](https://youtu.be/XvBpqKwzrFY?si=AyL0Wr3V4gb954yx) by Tim Edwards. (~1hr 30min)
    - Magic Tutorials by Carsten Wulff [ [Tutorial-1](https://www.youtube.com/watch?v=ORw5OaY33A4&t=9s)|[Tutorial-2](https://www.youtube.com/watch?v=NUahmUtY814)|[Tutorial-3](https://www.youtube.com/watch?v=OKWM1D0_fPI) ]

- **Klayout** 
  - [Tutorial using KLayout with gf180mcu (part 4)](https://www.youtube.com/watch?v=vamfMryYPS4)

----
:technologist: Saroj Rout (:link: `Discord @sroutk`)

* * *

[VideoXschemNgspice]:   https://drive.google.com/file/d/1QuJyBosXAcAIhj2Gz0zoxz_EHe3IlhK6/view?usp=sharing
[VideoMagic]:           https://drive.google.com/file/d/1ffgQrh8-0LQ_lEhNJCcJhuNUZTaG0cDd/view?usp=drive_link
[XSchem]:               https://xschem.sourceforge.io/stefan/index.html
[NGSpice]:              https://ngspice.sourceforge.net
[NGSpiceMan]:           https://ngspice.sourceforge.io/docs/ngspice-manual.pdf
[Magic]:                http://opencircuitdesign.com/magic/
[Netgen]:               http://opencircuitdesign.com/netgen/
