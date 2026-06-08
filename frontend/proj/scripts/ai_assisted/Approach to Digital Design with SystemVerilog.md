#Digital-Design 
# General Approach
## Setting the Stage
- Write extensive textual descriptions of the expected functionality of the block. Including opportunities for possible improvements, test plan & questions/concerns.
	- This becomes the spec sheet of that particular block. This will be appended to the primary project document on `typst`
- Develop the port list that needs to be supported for proper functioning.
	- Decide on the kind of interface to the outside world, such as using plain ports or an interface or struct bundle and/or using protocols like AXI or UART.
- Develop timing diagrams (in `wavedrom`) to demonstrate the response of the design due to change in inputs. This can go down to any level that the designer feels. 
- Prepare a top-down hierarchical `data_path` level implementation *block diagram* (on **draw.io**) down to register & comb logic level.
	- Decide on the compulsory pipeline stages (like, fixed memory latency)
	- Identify spec compliance mandatory clock domain crossings needed inside the block. Group different clock domains using the 4 color-theorem.
- Develop functional assertions & coverage conditions (in code and/or in text)
	- Refer to the assertions page to see which kinds of assertions apply where
## Testbenching
- Build an algorithmic twin of the expected implementation in a high level language (C++/Python) for poc (proof of concept) & use as golden model during verification.
	- Supply high level test cases to the golden_ref & the design (using DPI) simultaneously & compare the responses.
	- Later, after synthesis, the processor can be loaded with those test cases & can exercise the PL.
## Design Coding
- Begin with the control path & prove spec compliance with the simulation's output timing diagram. Code the data path at the end. Write assertions where possible.
- Perform rigiourous unit tests on your design using the test plan, to check for - 
	- Functional bugs.
	- Wasted cycles.
## Pipelining
- other terminologies - structural
### Architectural/Logical Pipeline Stages
- These are stages as bifurcated by the architect to cleanly distinguish between operations. And generally implemented in different modules.
- Need not have any correlation with actual number of registers in the design.
- Can define further hierarchies of Architectural & Implementational pipeline stages inside.
- Usually, they operate at different frequencies due to different task demands. 
	- Can communicate with other architectural stages over an interface, or in the case of simple pipelines, structs.
	- Can use FIFO structures to send data reliably. 
	- Can use bus protocols (AXI, AHB, Wishbone etc) to communicate. (take account of communication overhead)
### Implementational/Physical Pipeline Stages
- Flopped stages inside an architectural pipeline stage that is used to break up the critical path.
- They all must operate at the same clock frequency and do not use handshake protocols. But may use synchronous FIFOs in the case of infrequent arrival of data.
- Only the primary data path(s) is flopped manually with `always_ff` and the other signals are pipelined with `struct`
## File Extensions
#### Standard Files
##### Verilog
- v, sv
- vp, svp -> protected
- vh, svh -> header files
- vhp, svhp -> header protected
##### VHDL
- vhd, vhdl
- vhdp -> protected
#### IP instantiation template
- essentially, v or vhdl files
- veo -> verilog
- vho -> vhdl
#### Others (Common)
- mem -> memory value initialization file
- bd -> block diagram file
- wcfg -> wave config file
- xco, xci, xcix -> ip config file
#### Unknown
- svo, verilog, vlog, vf, vhf, vr, vg, vb, vm, h, tf, bmm, mif, elf, dcp, h
- edn, edf, edif, ngc

## Stuff in SV I haven't used
- randsequence, randcase, let, interconnect, nettype
- := & :/ & dist keyword in constraining
- Formal - assume, restrict, expect
- in assertions
	- until (until_with), throughout, implies, intersect, within, first_match, .ended, .matched
