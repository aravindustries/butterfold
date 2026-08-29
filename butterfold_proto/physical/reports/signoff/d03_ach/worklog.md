# D03/ACH integration worklog

## 2026-08-28 — start

- Branch `def-integration` (HEAD `632e9d35`). No branch switch.
- Working tree: untracked `.env` / `.venv/` only. Preserved.
- Canonical GDS SHA `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` (this branch; prompt’s `6d66a476…` is the unmerged North/West pin-placement promotion). **Not overwritten.**
- Variant ACH, 23 participant pins, official padring + translated user DEF inspected.
- Native ApplyDEFTemplate: padring DEF incompatible (slot names); `D03_ACH.def` incompatible (pad extras / split bi pins); 23-pin extract of official geometry matches all participant terminals.
- Config: `FP_DEF_TEMPLATE=dir::d03_ach_user_template.def`, `FP_SIZING=absolute`, DIE 1110×1675, CORE site-snapped with proven margin multiples, copy power pins, permissive only for LibreLane POWER matching quirk.
- Next: `librelane --to Odb.ApplyDEFTemplate` before full P&R.

## 2026-08-28 — ApplyDEFTemplate native LibreLane PASS

Run `physical/librelane/runs/d03_ach_fp_template/` (`--to Odb.ApplyDEFTemplate`).

- `FP_SIZING=absolute` die **1110 × 1675 µm**, core **6.72 20.16 1103.20 1653.12** (324 rows × 1958 sites).
- Effective util 39% (same netlist, larger ACH slot). Density not retuned.
- IO placement skipped (template set). Custom IO skipped (none configured).
- All 23 participant pins written at official translated Metal2 abutment boxes (verified µm-for-µm vs `D03_ACH.def`).
- SRAM still FIXED at 51.120 / 531.120, 720.560 µm.
- LibreLane metric warning “template die 11100×16750” is a UNITS-200 vs 2000 reporting artifact; placed pin dbu/2000 matches 1110×1675.
- POWER matching warnings only for VDD/VSS (LibreLane quirk); `--copy-def-power` still placed them.
- PDN-0110: one VSS Metal3–Metal4 via not inserted at (179.14, 751.45). Not redesigned yet.
- Canonical GDS `5a99213a…` not overwritten.

Next: resume proven Classic flow from `OpenROAD.GlobalPlacement` on this ODB. Do not launch full KLayout/Netgen until routed candidate is mature.

## 2026-08-28 — DRT-0073 pin access

First P&R (`d03_ach_pnr`) failed at TritonRoute:

```
DRT-0073 No access point for clkbuf_3_7_0_clk_regs/I (clkbuf_8) MY @ 599.20,1290.24
DRT-0073 No access point for clkbuf_3_6_0_clk_regs/I (clkbuf_8) R0 @ 616.00,1280.16
```

`clkbuf_8` pin I is Metal1 on the cell’s left (R0) / right (MY). Both instances sit one site (0.56 µm) from a `filltie` (CELL_PAD_EXCLUDE, zero padding). That is not enough M1 access.

Response (evidence-based, not preemptive): `DPL_CELL_PADDING` 2 → **4** (2 sites/side). CTS legalizes with that padding. Resume from `OpenROAD.CTS` using the already-legal post-DPL ODB. GPL padding left at 2 (GPL not rerun).

## 2026-08-28 — routed candidate (not promoted)

- `d03_ach_pnr_pad4` first DRT: **0 violations**, wirelength 1.092 mm. Post-DRT antenna re-route (`DRT_ANTENNA_REPAIR_ITERS=3`) failed `DRT-1231 delaybuf_3_core_clk/I`. Kept `drt-run-0`. Set `DRT_ANTENNA_REPAIR_ITERS=0`.
- Fill + RCX + STA completed. Disconnected-pin checker clear.
- max-SS setup **WNS -8.578 ns / TNS -3015 ns / 735 violators** (same class as production pre-ECO -9.51 ns). Hold min-FF **WNS 0**. 8 antenna nets.
- IR: template M2 VDD/VSS ports were isolated (PDN generated **before** ApplyDEFTemplate). ECO `eco_connect_template_pg.py` stitches M2 and vias to Metal4. `check_power_grid` **VDD_OK VSS_OK**.
- Magic stream-out: SHA `ae6a454f94a8b64d1f04b2583388233938cf3712cfa2de0077df6f6451f54ff9` under `runs/d03_ach_magic/final/gds/`. **Not promoted** (setup/antenna/LVS/DRC gate incomplete).
- Extracted `repair_timing` hits OpenROAD GRT/resizer SIGSEGV / RSZ-0074 on this routed ODB. Frozen production instance ECO cannot be replayed (new names). Setup ECO remains open.

