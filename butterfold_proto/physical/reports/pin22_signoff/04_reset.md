# 04 — Reset electrical

**PASS**

After `unset_case_analysis rst_n`:

| Check | Count |
|---|---|
| reset-visible slew | 0 |
| reset-visible cap | 0 |
| fanout | 0 |

Reset tree: regional `clkbuf_16` / `clkbuf_8` on the compact floorplan.

Evidence: [sta_filled.log](evidence/setup/sta_filled.log),
[reset_visible.rpt](evidence/reset/reset_visible.rpt)