# Directory Structure Reference
- To note, this is not updated frequently & cannot be identical to any specific project directory structure. This is strictly for referencing only. For the role of a directory, please refer to the `README.md` in that respective folder.
```
docs/
	desc: final project-docu.pdf
		stats of the design like LUT plots & about the golden ref code.
		spec of all blocks & calculations used
		assertions, coverage, tests exercised
		sim & syn reports & the back & forth, what was learnt 
	assets/
		desc: images & other stuff needed for documentation
		desc: take inspiration from "FPGA for beginners" & "Simple Tutorials for Embedded Systems" for drawing block diagrams
	litrature/ (gitignore)
		desc: litrature survey stuff like existing implementations & links to those repos & websites etc. & maybe books & papers
		datasheets/
			desc: reference datasheets that were used to make it work
	code-docs/
		Doxygen/
		NaturalDocs/
			desc: try to document python & tcl scripts
	README.md
		desc: credits, brief description, block pics, timing diagrams etc
		prereq to run the project & the steps to run it.

gen/
	desc: contains code that is auto-generated
	custom/
		desc: from custom script like Python or local AI
	logisim/
		src/
			desc: tool save file
		rtl/
			desc: HDL from LogiSim
	matlab/
		src/
			desc: simlink & .m files
		rtl/
	vitishls/
		includes/
		src/
			desc: can be symlinked to the cpu part if the files happen to be the same
		rtl/

proj/ (gitignore - at the moment)
	desc: project folders for the tools that I will be using in my project
	- Document all baseline scripts in sh, bat, tcl, makefile etc with natrual docs/ doxygen
	- https://www.fpgadeveloper.com/2014/08/version-control-for-vivado-projects.html/
	init/
		desc: environment initializations for all my EDA tools & zellij template
	tools/
		Folders like - vivado, questa, matlab (simulations for poc etc)
	scripts/
		desc: stuff that generates other project files
		launch_vivadoGUI.zsh
		duplicate_proj.zsh
			- Setting up a blank slate for getting started right away with the most up-to-date directory structure.
			- setting up project for vivado & vitis other such that the necessary files appear in the right directories
			- run the "tree" command to show the file structure to the user (only here) & cat the file structure into the readme file (to give an idea of what is where)
			- This initializes a git repo which is generated (maybe) from a github repo template & initialises the version number to 0.1.0 in the README
		build_proj.zsh
			- installs dependencies & runs synthesis and launches zellij in developer mode
		sim.tcl
			- maintain a hierarchy of tcl scripts in the design & tb files which might have .f files inside & running the top sim will add the folders as described by the individual sims(or whatever) & then, launch vivado with simulation & timing diagaram with any pre-saved wave config. (consider a makefile) can maybe even pass +TEST_CASE arg to run only one case (something like 564) pass maximum debug flags to the simulator, run the linter via cmdline first to iron out minor issues.
		syn.tcl
			- (https://www.reddit.com/r/FPGA/comments/9pgk1t/is_it_normal_for_synthesis_to_take_a_while/)
			- List out the steps that vivado has on the side pane so, I choose the best thing to run (1. RTL analysis, 2. Implementation 3. BitStream)
			- take the sim (or .f) files in the individual folders to know which files to include & which to exclude
			- save schematic diagram & powr, area & timing reports & LUT utilization in syn/data with the file named as the time & date it was generated.
		cpu_dev.tcl (untouched)
			- Opening vitis with the code in the run folder ready to be run
		commit.bat (depricated)
			- pushing the necessary files to github & passing the commit message
			- Increments the version number in the README file
			- Can ask for commit message per file
	  NOTE: vitisIDE (in CPU)

rtl/
	bind/
		- https://stackoverflow.com/questions/38316052/how-to-bind-an-interface-with-system-verilog-module
		- external SVA binds for designs
		- and for formal verif
	ip/
        - Vivado in-built IP blocks(.xci & .xml files)
        - Previously designed IP blocks
        - https://www.youtube.com/watch?v=9f4i1Fq7xak
	lib/
		- Handwritten(or pre-written) code from a previous project (non IP code) that is needed here, the ones that I know WILL work & are project independent (like a FIFO, AXI etc) (Say, for designing a VGA to HDMI converter, the basic non-IP VGA controller code can come here)
	mem/
	src/
			- reference the name of the proj I got the file from in the 1st line as a comment in the file
		- folders for main components (code that I am writing from scratch & that needs to be verified)
		- insert asserts into the code
        - interface files
            - for Unit tests & connections between units etc
            - and useful for adding asserts, modports, clocking blocks
            - even to the TB
		board_top/
		intrf/
	hdl_filelist.f
	scripts/
		makefile or tcl script file - use copilot
			- script to generate block diagram(if necessary)
			- To scour through all the rtl/ folders to add them to the compile sequence automatically by running the script to run sim or syn, same for sim/scripts	
				- Load the files into a local buffer in the script file itself and then depending on whether it is sim or syn feed the files to Questa or Vivado
			- tcl file (file -> write tcl) generates the entire project w/ all settings
			- links to a script in the sim folder to generate the unit test template file there & automatically open on vscode
			- to be able to add paths of files that were `included in the rtl(like gen/rtl/) in QuestaSim arguments
			  