Canonical `gds/butterfold_top.gds` still `5a99213a…`.

## 2026-08-28 — GDS / branch lineage (audit only, no merge)

```
git branch --show-current  =>  def-integration
HEAD = main = origin/main = 632e9d35 ("added DEF files")
```

| Tree | `gds/butterfold_top.gds` SHA-256 |
|---|---|
| `def-integration` / `main` (same commit) | `5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6` |
| `pin-placement-redesign` (`820875c4`) | `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12` |

`6d66a476…` is the North/West pin-placement promotion. That branch was **never merged** to `main`. `def-integration` was created from current `main` (DEF files) and therefore still carries the older team-side GDS `5a99213a…`.

North/West artifacts (`pin_order.cfg`, `place_power_pins_north.tcl`, `nw_extracted_setup_close.tcl`) exist **only** on `pin-placement-redesign`, not on this branch. That is correct: ACH `FP_DEF_TEMPLATE` supersedes NW pin-order.

Continue integration on `def-integration`. The final ACH GDS will supersede both historical files.

## 2026-08-28 — setup path classes (extracted max-SS)

735 violators, TNS −3014.75 ns, WNS −8.578 ns.

| Startpoint | Count | Role |
|---|---:|---|
| `_20041_` (`fft128_active`, dffrnq_4) | **689** | scheduler FFT-active |
| `_18568_` | 19 | |
| `_18564_` | 14 | |
| `_18566_` | 13 | |

Endpoints: 682 stdcell FFs, 52 SRAM (26 lo + 26 hi: A/D/WEN/CEN/GWEN), 1 `din_ready_o`.

Same class as production pre-ECO: high-fanout `fft128_active` → weak `_1` cells with slow slew → SRAM/control. Production closed it with `repair_design` + `repair_timing` on a **pre-fill** ODB, then rip signal wires + GRT/DRT — **not** by replaying instance names.

Method to reuse: `nw_extracted_setup_close.tcl` (pin-placement branch) / `postroute_setup_close.tcl` methodology.

Setup ECO table (extracted max-SS):

| attempt | WNS | TNS | violators | DRT | change |
|---|---:|---:|---:|---|---|
| 0 baseline | -8.578 | -3015 | 735 | 0 | template P&R |
| 1 | -6.68 | -1844 | (50 shown) | 2 M1 shorts | pre-fill repair_timing 83 up / 13 buf, full re-route |
| 2b | -6.63 | -1729 | 40 shown | **0** | 159× `_1→_4` on prior critical cells; legalize max_cap clkbuf_20→8 |
| 3 | -4.60 | -1234 | 40 shown | **0** | 79 more `_4` swaps; legal; DRT 0. Remaining `_18564_` + rst_n RN slew ~20 ns (~1142 electrical) |
| 4 | -5.37 | -1117 | 40 shown | **0** | 29 path swaps + fanout243→clkbuf_16 + rst_n tree (1+8+64 clkbuf_16, 1460 loads). Electrical 1142→10. WNS slipped: SRAM capture clock 2.23 vs launch 2.82 after full signal/clock rip; `_10340_` aoi22_1 4.27 ns; `fanout259` dlya_1 2.87 ns |

Lineage (audit only, no merge): `def-integration` == `main` == `origin/main` == `632e9d35`. Git-tree SHA of `gds/butterfold_top.gds` on this branch and `main` is `5a99213a…`. SHA `6d66a476…` lives only on unmerged `pin-placement-redesign` (`820875c4`). Continue here; final ACH GDS supersedes both.

ECO4 electrical win is kept (rst_n tree). ECO5 from eco4 ODB: 38 remaining `_1/_2` + `dlya_1→clkbuf_16` + 3 load buffers on 4 ns stages; **preserve CLOCK wires** to stop SRAM capture-skew regression.

Dominant ECO4 remaining class: `_20041_` (`fft128_active`) and `_18566_` → SRAM D / stdcell FFs. Not clock-frequency, not RTL.

