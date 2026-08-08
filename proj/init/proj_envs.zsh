#!/bin/zsh

export PROJECT_ROOT_DIR=$(git rev-parse --show-toplevel)
export PROJECT_NAME=$(basename $PROJECT_ROOT_DIR)

export PROJ_DIR="$PROJECT_ROOT_DIR/proj"
export RTL_DIR="$PROJECT_ROOT_DIR/rtl"
export SIM_DIR="$PROJECT_ROOT_DIR/sim"
export SYN_DIR="$PROJECT_ROOT_DIR/syn"

# goto init
export GOTO_ENV_DIR="$PROJECT_ROOT_DIR"

