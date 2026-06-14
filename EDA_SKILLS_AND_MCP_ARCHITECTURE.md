# ButterFold: EDA Skills Catalog & MCP Architecture
**For:** ButterFold agentic workflow enhancement  
**Date:** 2026-06-13  
**Scope:** 4-tier system with meta-planner, specialist agents, MCP servers, and critic/red-team

---

## Overview

ButterFold currently has a 4-agent pipeline (planner → code → verify → debug). This document extends that to a **4-tier, 4-specialist system**:

```
Tier 1: Skills Catalog
  ├─ simulate (iverilog-mcp)
  ├─ synthesize (yosys-mcp)
  ├─ timing (opensta-mcp)
  └─ area_estimate (techlib-mcp)

Tier 2: Meta-Planner Agent
  └─ Decomposes 3GPP spec → RTL tasks → specialist skill assignments

Tier 3: Specialist Agents (via MCP)
  ├─ Synthesis Agent (calls synthesize skill)
  ├─ Timing Agent (calls timing skill)
  ├─ Area Agent (calls area_estimate skill)
  └─ Sim Agent (calls simulate skill)

Tier 4: Critic / Red-Team Skill
  └─ Adversarial pre-verification checks before heavy EDA
```

---

## Tier 1: Skills Catalog

### 1.1 Skill: `simulate`

**Purpose:** Run RTL simulation with testbench and report results

**MCP Server:** `iverilog-server`

**Exposed Tools:**
```
1. compile_verilog(rtl_file, testbench_file, include_dirs, flags) -> (compile_ok, stderr)
2. run_simulation(vvp_file, waveform_dump_vcd, timeout_s) -> (sim_ok, stdout, stderr, vcd_path)
3. parse_vcd(vcd_file, signal_patterns) -> (signals_dict, time_range)
4. extract_testbench_results(sim_stdout) -> (passed, failed, error_list)
```

**Input Schema:**
```json
{
  "rtl_file": "/foss/designs/butterfold/generated/rtl/butterfold_top.v",
  "testbench_file": "/foss/designs/butterfold/tests/tb_butterfold_top.v",
  "iverilog_flags": "-g2012 -Wall",
  "vvp_timeout_s": 30,
  "expected_patterns": ["PASS", "done", "FAIL"]
}
```

**Output Schema:**
```json
{
  "compile_ok": true,
  "sim_ok": true,
  "testbench_passed": 9,
  "testbench_failed": 0,
  "simulation_time_ms": 2340,
  "waveform_size_mb": 15.2,
  "vcd_path": "/foss/designs/butterfold/generated/logs/sim.vcd",
  "error_log": null
}
```

**Constraints:**
- Runs inside Docker (`/foss/designs/butterfold`)
- `iverilog`, `vvp` must be in PATH
- VCD file size cap: 100 MB (testbench must limit dump scope)
- Timeout: 30 seconds default

---

### 1.2 Skill: `synthesize`

**Purpose:** Synthesize RTL to gates and report area, gates, critical paths

**MCP Server:** `yosys-server`

**Exposed Tools:**
```
1. synth_rtl(rtl_file, top_module, flatten, opt_level) -> (netlist_file, stat_json)
2. report_stat(netlist_file) -> (gate_count, cell_types, area_estimate_um2)
3. write_netlist(rtl_file, format) -> (netlist_file, num_gates)
4. extract_timing_slack(synth_report) -> (critical_path_ns, slack_ns)
```

**Input Schema:**
```json
{
  "rtl_file": "/foss/designs/butterfold/generated/rtl/butterfold_top.v",
  "top_module": "butterfold_top",
  "flatten": true,
  "optimization_level": "aggressive",
  "technology_node": "GF180"
}
```

**Output Schema:**
```json
{
  "netlist_file": "/foss/designs/butterfold/generated/synth/butterfold_top_synth.v",
  "total_gates": 3427,
  "total_area_um2": 125000,
  "cell_types": {
    "AND": 1200,
    "OR": 890,
    "NOT": 450,
    "NAND": 200,
    "DFF": 687
  },
  "critical_path_ns": 4.2,
  "logic_depth": 12,
  "synthesis_time_s": 8.5
}
```

**Constraints:**
- Requires `yosys` in PATH
- Optimization level: [basic, moderate, aggressive]
- Flat netlist only (for area estimation)
- Timeout: 60 seconds

---

### 1.3 Skill: `timing`

