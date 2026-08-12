#!/bin/zsh

: "${TOOLS_HOME:?TOOLS_HOME is not set}"
: "${XDG_DATA_HOME:?XDG_DATA_HOME is not set}"
typeset -U path

export PROJECT_ROOT_DIR=$(git rev-parse --show-toplevel) || { print -u2 "ERROR: not inside a git repo"; return 1 }
export PROJECT_NAME="$(basename $PROJECT_ROOT_DIR)"

export PROJ_DIR="$PROJECT_ROOT_DIR/proj"
export RTL_DIR="$PROJECT_ROOT_DIR/rtl"
export SIM_DIR="$PROJECT_ROOT_DIR/sim"
export SYN_DIR="$PROJECT_ROOT_DIR/syn"

# goto init
export GOTO_ENV_DIR="$PROJECT_ROOT_DIR"