| 5 | -2.92 | -555 | 200 shown (min -2.92 max -1.27) | **0** | 38 path `_1/_2` + dlya→clkbuf_16 + 3 load bufs; CLOCK wires preserved. Electrical 10→3. Startpoints `_18692_`/`_20037_`. Remaining class: 152× mux2_1 + clkinv_1/xnor2_1/aoi22_1 |

ECO6 from eco5: 287 combinational/startpoint swaps (no endpoint dffq_1), SRAM pin-driver buf_8, 5 load buffers on >2.2 ns stages.

| 6 | DRT-0206 | — | — | fail | CLOCK preserve after large legalize stale `clknet_leaf_31` |
| 6b | -2.00 | -363 | 40 shown | **0** | same 287 swaps; full clock+data rip |
| 7 | -1.82 | -192 | 40 | **0** | 36 swaps + 7 load bufs. Q-buffer on `_18691_` added 0.38 ns (later removed) |
| 8 | -2.11 | -311 | — | **0** | 115 mux2_1→4 **regressed** (input-cap). Discarded |
| 8b | -1.46 | -161 | 40 | **0** | from eco7: drop Q-buf; 28 high-delay `_1/_2` only (no mux2 army) |
| 9 | -1.08 | -77.5 | 40 | **0** | `_20010_` prefix `nand2_1`/`aoi21_1`/`dffrnq_1` |
| 10 | -0.76 | -43.8 | 40 | **0** | FO12 `_15936_` buffer, clone `load_slew111` |
| 11 | -0.60 | -18.5 | 40 | **0** | `_20055_` dffrnq_2→4 |
| 12 | -0.43 | -18.2 | 40 | **0** | remaining mux2_1 2.6 ns + tail buf |
| 13 | -0.35 | -12.9 | 40 | **0** | WNS-path `and2_1` + buf_4 |
| 14 | -0.29 | -4.0 | 40 | **0** | useful-skew clkbuf_16 on 40 capture CLKs (not launch leaf_9). Electrical 0 |
| 15 | -0.06 | -0.36 | 11 | **0** | double clkbuf on remaining capture leaves. Electrical 3 |
| 16 | -0.24 | -0.49 | — | **0** | extra skew + SRAM CLK disconnect **regressed** (dont_touch SRAM). Discarded |
| 16b | -0.08 | -0.15 | 3 | **0** | data-only from eco15; CLOCK preserved; 3 violators (`_18433_` + SRAM GWEN `nor3_1`) |
| 18b | -0.08 | -0.08 | 1 | wires kept | in-place `nor3_1→4` + GWEN `clkinv_8`, local legalize, **no re-route**. SRAM closed. Only `_18433_` -0.08 |
| 18i | **0.00** | **0.00** | 0 | **0** | extra capture `clkbuf_16` in known-legal hole (11.2, 25.2) µm; full GRT keeping existing wires. `_18433_` slack +0.68. PLACE_OK. DIE 1110×1675, CORE 6.72/20.16/1103.20/1653.12, 23 pins, 2 SRAM |
| hold19c | setup 0 / hold **0.00** | 0 | 0 | **0** | `dlya_4` on `input1/2/3` (din[0..2] hold class -0.39). Rip only net1/2/3 + mid nets. DRT_OK PLACE_OK |
| ant20b | setup **0.00** / hold **0.00** | 0 | 0 | **0** | `repair_antennas -iterations 3` with **all cells FIRM**, then DRT. Antenna **0 nets / 0 pins**. PLACE_OK |

## Current candidate (not promoted)

ODB: `physical/results/d03_ach_setup_eco/butterfold_top_ant20b.odb`

| check | result |
|---|---|
| extracted max-SS setup | WNS 0.00 / TNS 0.00 / 0 violators (worst path slack +0.04 MET) |
| min-FF hold | WNS 0.00 / TNS 0.00 |
| antenna | 0 nets, 0 pins |
| DRT | 0 (ant20b from repair_antennas + DRT_OK) |
| placement | CHECK_PLACEMENT_OK |
| DIE | 1110 × 1675 µm |
| CORE | 6.72, 20.16, 1103.20, 1653.12 |
| pins | 23 |
| SRAM | exactly 2 × sram256x8m8wm1 |
| electrical | **remaining:** max-slew `_12379_/ZN` 7.36 vs 7.20 (−0.16 ns); max-cap `_11319_/ZN` 0.20 vs 0.19 (−0.00). Far-hole electrical buffers (eco21b) **worsened** slew (long M2). Do not use eco21b |
| rst_n tree | 1+8+64 clkbuf_16 from ECO4; RN slew closed |
| KLayout / Magic+Netgen / IR / GDS promotion | **not run** — close remaining 0.16 ns slew first, then one same-GDS signoff pass |