**Purpose:** Static timing analysis (STA) with clock constraints

**MCP Server:** `opensta-server`

**Exposed Tools:**
```
1. read_netlist(netlist_file) -> (design_loaded, num_ports)
2. set_clock_constraint(period_ns, clock_pin) -> (constraint_set, slack)
3. report_timing(format) -> (critical_path_delay, slack_dict, timing_violations)
4. find_critical_paths(top_n) -> (paths[])
5. generate_sta_report(output_file) -> (report_path, analysis_complete)
```

**Input Schema:**
```json
{
  "netlist_file": "/foss/designs/butterfold/generated/synth/butterfold_top_synth.v",
  "clock_period_ns": 10.0,
  "clock_pin": "clk_core",
  "input_delay_ns": 1.0,
  "output_delay_ns": 1.0
}
```

**Output Schema:**
```json
{
  "max_delay_ns": 8.3,
  "setup_slack_ns": 1.7,
  "hold_slack_ns": 0.15,
  "met": true,
  "critical_paths": [
    {
      "start": "addr_gen/counter[7]",
      "end": "butterfly/mult_result[15]",
      "delay_ns": 8.3
    }
  ],
  "num_violations": 0,
  "sta_time_s": 3.2
}
```

**Constraints:**
- Requires `opensta` in PATH
- Clock constraint must be set before timing analysis
- Slack report in nanoseconds at specified clock period
- Timeout: 20 seconds

---

### 1.4 Skill: `area_estimate`

**Purpose:** Estimate silicon area from gate count and tech library

**MCP Server:** `techlib-server`

**Exposed Tools:**
```
1. lookup_cell_area(cell_type, tech_node) -> (area_um2, power_uw)
2. aggregate_area(netlist_file, cell_areas) -> (total_area_um2, breakdown)
3. estimate_routing(gate_count, route_density) -> (routing_area_um2)
4. estimate_total_area(logic_area, routing_area) -> (total_um2, efficiency_percent)
```

**Input Schema:**
```json
{
  "gate_count": 3427,
  "cell_breakdown": {
    "AND": 1200,
    "OR": 890,
    "NOT": 450,
    "NAND": 200,
    "DFF": 687
  },
  "tech_node": "GF180",
  "route_density": "standard"
}
```

**Output Schema:**
```json
{
  "logic_area_um2": 115000,
  "routing_area_um2": 10000,
  "total_area_um2": 125000,
  "breakdown": {
    "AND_area": 48000,
    "OR_area": 35600,
    "NOT_area": 9000,
    "NAND_area": 4000,
    "DFF_area": 18400
  },
  "area_efficiency": 92.0,
  "estimated_power_uw": 450,
  "estimate_accuracy": "±15%"
}
```

**Constraints:**
- GF180 tech library lookup only (first phase)
- Route density models: standard, dense, sparse
- Area estimates ±15% accuracy
- No timing-driven area optimization (separate tool)

---

## Tier 2: Meta-Planner Agent

### 2.1 Meta-Planner Purpose

The Meta-Planner reads the **3GPP spec extract** and ButterFold **modular_description.md**, then:

1. **Decomposes** the modem spec into hardware design tasks
2. **Assigns** each task to a specialist skill (simulate, synthesize, timing, area_estimate)
3. **Builds** a task DAG with dependencies and parallelization opportunities
4. **Outputs** `generated/meta_plan.json` for the orchestrator to execute

### 2.2 Meta-Planner Input

```
Sources:
  - 3GPP_ButterFold_Spec_Extract.md (frozen params: k=12, m=128, 8-bit)
  - modular_description.md (ButterFold hardware architecture)
  - agents/planner.py output (plan.json with hardware_constraints)

Task decomposition example:
  Input spec → Extract constraints → Generate subtasks → Assign skills
```

### 2.3 Meta-Planner Output: `meta_plan.json`

