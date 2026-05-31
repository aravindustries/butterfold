launch:
    just _vivado "-mode gui -notrace -source $PROJ_DIR/scripts/init.tcl > /dev/null 2>&1 &"

lint:
    # run the vivado linter & paste output here

compile:
    # check for compile errors with the current code

simulate:
    @clear
    just _vivado "-mode batch -notrace -source $PROJ_DIR/scripts/run_sim.tcl"

generate-bitstream:
    # run optimise-area (or use the previous run) & gen bitstream file & open hardware manager

commit-prepare:
    # run clean, move over IP files to the ip folder & zip files if necessary

unpack:
    # reverse of the above & sets up the project for development
    # create a vivado project directory, setup the project essentially, confgure the board

clean:
    # remove all temporary files & vivado generated files

_optimise-area:

_optimise-power:

_optimise-timing:

_vivado cmd:
    @cd $PROJ_DIR/tools/vivado && vivado {{cmd}}

# [working-directory: "{{env(PROJECT_DIR)}}/tools/vivado"]
# work_dir := env('PROJECT_DIR') + "/tools/vivado"
# [working-directory: "{{work_dir}}"]
# {{ if os() == "windows" { "powershell -Command \"Write-Host Building\"" } else { "./build.sh" } }}

