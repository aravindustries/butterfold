# ButterFold — Area / Timing / Power (PPA)

Synthesis-level PPA for the **modular** ButterFold chip: the six modules from
`butterfold_module_io.md` wired into `rtl/butterfold_top.v`. Two memory options
for the 128×16 complex scratch memory are compared:

1. **Register file** — the memory is flip-flops (`rtl/unified_mixed_radix_core.v`).
2. **SRAM macro** — the memory is 4× GF180 `sram128x8` macros
   (`rtl_sram/unified_mixed_radix_core.v`, single-port synchronous, 5-cycle
   butterfly FSM).

This is a **pre-layout** estimate (yosys + OpenSTA, ideal wires) — fast (~1–2 min),
no LibreLane/PnR required. It is the right tool for a quick area/timing/power read;
run LibreLane later for post-layout signoff numbers.

## Prerequisites
- The **IIC-OSIC-TOOLS** container (`hpretl/iic-osic-tools:chipathon26`) — it has
  `yosys`, `sta` (OpenSTA), `python3`, and the GF180MCU PDK (`gf180mcu_fd_sc_mcu7t5v0`
  standard cells + `gf180mcu_fd_ip_sram` macros) under `/foss/pdks`.
- This repo, checked out on branch `harissh`, available **inside** the container
  (e.g. mounted at `/foss/designs/...` or cloned into the container).

## Run it
From the repo root, inside the container:

```bash
bash scripts/ppa_regfile.sh     # register-file memory  -> area, timing, power, schematic
bash scripts/ppa_sram.sh        # SRAM-macro memory     -> area, timing, power
```

If your container runs detached (host repo mounted into it), you can drive it from
the host without opening a shell:

```bash
# adjust the container name and the in-container repo path to your setup
docker exec -w /foss/designs/chipathon/butterfold iic-osic-tools_chipathon_xvnc \
    bash scripts/ppa_sram.sh
```

Each script writes all artifacts (gate netlist, `area.txt`, `sta.tcl`, schematic
SVG, logs) under `generated/ppa_regfile/` or `generated/ppa_sram/`.

## How each number is produced
| Metric | Tool / command | Notes |
|---|---|---|
| Area | `yosys` → `stat -liberty <gf180 std-cell lib>` | sum of mapped std-cell areas (µm²). For SRAM, add the 4 macro footprints (LEF `SIZE`). |
| Timing | `sta` → `create_clock` + `report_worst_slack`/`report_checks` | worst setup/hold slack at 50 ns (20 MHz); critical-path delay → Fmax. |
| Power | `sta` → `report_power` | internal + switching + leakage at default switching activity. |
| Schematic | `yosys` → `show -format svg` (hierarchy kept) | block diagram of the 6 module instances. |

## Reference results (GF180MCU, whole chip, pre-layout)

| Metric | ① Register file (flip-flops) | ② SRAM macro (4× sram128x8) |
|---|---|---|
| **Total area** | **1.098 mm²** | **0.558 mm²** (logic 0.094 + macros 0.465) |
| **Timing** @ 20 MHz | setup **fails** (−1993 ns, unbuffered high-fanout artifact) | setup **meets** (+26.5 ns), hold +0.62 ns |
| **Fmax** | un-timeable pre-layout | **≈ 42 MHz** (limited by the 16×8 complex multiplier, ~23 ns path) |
| **Power** (default activity) | ~151 mW | ~66 mW (97% in the SRAM macros) |

**Why the SRAM version wins:** the register file stores the memory as 4096 flip-flops
with async 128:1 read muxes and 3 write-port decoders — that access logic (~0.8 mm²),
not the storage, dominates area and makes timing impossible. The SRAM core replaces
it with real single-port macros + a small sequencing FSM, so std-cell logic drops to
0.094 mm², timing closes on the real multiplier path, and power more than halves.

> Scope note: these builds target **PPA only** — functional golden-EVM closure is
> out of scope here (an observability tie-off on the scan pin keeps the datapath
> from being optimized away, since the authored I/O adapters don't drive `dout`).
