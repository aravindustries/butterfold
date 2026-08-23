# 38.4 MHz max-SS setup closure

Production point: **38.4 MHz**, period **26.041667 ns**, `TX_BYTE_INTERVAL=10`.
Target corner: **max_ss_125C_4v50** (GF180 9T + SRAM, SS 125 C, 4.50 V).

Status: **SETUP TIMING CLOSED AT 38.4 MHz**.

This report records the extracted-aware post-route ECO that is **not** produced
by the tracked LibreLane configuration. Apply
`physical/scripts/postroute_setup_close.tcl` to the tracked production post-DRT
ODB instead of depending on `/tmp`.

## Final closed result

| Item | Value |
|---|---|
| setup WNS | **+0.177954 ns** |
| setup TNS | **0** |
| setup violations | **0** |
| hold WNS | **+0.559095 ns** (max-SS diagnostic; not min-FF signoff) |
| hold violations | 0 |
| die area | **1.223277 mm²** (≤ 1.25 mm²) |
| instances | 16,487 |
| SRAM macros | 2 × `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| antenna diodes | 7 |
| pace_count bits | 4 (`TX_BYTE_INTERVAL=10` preserved) |

Worst closed setup path: `_20055_/Q` (`dft12_active`) → `_18305_/D`.

## Artifact hashes

Final routed ODB SHA-256:

```
073bcd1b1029fdb8d7a3914cd65b43709a53ad2f7c76e83bfbce20ba9bfa1e64
```

Final max SPEF SHA-256:

```
1591567cc4fafe3467cf7eca1958f3e1262915be5aea146d33d26016c17cd9c8
```

SPEF units: `*T_UNIT 1 NS`, `*C_UNIT 1 PF`, `*R_UNIT 1 OHM`.

Workspace copies (gitignored by `physical/.gitignore` → `results/`):

- `physical/results/38p4_setup_closed/iter2_routed.odb`
- `physical/results/38p4_setup_closed/iter2_routed.def`
- `physical/results/38p4_setup_closed/spef/butterfold_top.max.spef`
- `physical/results/38p4_setup_closed/SHA256SUMS`

These files were copied out of `/tmp/butterfold_38p4_setup_close2/` so closure
no longer lives only in `/tmp`. They are **not** proposed for Git: the
repository already tracks the LibreLane production run, and `physical/results/`
is ignored. Reproducibility is the ECO script plus the tracked production ODB.

## Tracked starting checkpoint

Clean interval-10 production (LibreLane 3.0.2, `gf180mcu_fd_sc_mcu9t5v0`):

```
physical/librelane/runs/butterfold_top_38p4_interval10_production_9t/
  46-odb-reportdisconnectedpins/butterfold_top.odb
