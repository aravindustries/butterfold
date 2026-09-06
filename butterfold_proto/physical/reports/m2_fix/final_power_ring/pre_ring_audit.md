# Pre-power-ring audit of the Codex checkpoint

This audit is taken **before** any power-ring geometry is added.

## Git / GDS

| Item | Value |
|---|---|
| Current branch | `power_ring` (created from `m2-fix` / `main`) |
| HEAD | `ad7b9a898efd6955c9983f196a465ddcf1387d8d` |
| Power-fix commit in ancestry | `68eccf1ddf7728d665e84cf0d6a15d4928a2167d` Strengthen final ACH power connections |
| Parent of power-fix | `d75b466e8084d2f8cf0fc5f7393e78d8f4f019e8` Complete final D03 ACH padframe integration |
| Canonical GDS | `gds/butterfold_top.gds` |
| Candidate GDS | `physical/results/m2_fix/candidate_power_fixed/butterfold_top.gds` |
| PRE_RING_GDS_SHA | `12876f003ed41f9b6229ef95207e50af71b16ef45a63ffb8516eb1be5dd71d2d` |
| Candidate/canonical match | **YES** (byte-identical) |

`power_ring` and `m2-fix` currently share HEAD `ad7b9a89`. That commit is **after** `68eccf1d` and only adds the final ACH powered netlist / LVS Verilog path plus Zone.Identifier cleanup. The physical GDS SHA is unchanged from the accepted power-fixed Codex chip.

## Final ACH interface (must remain PASS)

From `physical/reports/m2_fix/final_ach/final_signoff_summary.md` on this GDS:

| Gate | Result |
|---|---|
| INTERFACE_YAML_RESOLVED | **135/135** |
| CORE_TO_ACH_PADRING_CONNECTIVITY | **PASS** |
| REQUIRED_IO_CONTROLS | 102 |
| CONNECTED_IO_CONTROLS | **102/102** |
| PAD_PIN_SPACING_VIOLATIONS | **0** (145/145) |
| KNOWN_LONG_STRIP_PAD_SPACING | PASS (din_ready_o 0.350 µm vs 0.280 µm) |
| ORGANIZER_BLOCKAGES_IMPORTED | 1/1 |
| M2_CORNER_KEEP_OUT | PASS |
| NON_FILL_DRC_TOTAL | **0** (16/16 tables) |
| MSLOT_TOTAL | **0** |
| NETGEN_LVS | **PASS uniquely** (11746 devices / 11762 nets / 2 SRAM) |

## Power-via reviewer fix (must not regress)

| Item | Value |
|---|---|
| REVIEWER_SINGLE_VIA_POWER_CONCERN | RESOLVED |
| VDD independent core entries | 3 |
| VDD M2/M3 cuts per source | 3 |
| VDD critical M3/M4 cuts | 6 |
| VSS independent core entries | **1** (second branch rejected: LVS shorted 7 signals into VSS) |
| VSS critical M3/M4 cuts | 6 |
| VSS critical M4/M5 cuts | 9 |
| RAW_HAND_DRAWN_CRITICAL_VIA_CUTS | 0 |
| Via masters | generated `via2_3_*`, `via3_4_*`, `via4_5_*` |

## Current PDN (why a ring is still required)

ODB `physical/results/m2_fix/power_fixed.odb`:

| | |
|---|---|
| DIE | 0 0 1110 1675 |
| CORE | 6.72 20.16 1085.84 1088.64 |
| SRAM | 2 × sram256x8m8wm1 at (51.120, 720.560) R0 and (531.120, 720.560) R0 |
| ACH VDD | 6 north Metal2 ports, y=1674–1675, x≈631–704 |
| ACH VSS | 6 west Metal2 ports, x=0–1, y≈71–144 |
| Internal VDD/VSS | Metal1 rails; Metal4 vertical 1.6 µm straps; Metal5 horizontal 1.6 µm straps |
| Closed VDD ring | **NO** (vertical M4 straps are not closed by top/bottom bars) |
| Closed VSS ring | **NO** |

The chip has a routed internal grid and strengthened ACH-to-core entries, but **no closed top-level power ring** connecting the ACH power/ground pad interface around the core.

## Pre-ring IR (reference)

| | |
|---|---|
| PRE_RING_IR_VDD | 0.125 V |
| PRE_RING_IR_VSS | 0.0889 V |

## Proceed?

**YES.** Checkpoint SHA matches the accepted Codex power-fixed GDS. Interface, DRC, MSLOT, LVS, pad spacing, and the single-via power fix are the closed pre-ring state. The ring ECO will start from `power_fixed.odb`.