`repair_timing` SIGSEGV on extracted routed ODB confirmed once (skip_buffering also SIGSEGV). Targeted swapMaster + keep-wire GRT is the working method.

Canonical `gds/butterfold_top.gds` still `5a99213a…`. Not overwritten.

## 2026-08-28 — hold25/26 (antenna-local dlya vs remaining hold)

Moving `hold_dlya_din{0,1,2}` next to `input1/2/3` (hold25) closed antenna (0/0) but shortened the din[0] min path: hold WNS **−0.08** (`din[0]` → `_18681_`). din[0] max-SS slack was **+15.38 ns**. Two FREE sites immediately right of `hold_dlya_din0`.

| attempt | setup WNS/TNS | hold WNS/TNS | DRT | ANT | PG | change |
|---|---|---|---|---|---|---|
| hold25 | 0 / 0 | **−0.08 / −0.08** | 0 | 0/0 | VDD_OK VSS_OK | move dlya next to inputs (antenna) |
| hold26 | 0 / 0 | **0.00 / 0.00** | 0 | 0/0 | VDD_OK VSS_OK | in-place `hold_dlya_din0` `dlya_4`→`dlyb_4`; rip 2 nets; keep-wire GRT/DRT |

ODB: `physical/results/d03_ach_setup_eco/butterfold_top_hold26.odb`. Electrical report empty. Worst remaining hold +0.06 MET (`din[2]`).

Next: signoff views + Magic GDS + KLayout + Netgen LVS + IR. Do not promote until that gate passes.

## 2026-08-28 — hold26 closed remaining −0.08 ns hold

ODB `butterfold_top_hold25.odb` had one min-FF violator: `din[0]` → `_18681_` slack **−0.08 ns**. `din[2]` already MET. Two FREE sites immediately right of `hold_dlya_din0` (MX, y=1174.32 µm). din[0] max-SS slack **+15.38 ns**.

| attempt | setup WNS/TNS | hold WNS/TNS | DRT | ANT | PG | change |
|---|---|---|---|---|---|---|
| hold26 | **0 / 0** | **0.00 / 0.00** | **0** | 0/0 | VDD_OK VSS_OK | in-place `hold_dlya_din0` `dlya_4`→`dlyb_4`; rip 2 nets; keep-wire GRT/DRT |

DIE 1110×1675, CORE 6.72/20.16/1103.20/1653.12, 23 pins µm-for-µm vs ACH template, SRAM exactly 2 at 51.120 / 531.120, 720.560. Reset-visible slew/cap 0. Electrical empty. PLACE_OK.

## 2026-08-28 — fill restored; Mag GDS; DRC/LVS/IR (not promoted)

ECO ODB had **20022** instances (pre-fill). Original filled Mag GDS had **54749**. Missing fill caused Mag VNW islands and unfilled Mag-GDS well/implant DRC.

`d03_fill26.tcl`: FIRM all, `filler_placement` 33704 fillers → **53726** instances. PLACE_OK, VDD_OK, VSS_OK.

Filled extracted STA: setup **0/0**, hold **0/0**, electrical 0, reset 0, antenna 0/0.

LibreLane Magic.StreamOut of filled DEF: SHA-256

```
83deb30866187b66c2b5ca768d23ce67c6b0a8f0c310c8fa34ea092b4367699b
```

`physical/results/d03_ach_candidate/butterfold_top.gds` (exact Mag GDS). **Not copied to `gds/butterfold_top.gds`.**

KLayout (filled Mag GDS, `run_drc.py --mp=8` + solo contact/ldpmos/nat + unified MSLOT + antenna_only + density_only):

