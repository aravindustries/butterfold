# Contributing to butterfold

Thank you for considering to contribute to this repo!

### Toolchains Used
| Tool                | Version   | Purpose |
| :---                | :---      | :---    |
| zsh                 | ==5.9     | Shell |
| zellij              | >=0.45    | Terminal Multiplexer |
| mise                | >=2026.9  | Tool version manager & command runner |
| uv                  | >=0.12.12 | Python & package management |
| docker              | >=29.8.0  | LibreLane container |
| Xilinx Vivado Tools | ==2025.1  | Simulation & FPGA programming |
| Verilator           | >=5.032   | CLI used by AI agents to test code |

### Additional Preferred Tools
| Tool                | Version    | Purpose |
| :---                | :---       | :---    |
| goto                | github.com/Eloquencere/zsh-goto-cli | easy `cd` tool |
| yazi                | - | easy `cd` tool |

### Development Setup
To setup a local development environment, ensure you have all the required tools installed and follow these quick steps:
```zsh
# Clone your fork
git clone https://github.com/aravindustries/butterfold

# Navigate into the project directory
cd butterfold

# Setup environment
mise run setup

# Optional: To run the entire flow & generate bitstream/GDSII file
mise run <not assigned>
```

## Directory Structure
This repo uses a non-centralised structure information, meaning every dir gets to choose what is inside it, it is not pre-decided. You must refer to the `README.md` wherever available to get information about a directory's role, contents and the contents below it.
Use the following command to discover all the relevant `README.md` files in this repository
```zsh
fd "README.md" $PROJECT_ROOT_DIR
```

## Coding Style and Guidelines
Include this header comment string in every file you submit
```text
//////////////////////////////////////////////////////////////////////////////////
// Contributor(s) : <name> (<github username>)
//
// Project Name      : butterfold
// Target Devices    : Zybo
// Module Hierarchy  : <module name> <(IP)>
//                       <module name>
// Revision(DD/MM/YY):
//          DD/MM/YY - File Created (<Insert Commit Hash>)
//          DD/MM/YY - <description> (<Insert Commit Hash>)
//
//////////////////////////////////////////////////////////////////////////////////
```

## AI Usage Policy
The usage of AI is permitted in general the workflow encourages it but, you are responsible for any follow-up questions, fixes and enhancements.
The `agents/` dir in the root dir contains different agent personas tailored for roles like orchestration, coding & review. Refer to agents/README.md file for additional info.
It is advised to let your agents work in a `git worktree` to keep the blast radius minimal.

### PR Policy
You are required to append a chat log used to get the code.

Any usage must be declared with the following block along with the PR.
```markdown
## AI assistance disclosure
This PR was drafted with AI assistance (<AI Name>),  
all tests passing and verified with the feature/bug fix implemented.
```

