# Sim
When you need to put effort in breaking something

## Directory Overview :open_file_folder:
| Name | Purpose |
| :--- | :--- |
| :file_folder: `data/` | Relevant Simulation data for reference/debugging(.ucdb, .vcd, .wlf, .log) |
| :file_folder: `scripts/` | Testbench generation scripts |
| :file_folder: `verif/` | Verification base dir with Unit tests, UVM environments, formal tests |
| :page_facing_up: `sim.vivado.tcl` | Declaratively specifies the simulation file lists (`unit` — unit testbenches, `uvm` — UVM environments, `behav` — behavioural models for ASIC IP) — part of `orchestrate_proj.tcl` |

