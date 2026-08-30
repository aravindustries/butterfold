# ButterFold physical signoff — historical pre-ACH shrink baseline

**Current 22-pin compact production package:**
[`../pin22_signoff/`](../pin22_signoff/README.md)
(die 1092.66 × 1108.80 µm, SHA `31dbce1e…`, 22 terminals).

**This directory is the pre-ACH shrunk production baseline, not the current
22-pin chip.** Historical ACH validation:
[`../d03_ach_resized/`](../d03_ach_resized/README.md).

On this branch the project-canonical file `gds/butterfold_top.gds` **is**
that ACH GDS (SHA `93f2aba1…`). The previous main/pre-ACH baseline SHA
`f193cb1b7f4ec60f41e8993f662416ed2c2a4e63ae107d213a85d8f4749f3906`
(1092.66 × 1108.80 µm) is historical only.

---

ButterFold GF180MCU core, LibreLane 3.0.2 / OpenROAD. Production clock
**38.4 MHz** (26.041667 ns), `TX_BYTE_INTERVAL=10`. Historical shrink die
**1.211541 mm²** (1092.66 × 1108.80 µm).

## How to review

| Path | What it is |
|---|---|
| `*.md` in this directory | Human interpretation of one check |
| [`evidence/`](evidence/) | **Native tool output** copied into git |
| `physical/results/` | Heavy local artifacts (ODB/SPEF/GDS); gitignored |
| repo-root `gds/butterfold_top.gds` | **Current branch ACH GDS** (SHA `93f2aba1…`). This `signoff/` directory is the previous `f193cb1b…` baseline. |

Navigate: [11_signoff_summary.md](11_signoff_summary.md) → per-check `.md` → `evidence/`.

A clone of this repository is enough to inspect every claimed PASS. Do not
require `/tmp`, ignored `physical/results/`, or the original workstation.

| Report | Check |
|---|---|
| [00_manifest.md](00_manifest.md) | Tools, PDK, hashes |
| [01_setup_max_ss.md](01_setup_max_ss.md) | max-SS setup |
| [02_hold_min_ff.md](02_hold_min_ff.md) | min-FF hold |
| [03_electrical.md](03_electrical.md) | slew / cap / fanout |
| [04_reset.md](04_reset.md) | reset electrical |
| [05_antenna.md](05_antenna.md) | antenna |
| [06_drc.md](06_drc.md) | foundry DRC / density / mslot |
| [07_lvs.md](07_lvs.md) | Netgen + KLayout LVS |
| [08_erc.md](08_erc.md) | ERC / IR / disconnected pins |
| [09_power.md](09_power.md) | vectorless power |
| [10_final_artifacts.md](10_final_artifacts.md) | artifact manifest |
| [11_signoff_summary.md](11_signoff_summary.md) | dashboard |

**HISTORICAL: BUTTERFOLD TEAM-SIDE SIGNOFF COMPLETE (pre-ACH shrink GDS).**

Minimum-clear density on that 1092.66 × 1108.80 µm GDS: **PASS** (DCF.1d COMP 35.72% ≤ 70%).
Minimum-metal density: **INTEGRATOR FILL PENDING**.

Full device-level Netgen LVS PASS on that GDS (11612 devices / 11623 nets).
Do not present `f193cb1b…` as the current ACH validation GDS.