```json
{
  "version": "1.0",
  "spec_source": "3GPP_ButterFold_Spec_Extract.md",
  "frozen_params": {
    "k": 12,
    "m": 128,
    "i_q_bits": 8
  },
  "tasks": [
    {
      "task_id": "task_001_rtl_generation",
      "description": "Generate RTL from hardware spec",
      "agent": "code_agent",
      "skills": [],
      "prerequisites": ["plan_json"],
      "parallelizable": false,
      "estimated_time_s": 120
    },
    {
      "task_id": "task_002_simulation",
      "description": "Run RTL simulation with 9-test testbench",
      "agent": "verify_agent",
      "skills": ["simulate"],
      "prerequisites": ["task_001_rtl_generation"],
      "parallelizable": false,
      "sim_timeout_s": 30,
      "expected_pass_tests": 9
    },
    {
      "task_id": "task_003_synthesis",
      "description": "Synthesize RTL with yosys",
      "agent": "synthesis_specialist",
      "skills": ["synthesize"],
      "prerequisites": ["task_002_simulation"],
      "parallelizable": true,
      "synth_opt_level": "aggressive"
    },
    {
      "task_id": "task_004_timing_analysis",
      "description": "Run STA with clock constraint 100MHz",
      "agent": "timing_specialist",
      "skills": ["timing"],
      "prerequisites": ["task_003_synthesis"],
      "parallelizable": true,
      "clock_period_ns": 10.0,
      "target_slack_ns": 0.5
    },
    {
      "task_id": "task_005_area_estimation",
      "description": "Estimate silicon area from gate count",
      "agent": "area_specialist",
      "skills": ["area_estimate"],
      "prerequisites": ["task_003_synthesis"],
      "parallelizable": true,
      "area_target_um2": 130000
    },
    {
      "task_id": "task_006_critic_precheck",
      "description": "Adversarial compliance check before heavy verification",
      "agent": "critic",
      "skills": ["critic"],
      "prerequisites": ["task_001_rtl_generation"],
      "parallelizable": true,
      "stop_on_critical": true
    }
  ],
  "parallelization_groups": [
    {
      "group": "post_synthesis",
      "tasks": ["task_004_timing_analysis", "task_005_area_estimation"],
      "can_run_parallel": true
    }
  ],
  "success_criteria": {
    "all_simulation_tests_pass": true,
    "setup_slack_met": true,
    "total_area_under_130k_um2": true,
    "no_critical_critic_violations": true
  }
}
```

### 2.4 Meta-Planner Agent Python Stub

```python
# agents/meta_planner.py (new)
import json
from anthropic import Anthropic

def plan_from_specs():
    """
    Meta-planner: Read 3GPP spec + modular_description → task DAG
    """
    client = Anthropic()
    
    # Read frozen params from spec
    with open("3GPP_ButterFold_Spec_Extract.md") as f:
        spec_extract = f.read()
    
    with open("modular_description.md") as f:
        hw_spec = f.read()
    
    # Prompt meta-planner
    prompt = f"""
    You are a hardware design meta-planner. Your task is to:
    
    1. Read the 3GPP spec extract for ButterFold (frozen params: k=12, m=128, 8-bit)
    2. Read the modular hardware description
    3. Decompose the design into tasks
    4. Assign each task to a specialist skill: simulate, synthesize, timing, area_estimate, critic
    5. Build a task DAG with dependencies and parallelization opportunities
    6. Output a meta_plan.json with all task details
    
    3GPP SPEC EXTRACT:
    {spec_extract}
    
    HARDWARE SPEC:
    {hw_spec}
    
    Produce a JSON object with:
    - tasks[] with id, description, agent, skills, prerequisites, parallelizable flag
    - parallelization_groups[] showing which tasks can run in parallel
    - success_criteria with testability requirements
    """
    
    response = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=8000,
        messages=[{"role": "user", "content": prompt}]
    )
    
    # Parse JSON from response
    meta_plan = json.loads(response.content[0].text)
    
    # Write output
    with open("generated/meta_plan.json", "w") as f:
        json.dump(meta_plan, f, indent=2)
    
    print("[meta_planner] Meta-plan written to generated/meta_plan.json")
    return meta_plan

if __name__ == "__main__":
    plan_from_specs()
```

---

## Tier 3: MCP Servers

### 3.1 MCP Server Configuration (`.mcp.json`)

