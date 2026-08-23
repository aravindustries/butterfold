# 04 — Reset electrical

## Result

**PASS** at max-SS with `rst_n` visible: slew **0**, cap **0**.

Production SDC still has `set_case_analysis 1 rst_n`. That was unset
**in-memory only** for repair and for the reset-visible dump.

## Topology (native `report_net rst_n`)

Port `rst_n`: 173 loads, pin C 1.66 pF, wire C 0.51 pF, total **2.16 pF**.
First-level buffers on the port: `wire263` `clkbuf_20`, `wire264`/`wire265`
`buf_20`. Depth ~2 (`wire268` / `load_slew269` on `net263`).

## Evidence

| Item | Path |
|---|---|
| Reset-visible violators (empty = 0) | [evidence/reset/reset_electrical.rpt](evidence/reset/reset_electrical.rpt) |
| `report_net rst_n` | [evidence/reset/reset_topology.rpt](evidence/reset/reset_topology.rpt) |
| `RESET_VISIBLE_SLEW 0` / `RESET_VISIBLE_CAP 0` | [evidence/setup/max_ss_setup_summary.rpt](evidence/setup/max_ss_setup_summary.rpt) |

- Tool: OpenSTA `unset_case_analysis` + `report_check_types` / `report_net`
- Original: `sta_max_ss/electrical_reset_visible.rpt`, `sta_max_ss/reset_net.rpt`, `04_sta_max.log`