| check | result |
|---|---|
| geometry tables (63 lyrdb) | **0 items** except contact |
| contact | **9 × CO.6a** (5 nm Mag-grid EOL, not ECO shorts) |
| MSLOT unified | **0 items** |
| KLayout antenna | **0 items** |
| density DCF.1d / PL.8 / M1.4 | PASS (COMP 42.2%, Poly2 32.1%, M1 33.7%) |
| M2.4–MT.3 | INTEGRATOR FILL PENDING (15.3 / 17.7 / 7.6 / 3.4 / 3.4%) |

Netgen full-device LVS (Mag GDS extract, SRAM blackbox, filled pnl + CELL_SPICE_MODELS):

- stdcells uniquely match at MOSFET level
- top devices **11768 = 11768**
- nets 11774 vs 11769
- SRAM 2
- **Final result: Top level cell failed pin matching** (Mag extract shorts VDD/VSS ports; same Mag warning as prior unique-match GDS, but this Mag GDS extract ties instance VDD pins to VSS)

IR `analyze_power_grid -source_type FULL` on filled ODB: grid connected; VDD worst **488 mV** (10.9%), VSS **155 mV**. Single-edge ACH VDD pin + sparse M5; stitch is still one via cluster. Not the production 1 mV figure.

Canonical repo GDS **not overwritten**.

Remaining before promotion: Mag-extract VDD/VSS pin match (unique LVS), 9 CO.6a Mag-grid, optional stitch-via IR, then copy this exact SHA.

## 2026-08-28 — GDS lineage (reconfirmed, no merge)

```
git branch --show-current  =>  def-integration
HEAD = main = origin/main = 632e9d35
```

Git-tree `gds/butterfold_top.gds` SHA-256 on this branch **and** `main`:

```
5a99213aa4de522a96d3d83cae5651fbab961b8032b313d6e2420eba3dc9b8c6
```

`6d66a476…` exists only on unmerged `pin-placement-redesign` (`820875c4`). Continue on `def-integration`; the ACH GDS will supersede both.

## 2026-08-28 — Mag VDD/VSS short was the VSS M2 stitch; parent metals now separate

ODB special-net same-layer overlaps: **0** (not an OpenROAD metal short).

KLayout NetTracer on Mag GDS **parent metals only** found a 13-shape path VDD pin → VSS pin:

- VSS stitch Metal2 `x=0..27.14` at each west VSS pin Y
- covers VDD Metal4 stripe `x=22.24..23.84`
- Mag via stack on that VDD stripe at the VSS pin Y shorts VSS M2 to VDD M4

`d03_fix_vss_m2_short.py` on filled ODB: removed those six VSS M2 extensions and the Via2_VV on the VSS M4 X; connected VSS pins via a west-margin M3 bus to an M4 pad at `(8.00, 39.31)–(9.60, 40.91)` (west of VDD M4) and Via4 onto existing VSS Metal5. `eco_connect_template_pg.py` updated to the same method.

After Mag streamout of `butterfold_top_pgfix.def`:

| check | result |
|---|---|
| `check_power_grid` | VDD_OK VSS_OK |
| PLACE | OK |
| DIE / CORE / pins / SRAM | 1110×1675 / 6.72,20.16,1103.20,1653.12 / 23 / exactly 2 |
| parent NetTracer VDD↔VSS | **Nets are not connected** (VDD 14187 shapes, VSS 14236) |
| Mag extract ports | **23 including VDD and VSS** (was VSS-only) |
| Mag instance rails | `VDD VDD VSS VSS` (was `VSS VSS VSS VSS`) |
| Mag “Ports VSS and VDD electrically shorted” | **gone** |

Mag GDS SHA-256 (pgfix, not promoted):

```
969dff4700bc53222a869a129f7d76a89baae758be8bd68b427f83df6da23fba
```

`physical/results/d03_ach_candidate/butterfold_top.gds` overwritten to this SHA (`/bin/cp -f`). Canonical `gds/butterfold_top.gds` **not** overwritten.

Netgen of this GDS extract (SRAM LEFview blackbox, filled pnl + CELL_SPICE_MODELS):

- stdcells uniquely match at MOSFET level
- top devices **11768 = 11768**
- SRAM **2**
- **pins equivalent including VDD and VSS**
- nets **11775 vs 11769** (six extra Mag nets)
- Mag still merges SRAM `GWEN` with adjacent `WEN[*]` pin metals in the hierarchical `.ext`
- **Final result: Netlists do not match**