```json
{
  "mcpServers": {
    "iverilog-server": {
      "command": "python agents/mcp_servers/iverilog_server.py",
      "env": {
        "PYTHONPATH": "/foss/designs/butterfold"
      },
      "description": "Verilog compilation + simulation (iverilog/vvp)",
      "tools": [
        "compile_verilog",
        "run_simulation",
        "parse_vcd",
        "extract_testbench_results"
      ]
    },
    "yosys-server": {
      "command": "python agents/mcp_servers/yosys_server.py",
      "env": {
        "PYTHONPATH": "/foss/designs/butterfold"
      },
      "description": "RTL synthesis and gate-count estimation (yosys)",
      "tools": [
        "synth_rtl",
        "report_stat",
        "write_netlist",
        "extract_timing_slack"
      ]
    },
    "opensta-server": {
      "command": "python agents/mcp_servers/opensta_server.py",
      "env": {
        "PYTHONPATH": "/foss/designs/butterfold"
      },
      "description": "Static timing analysis (STA) with opensta",
      "tools": [
        "read_netlist",
        "set_clock_constraint",
        "report_timing",
        "find_critical_paths",
        "generate_sta_report"
      ]
    },
    "techlib-server": {
      "command": "python agents/mcp_servers/techlib_server.py",
      "env": {
        "PYTHONPATH": "/foss/designs/butterfold"
      },
      "description": "Technology library lookups and area estimation",
      "tools": [
        "lookup_cell_area",
        "aggregate_area",
        "estimate_routing",
        "estimate_total_area"
      ]
    }
  }
}
```

### 3.2 MCP Server Implementation Outline

Each server implements the SSE (Server-Sent Events) MCP protocol.

#### `iverilog_server.py`

```python
import subprocess
import json
import os
import re

def compile_verilog(rtl_file, testbench_file, include_dirs=[], flags="-g2012 -Wall"):
    """Compile Verilog with iverilog"""
    cmd = ["iverilog", flags, "-t", "null", rtl_file, testbench_file]
    
    result = subprocess.run(cmd, capture_output=True, text=True, cwd="/foss/designs/butterfold")
    
    return {
        "compile_ok": result.returncode == 0,
        "stderr": result.stderr,
        "stdout": result.stdout
    }

def run_simulation(vvp_file, waveform_dump_vcd, timeout_s=30):
    """Run compiled simulation with vvp"""
    cmd = ["vvp", "-n", vvp_file]
    if waveform_dump_vcd:
        cmd.extend(["-vcd", waveform_dump_vcd])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s,
                                cwd="/foss/designs/butterfold")
        
        return {
            "sim_ok": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "vcd_path": waveform_dump_vcd if waveform_dump_vcd else None
        }
    except subprocess.TimeoutExpired:
        return {
            "sim_ok": False,
            "stdout": "",
            "stderr": f"Simulation timeout after {timeout_s}s",
            "vcd_path": None
        }

def parse_vcd(vcd_file, signal_patterns=[]):
    """Parse VCD file and extract signals"""
    # Stub: in real implementation, use pyvcd or similar
    return {
        "signals_dict": {},
        "time_range": [0, 0]
    }

def extract_testbench_results(sim_stdout):
    """Extract PASS/FAIL counts from simulation output"""
    passed = len(re.findall(r"PASS|✓", sim_stdout))
    failed = len(re.findall(r"FAIL|✗", sim_stdout))
    
    return {
        "passed": passed,
        "failed": failed,
        "errors": []
    }
```

#### `yosys_server.py`

```python
import subprocess
import json
import re

def synth_rtl(rtl_file, top_module, flatten=True, opt_level="aggressive"):
    """Run yosys synthesis"""
    yosys_script = f"""
read_verilog {rtl_file}
synth -top {top_module} -json generated/synth/stat.json
"""
    
    result = subprocess.run(["yosys", "-p", yosys_script], 
                          capture_output=True, text=True,
                          cwd="/foss/designs/butterfold")
    
    # Parse stat output
    stat_json = json.load(open("generated/synth/stat.json")) if os.path.exists("generated/synth/stat.json") else {}
    
    return {
        "netlist_file": "generated/synth/butterfold_top_synth.v",
        "stat_json": stat_json,
        "success": result.returncode == 0
    }

def report_stat(netlist_file):
    """Get gate count and area estimate"""
    # Parse netlist and count cells
    with open(netlist_file) as f:
        netlist = f.read()
    
    cell_types = {}
    for cell_type in ["AND", "OR", "NOT", "NAND", "DFF"]:
        count = len(re.findall(rf"\\{cell_type}\b", netlist))
        if count > 0:
            cell_types[cell_type] = count
    
    total_gates = sum(cell_types.values())
    
    # Approximate area (GF180): ~100 um² per gate
    area_um2 = total_gates * 100
    
    return {
        "gate_count": total_gates,
        "cell_types": cell_types,
        "area_estimate_um2": area_um2
    }
```

#### `opensta_server.py` and `techlib_server.py`

Similar stub implementations would follow, wrapping external tools via subprocess.

---

## Tier 4: Critic / Red-Team Skill