sim/
	data/
		unit/
			blk1_response(currtime).ucdb (code coverage)
			blk1_response(currtime).vcd/wlf/trn (timing diagram)
			blk1_reponse(currtime).txt/log (log file)
		uvm/
		wave_dumps/
			vcd/ (most common)
			wlf/ (questa)
			trn/ (xcelium)
		logs/
			.log or .txt (with incrementing numbers)
	scripts/
		desc: tb code generation scripts
	poc/
		- models the whole system might even contain individual blocks that can be used by scoreboards
			- superficial MATLAB, Python or C++ implementation to understand the scope of the project & to get preliminary expected outputs & for final equivalence check
			- (Eg. for a VGA controller implement it on an Arduino or ESp32 to get a sample output)
			- Report these findings in 1 page of OneNote as Research
		- Code that can emulate a sub-block block of the design, which can all be combined together to test the entire design
		- sv or HLS synthesised code
		- C/C++ or systemC or Python or matlab code to support the rtl and/or testbench (octave)
		- Can I use MATLAB or python in real-time as reference models when the sim is running?
		- Can contain the simulation of the final product / design for proof of concept in C/C++, python, MATLAB
		- reference IPs as well
		- IP blocks of Vivado
	verif/
		dv/
			unit/
			uvm/
				- Allow to specify a functional verification test plan
				components/
						agent/
						environment/
						sequence/
						test/
						utilities/
						components_pkg.sv
					(note: perform a connectivity check every time the agents are changed)
				func_tests/
					test1.cpp
				extern-emulator/
					- agent(s) within an env used to emulate external components to verify a component like FIFO or arbiter 				(master_emu or slave_emu etc)
					- independent test cases (inputs to their agents, sequences)
					compile/
						emulators_pkg.sv
				compile/
					testbench_pkg (probe + extern + components)
			unit/
				golden_refs/ (probably depricated by poc)
					- Reference blocks written as golden reference models
					blk1_CocoTB.py
					blk1_SVUnit.sv
					blk1_HLS.cpp
				func_tests/
					blk1_CocoTB.py - to check HDL generated by LogicSim, MATLAB & IP blocks
					blk1_SVUnit.sv (depricated) - mainly to check custom HDL code written by me
					blk1_custom.sv (depricated) - pre written testb code by me using pure SV unit testbenches using interface(clocking + modport), program etc & with assertions to get rid of x & z states
					blk1_HLS.cpp
		formal/
		mem/
			- common mem files for testing sake
		lib/
			- other files like file handling code, top module locator or template folders(like uvmf) etc
			- LFSR for test generation (re-usable code and not specifically project specific)

syn/
	constrs/
		board/
			desc: constraint files for different target boards
		design/
			timing.xdc (better off as tcl)
				desc: timing constraints like input delay, multi cycle path etc
			debug.xdc
				desc: constrs for debug ILA probes to prevent it from interfering from the design
	release/
		bitstream file
		final_ip_block
			- final IP block of the code previously under test(created by me for re-usability)
		reports/
			- final schematic diagram(or files) & final IP block diagram pics(or files) etc
			- timing, power, area etc
			- How many LUTs used out 17,600 (can I automate this to make a file right after synthesis in vivado?)
	src/
		- zybo7010.xdc (final constraints file)
		- memory initialisation files
	data/
		post_syn/
			- functional & timing(GLA) simulation in vivado
		post_impl/
			- timing diagram or log file using ILA

cpu/
	includes/
	src/
		- final cpp code that is written to the processor to run the FPGA
	bin/
		- binary output of the compiler (if it exists)

board/ (cpu+rtl whole board system config related files)
	- implementational information like runtime usage, etc (even I don't know for sure)
	reports/
		- Average & max CPU & on board memory usage (can a write a code that keeps a log and submits a report at the end of a session or something?)
	- Scripts/
		- to setup n/w & serial connections etc & access the bitstream & xdc from syn/
		- & to load the bitsteam into the storage to load it by default when the FPGA is turned on the next time
```

# Easter Eggs
- As a fun thought experiment, think of how I can put Easter eggs into my code, like how tayagaraja inserted his name into his songs, like how chips and PCBs have special messages that cannot be removed easily. This will be the ultimate copyright protection I can do.

### To Do
- [ ] Calculating the depth of a fifo using deduction and emperically. For example, if the clock speed up is 2x from left to right domain, the the depth needs to be 2.
How does 2 FF crossing work? What are it's limitations.
- [ ] How different is it from reset domain crossing.
- [ ] Unify coding methodologies & guidelines from Notion to obsidian.
- [ ] How to use the worst negative slack timing report to identify my critical path and find the maximum frequency of operation. (TCL)
- [ ] why would I need to bind interfaces.
- [ ] Some good use cases of packages.
- [ ] Find papers on Content addressable memory & do project.
- [ ] Need to learn to tell vivado to not consider control paths as critical (or is that even a good idea?)
* [ ] Using synchronous vs asynchronous reset FF. Does it make sense to have one universal reset button or have a previous block reset the next?
* [ ] When should active low signals be used? Especially resets
* [ ] Need to learn the art of converting simple testbenches with initial & wait statements into synthesisable code such that it can be demonstrated with ILA.
	* [ ] Learn to write code that is friendly to synthesisable testbench code & to the previous blocks.
* [ ] Learn to drive modules from the processor to the FPGA (processor becomes my TB).
- [ ] Difference between using 'specify' in SV code & hard coding input & output delays in a synthesis TCL file.
- [ ] What is speculative execution in processors
- [ ] Learn to write code that efficiently use LUT slices such that the synthesis tool can optimise the placement better.
- [ ] if I have a 5 stage pipeline, but out of necessity, I need to break it down into 10 stages, should I now put 10 new items in the pipeline or let it operate at half capacity cause I have no name for the intermediate stages.
* [ ] How to do dynamic clock switching (making a module operate on 2 different clock frequencies, but 1 clock port) - https://www.intel.com/content/www/us/en/docs/programmable/683082/22-1/clock-multiplexing.html
- [x] In my template zybo_top file, add comments that I need to usually have on the top like company etc. Instantiate an ila and clock wiz and comment them. Create another module at the end of the file with `ifdef XILINX_SIMULATOR and create a zybo_top_tb and create a module to drive in fclk at 125MHz`. & also a reset generator for top (& it's not dependent on the number of clock edges)
