#!/bin/zsh

export PROJECT_ROOT_DIR=$(git rev-parse --show-toplevel)
export PROJECT_NAME=$(basename $PROJECT_ROOT_DIR)

export FRONTEND_DIR="$PROJECT_ROOT_DIR/frontend"

export PROJ_DIR="$FRONTEND_DIR/proj"
export RTL_DIR="$FRONTEND_DIR/rtl"
export SIM_DIR="$FRONTEND_DIR/sim"
export SYN_DIR="$FRONTEND_DIR/syn"

# goto init
export GOTO_ENV_DIR="$FRONTEND_DIR"