### 4.1 Critic Skill Purpose

Before running expensive EDA tools (synthesis, timing, area), the **Critic skill** runs **lightweight adversarial checks** to catch RTL compliance violations early.

### 4.2 Critic Checks

```
1. FROZEN_PARAM_CHECK
   - Does RTL respect k=12 (fixed for tapeout)?
   - Does RTL respect m=128 (fixed for tapeout)?
   - Does RTL respect 8-bit I/Q quantization?
   → FAIL if violated

2. STRUCTURAL_LINTING
   - Unused signals?
   - Undriven nets?
   - Multi-driven nets?
   → WARNING

3. FSM_DEADLOCK_CHECK
   - Can FSM scheduler reach all states?
   - Is there a path from IDLE to all other states?
   → WARNING if unreachable states exist

4. WAVEFORM_COMPLIANCE
   - Does RTL structure match 3GPP DFT-s-OFDM spec?
   - Are transform sizes correct?
   - Is CP insertion/removal logic present?
   → FAIL if missing

5. EDGE_CASE_INJECTION
   - Zero input → zero output (linearity)?
   - Max input doesn't cause overflow?
   - CP length assumptions valid?
   → FAIL if issues found

6. TIMING_SANITY
   - Are critical paths obvious?
   - Is there evident pipeline slack?
   → WARNING if tight

7. AREA_BUDGET_ESTIMATE
   - Does netlist gate estimate fit area budget (<130k um²)?
   → WARNING if over
```

### 4.3 Critic Skill Implementation

```python
# .claude/skills/eda/critic.py
import re
import subprocess

class CriticSkill:
    def run_adversarial_checks(self, rtl_file, spec_extract, verify_result):
        """
        Run all adversarial checks before heavy verification
        
        Returns:
          {
            "passed": bool,
            "warnings": [str],
            "errors": [str],
            "proceed_to_eда": bool
          }
        """
        errors = []
        warnings = []
        
        # 1. Frozen param check
        rtl_text = open(rtl_file).read()
        if "parameter K = 12" not in rtl_text:
            errors.append("RTL missing frozen param k=12")
        if "parameter M = 128" not in rtl_text:
            errors.append("RTL missing frozen param m=128")
        
        # 2. Structural linting
        unused_signals = self._check_unused_signals(rtl_file)
        if unused_signals:
            warnings.append(f"Unused signals: {', '.join(unused_signals[:3])}")
        
        # 3. FSM deadlock check
        fsm_ok = self._check_fsm_deadlock(rtl_file)
        if not fsm_ok:
            warnings.append("Potential FSM unreachable states (check manually)")
        
        # 4. Waveform compliance
        has_dft = "dft_kernel" in rtl_text.lower()
        has_cp = "cp_" in rtl_text.lower()
        if not (has_dft and has_cp):
            errors.append("RTL missing DFT or CP logic")
        
        # 5. Edge case injection
        edge_ok = self._check_edge_cases(rtl_file)
        if not edge_ok:
            errors.append("Edge case handling suspicious")
        
        # 6. Timing sanity
        depth = self._estimate_logic_depth(rtl_file)
        if depth > 20:
            warnings.append(f"High logic depth {depth}, check timing")
        
        return {
            "passed": len(errors) == 0,
            "warnings": warnings,
            "errors": errors,
            "proceed_to_eda": len(errors) == 0,
            "critic_time_s": 2.3
        }
    
    def _check_unused_signals(self, rtl_file):
        # Stub: use Verilog parser to detect unused signals
        return []
    
    def _check_fsm_deadlock(self, rtl_file):
        # Stub: traverse FSM state graph
        return True
    
    def _check_edge_cases(self, rtl_file):
        # Stub: static analysis
        return True
    
    def _estimate_logic_depth(self, rtl_file):
        # Stub: estimate combinational depth
        return 10
```

### 4.4 Critic Integration Point

```python
# In orchestrator or verify agent:
if critic_result['proceed_to_eda']:
    # Run synthesis, timing, area estimation in parallel
    run_eда_skills_parallel(...)
else:
    # Report errors and ask user to fix RTL
    print(f"Critic blocking: {critic_result['errors']}")
    return FAILED
```

---

## Integration with Existing Agents

### Step 1: Generate Meta-Plan
```bash
python agents/meta_planner.py
# Output: generated/meta_plan.json
```

