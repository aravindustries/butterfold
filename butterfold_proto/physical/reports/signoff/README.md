# ButterFold physical signoff — reviewer package

ButterFold GF180MCU core, LibreLane 3.0.2 / OpenROAD. Production clock
**38.4 MHz** (26.041667 ns), `TX_BYTE_INTERVAL=10`. Die **1.211541 mm²**
(1092.66 × 1108.80 µm).

## How to review

| Path | What it is |
|---|---|
| `*.md` in this directory | Human interpretation of one check |
| [`evidence/`](evidence/) | **Native tool output** copied into git |
| `physical/results/` | Heavy local artifacts (ODB/SPEF/GDS); gitignored |
| `gds/butterfold_top.gds` at repo root | Canonical tracked **team** GDS (filled SHA `f193cb1b…`) |

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

**BUTTERFOLD TEAM-SIDE SIGNOFF COMPLETE.**

Minimum-clear density: **PASS** (DCF.1d COMP 35.72% ≤ 70%).
Minimum-metal density: **INTEGRATOR FILL PENDING** (not manufacturing-closed).

Full device-level Netgen LVS PASS. Interval-10 foundry-SRAM functional PASS.
Canonical `gds/butterfold_top.gds` is the filled team GDS `f193cb1b…`.
Do not claim post-integration manufacturing signoff.
