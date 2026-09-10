# ACH integration shell on the native PDN core ring

Work done on top of `native-power-ring` (`b5d2596d`, Arav Sharma).
Nothing here is pushed. Artifacts under `physical/results/native_power_ring/`.

## 1. Finding: the shipped native-ring GDS has no ACH shell

`gds/butterfold_top.gds` on `native-power-ring` (SHA `d283d354…`) is the
**23-pin core only**:

| check | shipped `cb449023` (ECO ring) | `d283d354` (native ring) |
|---|---:|---:|
| `_PDRV0`/`_PDRV1` labels | 302 | **0** |
| `ach_*_tie0` instances | 1673 | **0** |
| `clk_PU` / `clk_PD` labels | 2 | **0** |
| DEF `PINS` | 135 | **23** |

Expected: a reharden starts from the 23-port RTL, and the 135 ACH terminals
plus 102 pad-control tie-offs are added afterwards by
`generate_final_ach_shell.py`. That step was not re-run. As committed, this
GDS reintroduces the original review finding (digital I/O controls undriven).

## 2. Shell re-applied — verification PASSES

`results/native_power_ring/shell2/` — GDS `e09b2232…`
(geometry identical to `shell/` `a00e5161…`; `filled.def` md5 matches, only
GDS timestamps differ, so signoff below applies to both).

| check | result |
|---|---|
| Netgen LVS | **Circuits match uniquely**, 11736 / 11736 nets |
| KLayout DRC, 16 tables | **0** (metal1-5, metaltop, via1-4, poly2, nplus, pplus, comp, contact, nwell) |
| MSLOT (MSLOT.0–.9) | **0** |
| routing DRC | 0 |
| `check_power_grid` | PSM-0040 both rails |
| ACH connectivity audit | 135/135, 102/102 controls, 0 floating, 0 illegal, 0 errors |
| power ring | closed 4 sides both rails, 2.0 µm, PDN-generated |
| BTerms / DEF PINS | 135 |
| die | 1110 × 1675 µm, 1.859250 mm² |
| antenna (OpenROAD) | 1 |

Magic extraction reports 503 errors — **identical count to arav's own
native-ring run**, i.e. a property of the deck on this design, not the shell.

## 3. Open problem: setup timing

| build | setup WNS max_ss | violations | hold min_ff |
|---|---:|---:|---:|
| arav `filled.odb` (no shell) | **+5.351** | 0 | +0.301 |
| `shell2` (shell + full reroute) | **−4.167** | 453 | +0.401 |
| `close1` (repair, margin 1.5) | −2.122 | 251 | +0.402 |
| `close2` (repair, margin 3.5) | **−1.511** | 215 | +0.404 |
| `close3` (margin 2.5, GRT adj 0.15) | −2.160 | 242 | +0.400 |

Worst path is ordinary core logic, **not** the shell: startpoint `_18565_`
(dffrnq_2), 26 combinational levels through `_09390_ … clone20/ZN`, endpoint
`_18299_/D`. No `ach_*` cell on it. All 453 endpoints hang off that one cone.

Cause: the shell's 112 nets require routing, which requires destroying all
11,519 existing signal routes. Arav's database was closed against *its own*
routing; clearing it discards that closure. `repair_timing` tops out at about
**+1.9 ns** on this netlist while re-routing costs about **3.4 ns**, so the
loop does not converge — three iterations with different margins and
congestion settings landed between −1.5 and −2.2.

`close2` (`db0ccc18…`) has the best timing but has **not** had LVS/DRC/MSLOT run.

## 4. What is needed

The closure method, not more generic repair. Arav's flow produced a closed
design twice (`m2_fix` +0.119 ns, native ring +5.351 ns); reproducing it from
outside did not work.

Also worth confirming: his +5.351 ns run and an equivalent fresh LibreLane
reharden of the same RTL/SDC (`core-ring-rebuild`, `18bd0b78`) differ by ~16 ns.
Both used a propagated clock and extracted SPEF. That gap is unexplained.

## 5. Reproduction

```
scripts/generate_final_ach_shell.py D03.def/D03/project_defs/ACH/D03_ACH_interface.yaml \
    results/native_power_ring/ach_shell.tcl results/native_power_ring/ach_shell.json
SHELL_OUT=.../shell2 scripts/apply_ach_shell.sh     # 23 -> 135 BTerms, +112 cells
SHELL_OUT=.../shell2 scripts/route_ach_shell.sh     # clear routes, GRT, antenna, DRT
SHELL_OUT=.../shell2 scripts/finish_ach_shell.sh    # fill, PSM, streamout
scripts/unix/lvs_ach_shell.sh                       # magic + netgen
scripts/unix/native_ring_run_drc.sh <gds> <out>     # 16 tables
scripts/unix/run_mslot.sh                           # MSLOT
```

Notes for anyone re-running: arav's databases need `/foss/tools/openroad`
(schema 0.129), LibreLane's need `/foss/tools/openroad-librelane` (0.126);
`detailed_route` fails with DRT-1231 unless existing wires and guides are
destroyed first; several committed scripts have CRLF line endings and
hardcode `/headless/aravindustries-repos/...`.