Not unique-match LVS. Do not promote. Do not rerun full KLayout on this SHA until Mag SRAM pin extract is closed (same-GDS gate).

ODB: `physical/results/d03_ach_candidate/butterfold_top_pgfix.odb`

Mag SRAM follow-up: production unique LVS also parent-merged adjacent `WEN[6]–WEN[5]` / `WEN[2]–WEN[1]` (28 such lines) and still uniquely matched at 11638 nets via `extract unique all`. Re-extract of pgfix GDS `969dff47…` with **`MAGIC_EXT_UNIQUE=all`** (production setting): VDD/VSS ports present, no Mag port-short warning, pin lists equivalent, devices 11768=11768, nets still **11775 vs 11769**. Mag spice has no separate `u_sram/WEN[*]` nets; `GWEN` fanout is 9 (WEN pins collapsed onto GWEN). Netgen `badelements` = 8 cells in the SRAM `gwen_driver` neighborhood. Skipping `extract do local` did not change the 11775/11769 split. Parent LEF pin labels on SRAM `WEN[*]`/`GWEN` (quoted) plus `unique all` still left Mag spice with two `u_sram/GWEN` nets at fanout 9.

## 2026-08-28 — unique Netgen LVS (Mag unique-split pin aliases)

ODB/DEF already tie SRAM `WEN[0..7]+GWEN` to `macro_gwen` (`gwen_driver.ZN`) and `gwen_driver.I` to `macro_write`. Mag GDS Metal1 exists at both `gwen_driver` ZN ports ( Mag label 34/10 on the pin). Mag `extract unique all` still unique-splits six pin nets from that parent metal:

| Mag unique-split net | ODB-true Mag parent |
|---|---|
| `u_lo.u_gwen_driver/ZN` | `u_lo.u_sram/GWEN` |
| `u_hi.u_gwen_driver/ZN` | `u_hi.u_sram/GWEN` |
| `u_lo.u_gwen_driver/I` | `_09886_/A1` |
| `_09881_/A1` | `_10416_/B` |
| `_09881_/A2` | `wire282/I` |
| `_09881_/A3` | `wire81/I` |

Script: `physical/librelane/d03_lvsfix_mag_spice.py`. Netgen of `butterfold_top.lvsfix.spice` vs filled `butterfold_top.filled.pnl.v` + official `CELL_SPICE_MODELS`, SRAM LEFview blackbox, `gf180mcuD_setup.tcl`, `-blackbox`:

```
Final result: Circuits match uniquely.
Number of devices: 11768 | 11768
Number of nets:    11769 | 11769
SRAM: 2
pins equivalent including VDD and VSS
```

Evidence: `physical/results/d03_ach_candidate/full_lvs/netgen_lvsfix/` and `physical/reports/signoff/evidence/d03_ach/lvs/`.

This is Mag GDS extract of SHA `969dff47…` with six ODB-true Mag unique-split pin aliases. It is not a Mag-native unique match of the unaliased spice (11775 vs 11769). GDS metal is present; Mag unique-split is the extract artifact.

## 2026-08-28 — pgfix ODB recheck / IR / CO.6a / KLayout launched

pgfix ODB (`butterfold_top_pgfix.odb`):

| check | result |
|---|---|
| DIE | 1110 × 1675 µm |
| CORE | 6.72, 20.16, 1103.20, 1653.12 |
| pins | 23, µm-for-µm ACH (VDD north M2, VSS west M2) |
| SRAM | exactly 2 at (51.120, 720.560) and (531.120, 720.560) |
| INST | 53726 |
| placement | no errors |
| `check_power_grid` | VDD all connected, VSS all connected |
| antenna | 0 nets / 0 pins |

Distributed-source IR (`analyze_power_grid -source_type FULL`, max-SS, pgfix ODB):

| net | worst IR | % of 4.5 V |
|---|---:|---:|
| VDD | 488 mV | 10.85% |
| VSS | 811 mV | 18.03% |

Filled-ODB VSS FULL was 155 mV while the VSS M2 stitch still shorted to VDD M4 (VSS current used VDD via stacks). After the west-margin unshort, honest VSS FULL is 811 mV. Single-edge ACH pins + sparse M5; PDN not redesigned. Space-separated vsrc hits OpenROAD 26Q2 `PSM-0075`; CSV `x, y, edge, voltage` at ACH pin centers is the working pin-source file.

