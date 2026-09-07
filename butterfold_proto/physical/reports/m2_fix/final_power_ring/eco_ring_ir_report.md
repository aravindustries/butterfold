# ECO-ring quantitative IR (existing implementation)

This is a measured baseline of the **existing ECO power-ring** on `main`.
It is not a PDN architecture comparison and does not claim an optimal ring.
The layout was not modified.

```
branch: main
HEAD:   79eda92f50182f1126faafff5c78479ac71dcbe7
        79eda92f Merge pull request #5 from aravindustries/power_ring

GDS path:   gds/butterfold_top.gds
            (byte-identical: butterfold_proto/gds/butterfold_top.gds)
GDS SHA256: cb44902373b3189249cefb8f7085823e1aa2b0dcd9e483ff7426c30397c5bf9f

ODB path:   physical/results/m2_fix/power_ring.odb
ODB SHA256: 8883b46559644aef38db675259f248addb548749ea0a8b5fead21fbe6cab5cc6

OpenRCX SPEF path:
    physical/reports/m2_fix/final_power_ring/evidence/eco_ring_ir/eco_ring.max.spef

analysis corner:          max_ss_125C_4v50
supply voltage:           VDD = 4.5 V, VSS = 0 V
power-grid analysis method:
    fresh OpenRCX extract_parasitics (-lef_res, rules.openrcx.gf180mcuD.max)
    from power_ring.odb, then OpenROAD analyze_power_grid / check_power_grid
    with existing irdrop/VDD.vsrc (6 north pads, y=1674.500)
    and irdrop/VSS.vsrc (6 west pads, x=0.500)
    vectorless instance power, no VCD/SAIF
```

ODB SHA after analysis is unchanged. No `write_db` / route / ring ECO.

## Fresh measurement

| Item | Value |
|---|---|
| VDD_WORST_IR_DROP_V | **0.206 V** (CSV 0.205852 V) |
| VDD_WORST_IR_DROP_PERCENT | **4.57 %** of 4.5 V |
| VDD_WORST_LOCATION | instance `FILLER_2_1854` Metal1 (1045.24, 35.28) µm; V = 4.294148 V |
| VSS_WORST_IR_RISE_V | **0.0889 V** (CSV 0.088860 V) |
| VSS_WORST_LOCATION | instance `FILLER_171_1741` Metal1 (985.552, 886.264) µm; V = 0.088860 V |
| Vectorless power | 0.120 W |
| PSM_VDD | **PASS** (PSM-0040 all VDD shapes connected) |
| PSM_VSS | **PASS** (PSM-0040 all VSS shapes connected) |

PDNSim summary (same session as the fresh SPEF):

```
VDD  Worstcase IR drop: 2.06e-01 V   Percentage drop: 4.57 %
VSS  Worstcase IR drop: 8.89e-02 V   Percentage drop: 1.97 %
```

## Comparison

| | VDD worst drop | VSS worst rise |
|---|---:|---:|
| Pre-ring (via-fix) | 0.125 V | 0.0889 V |
| Previously measured ECO-ring | 0.206 V | 0.0889 V |
| This fresh OpenRCX + PDNSim run | **0.206 V** | **0.0889 V** |

The fresh measurement **reproduces** the previous ECO-ring result (VDD 0.206 V,
VSS 0.0889 V) within PDNSim’s reported precision. VSS matches the pre-ring
value. VDD remains 0.081 V worse than pre-ring in this ECO-ring topology.

## Conclusion

The current ECO-ring implementation was re-characterized using a fresh
OpenRCX extraction from the accepted final ODB. Worst-case VDD IR drop is
0.206 V (4.57% of 4.5 V) and VSS rise is 0.0889 V. All VDD/VSS PDN shapes remain
connected.

This is the measured baseline of the existing ECO-ring implementation before
any native `PDN_CORE_RING` rehardening.

## Raw evidence

Directory: `physical/reports/m2_fix/final_power_ring/evidence/eco_ring_ir/`

| File | Role |
|---|---|
| `eco_ring.max.spef` | Fresh OpenRCX max SPEF from `power_ring.odb` |
| `analyze_power_grid.log` | Full OpenROAD / PDNSim log |
| `eco-ring-VDD.csv` | Instance VDD voltage map |
| `eco-ring-VSS.csv` | Instance VSS voltage map |
| `psm_connectivity.txt` | PSM-0040 VDD/VSS connectivity |
| `vectorless_power.rpt` | Vectorless power used by PDNSim |
| `SHA256SUMS` | SHA256 of the artifacts above |
