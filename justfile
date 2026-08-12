create:
    mkdir -p $PROJ_DIR/tools/vivado
    just _vivado "-mode batch -notrace -source $PROJ_DIR/scripts/create_project.tcl"
    uv venv
    uv pip install -r requirements.txt

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

start-container jupyter="false":
    @if [ -z "$(docker ps -q -f name=^/gf180-x$)" ]; then \
        DOCKER_TAG=chipathon26 CONTAINER_NAME=gf180-x DESIGNS=$RTL_DIR bash $PROJ_DIR/tools/sscs-chipathon-2026/resources/IIC-OSIC-TOOLS/start_chipathon_x.sh; \
    fi
    docker exec -it gf180-x bash
    {{ if jupyter == "true" { "cd $RTL_DIR && jupyter notebook &> /dev/null &" } else { "" } }}

    # In the docker terminal
    # source sak-pdk-script.sh gf180mcuD gf180mcu_fd_sc_mcu7t5v0 
    # librelane config.yaml --pdk gf180mcuD --pdk-root /foss/pdks --manual-pdk

    # NOTE: set an env var path for runs/ if possible

_optimise-area:

_optimise-power:

_optimise-timing:

_vivado cmd:
    @cd $PROJ_DIR/tools/vivado && vivado {{cmd}}

# [working-directory: "{{env(PROJECT_DIR)}}/tools/vivado"]
# work_dir := env('PROJECT_DIR') + "/tools/vivado"
# [working-directory: "{{work_dir}}"]
# {{ if os() == "windows" { "powershell -Command \"Write-Host Building\"" } else { "./build.sh" } }}