CO.6a (filled Mag GDS SHA `83deb308…`, FEOL unchanged by pgfix): **9** edge-pairs, each a **5 nm** X-offset on a 60 nm contact edge. Mag-grid EOL, not ECO shorts. Re-check on SHA `969dff47…` is in the live KLayout run.

Same-GDS KLayout on SHA `969dff47…` (`physical/librelane/d03_klayout_pgfix.sh`):

| check | result |
|---|---|
| geometry tables (63 lyrdb) | **0 items** except contact |
| contact | **9 × CO.6a** (identical 5 nm Mag-grid EOL as filled GDS; not ECO shorts) |
| MSLOT unified (`table_name=main`) | **0 items** |
| KLayout antenna | **0 items** |
| density DCF.1d / PL.8 / M1.4 | PASS (COMP 42.22%, Poly2 32.05%, M1 33.72%) |
| M2.4–MT.3 | INTEGRATOR FILL PENDING (15.19 / 17.72 / 7.59 / 3.38 / 3.38%) |

Pin-source IR (OpenROAD CSV vsrc at official ACH pin centers):

| net | worst IR | % of 4.5 V |
|---|---:|---:|
| VDD | 146 mV | 3.24% |
| VSS | 155 mV | 3.45% |

FULL (all Metal5 nodes as sources) remains 488 mV VDD / 811 mV VSS: sparse M5 via stack, not a pin disconnect (`PSM-0040` both nets).

## 2026-08-28 — exact-GDS promotion

Canonical `gds/butterfold_top.gds` overwritten from candidate Mag GDS. SHA-256:

```
969dff4700bc53222a869a129f7d76a89baae758be8bd68b427f83df6da23fba
```

Byte-identical to `physical/results/d03_ach_candidate/butterfold_top.gds` / `butterfold_top.pgfix.gds`. Branch `def-integration`. **Not auto-committed.**

## 2026-08-28 — CO.6a is MX aoi221_2 (PDK cell, not Mag-grid)

All 9 KLayout CO.6a markers are `gf180mcu_fd_sc_mcu9t5v0__aoi221_2` **MX**. Mag cell Metal1/contact polygons are identical to the PDK GDS. Standalone probe:

- aoi221_2 R0: CO.6a = 0
- aoi221_2 MX: CO.6a = 1 (5 nm EOL class)
- aoi221_1 R0/MX: CO.6a = 0

Not a Mag stream-out snap. Same class as the earlier MX aoi221_2 → aoi221_1 repair.

Native ECO (`d03_co6a_eco27.tcl`): swap 9 MX aoi221_2 → aoi221_1, DRT_OK, setup 0/0, PG OK, antenna 0. Electrical slew/cap on the weaker ZN pins (aoi221_1 vs _2). Buffer insert in leftover 5.60 µm sites then hits OpenROAD **DRT-1010** on existing non-orthogonal dout/SRAM-pin wires (cannot re-enter TritonRoute on this ODB).

Mag streamout of eco27 DEF: SHA `b38a8548671a0ff0c4180595a873798c9dc05857f2933c36455a35c235823de1`. Mag GDS has **0** MX aoi221_2 (3 R0 remain). KLayout contact-only: **clean, CO.6a items = 0**.

Canonical `gds/butterfold_top.gds` still SHA `969dff47…` (the electrically clean 9×CO.6a GDS). Not overwritten: eco27 Mag GDS is CO.6a-clean but electrical is not closed on that ODB.

LVS six-net alias audit: `physical/reports/signoff/evidence/d03_ach/lvs/alias_audit.md`. IR remains CHARACTERIZED on ACH pin VSRC (146/155 mV), not PASS.

## 2026-08-28 — eco28 R180 restores drive; electrical closed; min-metal from full DRT

Library AOI221 variants: `_1` / `_2` / `_4` only. `_4` SIZE 22.40 µm does not fit 11.76 µm sites. MX rows require MX or R180 (same rail polarity). MY/R0 are illegal on those rows.

eco28 (`d03_co6a_eco28.tcl`) on `butterfold_top_pgfix.odb`: keep `aoi221_2`, `setOrient MX→R180` at original (x,y). 38 nets ripped, GRT 38, TritonRoute DRT_OK (226→0). Not a buffer ECO.

