# ButterFold physical signoff — reviewer package

ButterFold GF180MCU core, LibreLane 3.0.2 / OpenROAD. Production clock
**38.4 MHz** (26.041667 ns), `TX_BYTE_INTERVAL=10`. Die **1.223277 mm²**.

## How to review

| Path | What it is |
|---|---|
| `*.md` in this directory | Human interpretation of one check |
| [`evidence/`](evidence/) | **Native tool output** copied into git |
| `physical/results/` | Heavy local artifacts (ODB/SPEF/GDS); gitignored |
| `gds/butterfold_top.gds` at repo root | Canonical tracked **team** GDS (SHA `6d66a476…`) |

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

**BUTTERFOLD NORTH/WEST PIN-PLACEMENT SIGNOFF COMPLETE.**

Physical terminals **23**: NORTH 12, WEST 11, EAST 0, SOUTH 0.
RTL/functionality unchanged. Existing `VDD`/`VSS` ports unchanged.

Minimum-clear density: **PASS** (DCF.1d COMP 34.39% ≤ 70%).
Minimum-metal density: **INTEGRATOR FILL PENDING** (not manufacturing-closed).
CO.6a: **0**. Full device-level Netgen LVS: **Circuits match uniquely**.
Canonical `gds/butterfold_top.gds` SHA `6d66a476…`.
Do not claim post-integration manufacturing signoff.
