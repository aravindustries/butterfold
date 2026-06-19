## setup
```bash
uv venv
uv pip install -r requirements.txt
```

## Running
DOCKER_TAG=chipathon26 CONTAINER_NAME=gf180-x DESIGNS=$RTL_DIR bash $PROJ_DIR/tools/sscs-chipathon-2026/resources/IIC-OSIC-TOOLS/start_chipathon_x.sh

note: set an env var path for runs/ if possible

docker exec -it gf180-x bash

& optionally run
cd $RTL_DIR && jupyter notebook &> /dev/null &

### In the terminal
source sak-pdk-script.sh gf180mcuD gf180mcu_fd_sc_mcu7t5v0 
librelane config.yaml --pdk gf180mcuD --pdk-root /foss/pdks --manual-pdk