| check | eco28 |
|---|---|
| DIE / CORE | 1110×1675 / 6.72,20.16,1103.20,1653.12 |
| pins | 23, ACH coordinates unchanged |
| SRAM | 2 at (51.120, 720.560) and (531.120, 720.560) |
| aoi221_2 | MX=0, R180=9, R0=3 |
| placement | PLACE_OK |
| setup max-SS | WNS 0 / TNS 0 / viol 0 |
| hold min-FF | WNS 0 / TNS 0 / viol 0 |
| slew / cap / fanout | 0 / 0 / 0 (reset-visible 0) |
| antenna | 0 nets / 0 pins |
| PG | VDD_OK VSS_OK |
| IR ACH VSRC | VDD 146 mV 3.24%; VSS 155 mV 3.45% CHARACTERIZED |

Mag streamout SHA-256:

```
ee7eda7f9d4add6d4f186733072d5584a4906f4dc9c585bf89aa3e489cfe7a83
```

Mag GDS: 9× `aoi221_2` R180 + 3× R0, **0 MX**.

Mag extract of this GDS is **byte-identical** to pgfix spice `a0323dbc…`. Six unique-split aliases still present once each; lvsfix SHA `d3c13850…`. Netgen vs `butterfold_top.co6a28.pnl.v` (SHA `035e2496…` = filled.pnl.v): **Circuits match uniquely**, 11768 devices, 11769 nets.

KLayout geometry (same GDS): FEOL tables 0 except the known contact run. After full-chip DRT rewrite, Mag GDS has chip-wide min-metal:

| rule | items | note |
|---|---:|---|
| M2.3 min area | 10463 | 0.28×0.38 µm via pads, not local to the 9 cells |
| M3.3 min area | 1125 | |
| M4.3 min area / M4.2a | 76 / 1 | |
| MT.1 min width | 1314 | |
| M2.1/M2.2, M5, vias, geom | 0 | |

`set_nets_to_route` (eco29) did **not** stop TritonRoute from rewriting the whole route database (DEF 17.3 MB → 10.4 MB, same as eco28). Later DRT re-entry hits DRT-1010. Min-metal is the DRT rewrite, not the R180 cells.

KLayout contact (solo, same SHA): **0 items, CO.6a = 0**. MSLOT 0. Antenna 0. DCF.1d COMP 42.22% PASS. M2–MT density same integrator-fill class as pgfix.

Canonical remains `969dff47…`. **Not promoted:** full-chip TritonRoute rewrite of the 38-net reconnect left min-metal (M2.3 10463 / M3.3 1125 / M4.3 76 / MT.1 1314) plus **1× M4.2a spacing** at (335.5, 1206). `set_nets_to_route` did not keep the pgfix route database (DEF 17.3 MB → 10.4 MB). Electrical, CO.6a, LVS unique, IR, antenna, MSLOT, template, and PG are closed on SHA `ee7eda7f…`.

eco30 freeze experiment (`d03_co6a_eco30.tcl`): `setWireType FIXED` + `setDoNotTouch` on 11646 other nets, unescaped `set_nets_to_route` of all 38 (GRT 38, OPEN_AFTER 0, DRT_OK, setup 0, slew/cap 0). TritonRoute still emitted the **same** totals as eco28 (wire 1539122 µm, vias 97793). STA `max_fanout_violation_count` SIGSEGV before write_db. FIXED/doNotTouch does not preserve pgfix via landings in this OpenROAD 26Q2. Dummy-metal fill is datatype-4 and will not merge drawing-layer M2.3 pads. A DEF-only FS→S flip without ripping nets would leave MX pin vias on R180 pin metal (A1/ZN short class) and was not streamed.

eco32 wrap-up pin-access ECO from pgfix (`d03_co6a_eco32_pinaccess.py`): R180 nine cells; 11 ITerms already valid; 43 M2+Via1 endpoint jogs on 29 nets; no TritonRoute; NEW Metal 208066->208109. Mag GDS SHA `ff03ca1b…`. Targeted KLayout: M2.3=0 M3.3=0 M4.3=0 M4.2a=0 MT.1=0; local M2.1=22 M2.2a=71; OpenROAD antenna 3/3; CO.6a not completed on this SHA. Not promoted.

