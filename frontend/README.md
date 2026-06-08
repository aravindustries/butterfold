# Frontend
Welcome to the coding side of building a digital circuit.

> Built with :heart: by [Eloquencere](https://github.com/Eloquencere), [spacebiz24](https://github.com/spacebiz24), and [darshanram008](https://github.com/darshanram008)

## Directory Overview :open_file_folder:
| Name | Purpose |
| :--- | :--- |
| :file_folder: `docs/` | Documentation — litrature, datasheets, design spec, block diagrams, timing diagrams, auto-generated code docs |
| :file_folder: `proj/` | Environment setup scripts and EDA tool project files (Vivado, Questa, Vitis) |
| :file_folder: `rtl/` | All synthesisable HDL source files, IPs, interfaces, and bind files |
| :file_folder: `sim/` | Testbenching — Design Verification unit tests and UVM environments, reference models, Formal Verification, simulation outputs |
| :file_folder: `syn/` | Synthesis constraints, release bitstreams, and post-syn/post-impl reports |
| :page_facing_up: `.goto_aliases` | Shell aliases for quick directory navigation |

**Not Implemented**

| Name | Purpose |
| :--- | :--- |
| :file_folder: `gen/` | Auto-generated RTL from tools like LogiSim, MATLAB/Simulink, and Vitis HLS |
| :file_folder: `cpu/` | C/C++ firmware and binaries that run on the onboard processor |

## Getting Started
> [!WARNING]
> Work in Progress

**Prerequisites:**
- Vivado (for linting, simulation & synthesis)
- Vitis/VitisHLS (for CPU firmware and HLS blocks)
- just 2.x (for easy tool access)
- mask 1.x (for markdown scripts thta can be executed)
- Python 3.x (for scripts)
- Zellij (optinal, for launching a terminal-multiplexed developer workspace layout)
- Verilator (optional, for editor linting)

**To Setup a Development Environment**

**Method 1: Launch a Zellij session**
```bash
source proj/launch_dev_session.zsh
```
**Method 2: Manually Setup environment vars**
```bash
cd proj
source init/xilinx_envs.zsh
source init/proj_envs.zsh
source $PROJECT_ROOT_DIR/.venv/bin/activate
```

**To Launch EDA Tools:**
```bash
just --choose # interactive recipe chooser
```

