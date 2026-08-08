#!/bin/zsh

cd "$(dirname "${(%):-%x}")" # change directory to script location

# Initialise init scripts
# source init/cadence_envs.zsh
# source init/mentor_envs.zsh
source init/xilinx_envs.zsh
source init/proj_envs.zsh

source $PROJECT_ROOT_DIR/.venv/bin/activate

open $PROJECT_ROOT_DIR

# NOTE: launch into the same hermes session in the AI tab

zellij delete-session "$PROJECT_NAME" &> /dev/null
zellij --layout="$PROJ_DIR/init/zellij_layout.kdl" attach --create "$PROJECT_NAME"

cd -