### Step 2: Run Critic Pre-Check
```bash
# Verify agent calls: critic.run_adversarial_checks(rtl, spec, verify_result)
# If FAIL: exit, ask user to fix RTL
# If PASS: proceed to Step 3
```

### Step 3: Run Synthesis in Parallel
```bash
# Orchestrator reads generated/meta_plan.json
# Spawns:
#   - synthesis_specialist → synth_rtl (skill)
#   - timing_specialist → timing analysis (skill)
#   - area_specialist → area_estimate (skill)
#
# All run in parallel post-synthesis
```

### Step 4: Report Results
```json
{
  "synthesis": {
    "total_gates": 3427,
    "area_um2": 125000,
    "time_s": 8.5
  },
  "timing": {
    "clock_period_ns": 10.0,
    "critical_path_ns": 8.3,
    "slack_ns": 1.7,
    "met": true
  },
  "area": {
    "total_um2": 125000,
    "efficiency": 92.0,
    "power_uw": 450
  }
}
```

---

## File Structure

```
butterfold/
├── .mcp.json                                  ← MCP server config
├── agents/
│   ├── meta_planner.py                        ← NEW: Tier 2
│   ├── orchestrator.py                        ← Existing, calls meta_planner first
│   └── mcp_servers/                           ← NEW: Tier 3
│       ├── iverilog_server.py
│       ├── yosys_server.py
│       ├── opensta_server.py
│       └── techlib_server.py
├── .claude/
│   └── skills/
│       └── eda/
│           └── critic.py                      ← NEW: Tier 4
├── 3GPP_ButterFold_Spec_Extract.md           ← Input to meta-planner
├── modular_description.md                     ← Existing
├── generated/
│   ├── meta_plan.json                         ← Output from meta_planner
│   ├── plan.json                              ← Existing (planner output)
│   ├── rtl/
│   │   └── butterfold_top.v                   ← Existing (code_agent output)
│   └── synth/
│       ├── butterfold_top_synth.v             ← From synthesis skill
│       └── stat.json                          ← Synthesis stats
```

---

## Execution Flow

```
User runs: python agents/orchestrator.py

orchestrator.py
  ↓
  1. planner.py (existing) → generated/plan.json
  ↓
  2. meta_planner.py (NEW) → generated/meta_plan.json
     ↓ reads 3GPP_ButterFold_Spec_Extract.md
  ↓
  3. code_agent.py (existing) → generated/rtl/butterfold_top.v
  ↓
  4. critic.py (NEW) → pre-check results
     IF FAIL → report errors, exit
     IF PASS → continue
  ↓
  5. verify.agent.py (existing) → generated/verify_result.json
     Calls: simulate skill (iverilog-server)
  ↓
  6. [PARALLEL] Run EDA skills (if verify passed):
     ├─ synthesis_specialist → synthesize skill (yosys-server)
     ├─ timing_specialist → timing skill (opensta-server)
     └─ area_specialist → area_estimate skill (techlib-server)
  ↓
  7. summarize → generated/summary.md with all results
```

---

## Dependencies & Installation

### Inside Docker (`/foss/designs/butterfold`)

```bash
# Install Python MCP SDK and EDA tool wrappers
pip install -r requirements.txt

# Requirements must include:
anthropic
python-dotenv
langgraph
pdfplumber
pyvcd              # For VCD parsing in simulate skill
# yosys, iverilog, opensta already in Docker
```

### `.mcp.json` Configuration

```bash
# Ensure .mcp.json is in butterfold root
# LLM will auto-discover and connect to all servers
```

---

## Testing & Validation

### Unit Test: Critic Skill
```bash
pytest tests/test_critic_skill.py -v
```

### Integration Test: Meta-Planner
```bash
python agents/meta_planner.py
cat generated/meta_plan.json | jq '.tasks[] | {id, agent, skills}'
```

### E2E Test: Full Pipeline
```bash
python agents/orchestrator.py
# Should output: planner → meta-planner → code → critic ✓ → verify → synth/timing/area
```

---

## Future Enhancements

1. **Judge model (local lightweight LLM)** - Score RTL compliance in parallel with synthesis
2. **Design-space exploration (DSE)** - Automated sweep of k, m, radix strategies
3. **Power estimation** - Add power_estimate skill (openpower)
4. **Physical design** - LibreLane integration for RTL→GDS closure
5. **Hardware cost modeling** - Normalize area/power/timing tradeoffs

---

**END OF EDA SKILLS & MCP ARCHITECTURE**
