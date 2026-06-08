# Frontend
Welcome to the coding side of building a digital circuit

> Built with :heart: by [Eloquencere](https://github.com/Eloquencere), [spacebiz24](https://github.com/spacebiz24), and [darshanram008](https://github.com/darshanram008)

## Folder Overview :open_file_folder:
| Directory | Purpose |
| :--- | :--- |
| `docs/` | Documentation — litrature, datasheets, design spec, block diagrams, timing diagrams, auto-generated code docs |
| `rtl/` | All synthesisable HDL source files, IPs, interfaces, and bind files |
| `sim/` | Testbenching — Design Verification unit tests and UVM environments, reference models, Formal Verification, simulation outputs |
| `syn/` | Synthesis constraints, release bitstreams, and post-syn/post-impl reports |
| `proj/` | Environment setup scripts and EDA tool project files (Vivado, Questa, Vitis) — gitignored |
| `gen/` | Auto-generated RTL from tools like LogiSim, MATLAB/Simulink, and Vitis HLS — NOT IMPLEMENTED |
| `cpu/` | C/C++ firmware and binaries that run on the onboard processor |

## Getting Started
> [!WARNING]
> Work in Progress

**Prerequisites:**
Vivado (for linting, simulation & synthesis)
Vitis/VitisHLS (for CPU firmware and HLS blocks)
just 2.x (for easy tool access)
mask 1.x (for markdown readable & executable scripts)
Python 3.x (for scripts)
Zellij (optinal, for launching a terminal-multiplexed developer workspace layout)
Verilator (optional, for editor linting)

**To Setup Dev Environment**
```bash
# Method 1
source frontend/proj/launch_dev_session.zsh

# Method 2 - Read the 
mask setup # YET to implement
```

**To Launch:**
```bash
# To interactively choose recipes
just --choose
```