```

That ODB is post-DRT, has the seven antenna diodes, and **already includes**
LibreLane post-GRT `repair_design` / resizer timing
(`RUN_POST_GRT_DESIGN_REPAIR`, `RUN_POST_GRT_RESIZER_TIMING` in
`physical/librelane/config.json`). It is **before** filler insertion (step 50).

Original extracted max-SS on that production implementation:

| Metric | Value |
|---|---|
| setup WNS | -9.511038 ns |
| setup TNS | -3307.565842 ns |
| setup violations | 763 |
| hold WNS | +1.364382 ns |

Root cause: global-route RC was optimistic versus OpenRCX. Cell delay, not
raw wire delay, accounted for ~99% of the WNS collapse (slow-corner Liberty
through underestimated slew/load). Not an RTL/architecture failure and not a
SPEF/Liberty unit error.

## What LibreLane already generates

Do **not** encode these in the ECO script; they are already in the production ODB:

- synthesis with `TX_BYTE_INTERVAL=10`
- floorplan / PDN / placement / CTS
- post-GRT electrical + timing repair (estimated RC)
- detailed routing
- 7 antenna diode instances from `repair_antennas`
- `GPL_CELL_PADDING=2`, `DPL_CELL_PADDING=2`

## Post-route ECO that exists only outside the tracked flow

All of the following are in `physical/scripts/postroute_setup_close.tcl`
(machine-readable twin: `physical/scripts/postroute_setup_close.eco.json`).

Compared to the production post-DRT ODB:

| Class | Count | Notes |
|---|---:|---|
| master resizes | **175** | `dbInst::swapMaster` to the **final** drive |
| inserted instances | **19** | 8 clones + 10 load/wire buffers + 1 split buffer |
| new nets | **19** | `net`, `net225`–`net234`, `net235`–`net240`, `net242`, `net243` |
| pin swaps | **16** | commutative input swaps from `repair_timing` |
| sink retargets | **178** | existing loads moved onto the new nets (plus one existing-net retarget) |
| removed instances | **0** | |
| CTS resizes | **0** | |
| diode changes | **0** | 7 production `ANTENNA_*` instances preserved |

Inserted instances:

| Name | Master | Role |
|---|---|---|
| `clone235` | `nand4_2` | clone |
| `clone236` | `aoi21_2` | clone |
| `clone237` | `aoi21_2` | clone |
| `clone238` | `oai31_2` | clone |
| `clone239` | `oai21_2` | clone |
| `clone240` | `nand4_2` | clone |
| `clone242` | `and4_2` | clone |
| `clone243` | `nand2_2` | clone |
| `load_slew225` | `clkbuf_4` | load/slew buffer |
| `load_slew228` | `clkbuf_16` | load/slew buffer |
| `load_slew229` | `clkbuf_2` | load/slew buffer |
| `load_slew230` | `clkbuf_4` | load/slew buffer |
| `load_slew231` | `clkbuf_12` | load/slew buffer |
| `load_slew232` | `clkbuf_8` | load/slew buffer |
| `load_slew233` | `buf_4` | load/slew buffer |
| `load_slew234` | `clkbuf_8` | load/slew buffer |
| `split` | `buf_2` | splits `fft128_active` |
| `wire226` | `clkbuf_2` | wire buffer |
| `wire227` | `clkbuf_2` | wire buffer |

The 175 resizes are the union of:

1. **164** masters changed by one extracted-aware `repair_design` + `repair_timing -setup` on annotated max SPEF (plus the 19 inserts, 16 pin swaps).
2. **15** later targeted `swapMaster` operations (11 new vs production, 4 further upsizes of cells the broad repair had already grown):

| Cell | Production → closed | ECO |
|---|---|---|
| `_09454_` | `and4_1` → `and4_4` | targeted 1 |
| `_15949_` | `nand4_1` → `nand4_4` | targeted 1 |
| `_15977_` | `nand4_1` → `nand4_4` | targeted 1 |
| `_15988_` | `oai211_1` → `oai211_4` | targeted 2 |
| `_16108_` | `nor2_2` → `nor2_4` | targeted 2 |
| `_09425_` | `nor2_1` → `nor2_4` | targeted 3 |
| `_09450_` | `oai31_1` → `oai31_4` | targeted 3 |
| `_09541_` | `aoi21_2` → `aoi21_4` | targeted 3 |
| `_09417_` | `clkinv_1` → `clkinv_4` | targeted 4 |
| `_15986_` | `oai221_2` → `oai221_4` | targeted 4 |
| `_09416_` | `aoi211_1` → `aoi211_4` | targeted 4 (via `_2`) |
| `_09401_` | `nor2_1` → `nor2_4` | targeted 4 (via `_2`) |
| `_09394_` | `nand2_1` → `nand2_4` | targeted 5 |
| `_09395_` | `inv_1` → `inv_4` | targeted 5 (via `_2`) |
| `_09390_` | `nor2_1` → `nor2_4` | targeted 5 (via `_2`) |

The Tcl applies **one** swap to the final master; it does not replay intermediate sizes.

Extracted WNS history:

```
-9.511 ns  production OpenRCX
-2.131 ns  broad extracted-aware repair, rerouted
-1.744 ns  targeted 1
-1.159 ns  targeted 2
-0.726 ns  targeted 3
-0.192 ns  targeted 4
+0.178 ns  targeted 5  (closed)
```

## How to reproduce

From `butterfold_proto/`:

```sh
openroad -no_init -exit physical/scripts/postroute_setup_close.tcl
# optional, expensive:
ECO_ROUTE=1 openroad -no_init -exit physical/scripts/postroute_setup_close.tcl
```

Or `make -C physical postroute-setup-eco`.

Then extract max parasitics (`rules.openrcx.gf180mcuD.max`) and run
`max_ss_125C_4v50` STA at 26.041667 ns. Bit-identical routing to the closed
ODB is not guaranteed after a fresh DRT; the logical ECO is deterministic.

## Next (not done here)

1. Min parasitic extraction + hold STA at `min_ff_n40C_5v50`
2. Reset-network electrical treatment (`rst_n` is case-analyzed 1)
3. Final antenna check
4. Signoff DRC / LVS / ERC / power / GDS
