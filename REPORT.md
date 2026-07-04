# ButterFold — Modular Chip PPA Report

**Design:** a 5G-NR-inspired **DFT-s-OFDM** transform chip (K=12 subcarriers,
M=128 FFT/IFFT, CP=9/10), decomposed into the **six hardware modules** defined in
`butterfold_module_io.md` and integrated into one top, `rtl/butterfold_top.v`.

**This report** presents the **area / timing / power** of that modular chip on the
**GF180MCU** open PDK, comparing the two ways of building the FFT scratch memory —
a flip-flop **register file** vs a **GF180 SRAM macro**. Every number here is
measured (yosys + OpenSTA); the commands are in [`PPA.md`](PPA.md) and reproduce
these values exactly.

> Scope: this is a **synthesis-level (pre-layout) PPA study**. Functional
> golden-EVM closure of the modular RTL is a separate track and is **not** claimed
> here — see §6.

---

## 1. Architecture

![ButterFold modular architecture](schematics/architecture.svg)
*`schematics/architecture.svg` — the six modules and how they connect.*

| Module (RTL) | Role |
|---|---|
| `scheduler_addr_control` | Control brain — sequences DFT-12 / FFT-128 / IFFT-128, generates memory + twiddle addresses, drives map / CP control. |
| `unified_mixed_radix_core` | Datapath — **128×16 complex scratch memory** + shared complex multiplier + radix-2 butterfly + scale/round/saturate. Executes scheduler micro-ops. |
| `twiddle_source` | Quantized Q1.7 twiddle ROM, with conjugation for inverse transforms. |
| `subcarrier_map_extract` | Centered subcarrier map (TX) / extract (RX) — bins 58..69 of a 128-bin grid. |
| `fdiq_io_adapter` | Frequency-domain I/Q byte pack/unpack (the 12 QAM samples). |
| `tdiq_io_adapter_cp` | Time-domain I/Q byte pack/unpack + cyclic-prefix insert/remove (9 or 10). |

`butterfold_top` wires these together with a thin glue layer (command capture,
memory address pointers, stream muxing). The chip is driven byte-by-byte on
`din`/`dout`: the first byte is the command (`0x03`=TX, `0x04`=RX).

The **only** structural difference between the two builds below is inside
`unified_mixed_radix_core` — the scratch memory. Everything else is identical.

---

## 2. PPA methodology

Fast, pre-layout, no place-and-route required (~1–2 min each):

| Metric | Tool | How |
|---|---|---|
| **Area** | yosys | `synth` → `dfflibmap`/`abc` map to `gf180mcu_fd_sc_mcu7t5v0`, then `stat -liberty`. SRAM macros add their LEF footprint. |
| **Timing** | OpenSTA | map netlist, `create_clock` 50 ns, `report_checks`/`report_worst_slack`. |
| **Power** | OpenSTA | `report_power` (internal + switching + leakage, default activity). |
| **Schematic** | yosys `show` + graphviz | module-instance and datapath views. |

PDK: `gf180mcuD` · std cells `gf180mcu_fd_sc_mcu7t5v0` · SRAM `gf180mcu_fd_ip_sram__sram128x8m8wm1` · corner `tt_025C_5v00`.

---

## 3. Results

| Metric | ① Register file (flip-flops) | ② SRAM macro (4× `sram128x8`) |
|---|---|---|
| **Total area** | **1.098 mm²** | **0.558 mm²** |
| — std-cell logic | 1.098 mm² (49,322 cells) | 0.094 mm² (4,251 cells) |
| — memory | 4096 FFs + access logic (in logic above) | 0.465 mm² (4 macros) |
| **Setup** @ 50 ns (20 MHz) | **FAIL** −1993 ns (artifact, see §4) | **MET** +26.5 ns |
| **Hold** | MET +0.84 ns | MET +0.62 ns |
| **Max data-path / Fmax** | un-timeable pre-layout | **23.3 ns → ≈ 42 MHz** |
| **Power** (default activity) | ~151 mW | ~66 mW |
| **Critical path** | min-gate driving 4096 mem cells | 16×8 complex multiplier (the real datapath) |

Each SRAM macro footprint = 431.86 µm × 268.88 µm = 116,119 µm²; 4 macros (real/imag
× hi/lo byte) = 464,474 µm² = 0.465 mm².

---

## 4. Why the SRAM version wins

The register-file core stores the 128×16 scratch memory as **4096 flip-flops with
an async 128:1 read mux and three write-port address decoders**. That *access
logic* — not the storage — is the problem:

- **Area:** the mux/decoder cones balloon the std-cell logic to **1.098 mm²**
  (75% is combinational).
- **Timing:** a minimum-size gate ends up driving all 4096 memory cells with no
  buffering, so pre-layout STA shows a single stage at **1754 ns** — the −1993 ns
  "violation" is this **unbuffered high-fanout artifact**, not a real Fmax. PnR
  buffering would help, but it can never make this structure competitive.

The SRAM core (`rtl_sram/unified_mixed_radix_core.v`) replaces the array with **4
real single-port synchronous SRAM macros** and a **5-cycle butterfly FSM**
(read src0 → read src1 → compute → write dst0 → write dst1). Result:

- The mux/decoder logic **disappears** → std-cell logic drops to **0.094 mm²**.
- Timing **closes**: the critical path is now the genuine **16×8 complex
  multiplier (~23 ns)** → **Fmax ≈ 42 MHz**.
- Power **more than halves** (151 → 66 mW), now dominated by the SRAM macros.

**Counter-intuitive note:** for a memory this small (4096 bits), the SRAM *storage*
(0.465 mm²) is actually larger than the flip-flop *storage* (0.261 mm²) — GF180 SRAM
macros carry big fixed periphery. The win is **deleting the multiport access logic**
and **getting characterized timing**, not the storage density.

---

## 5. Schematics (`schematics/`)

| File | What it shows |
|---|---|
| `architecture.svg` / `.png` | Block diagram of the 6-module chip (from `architecture.dot`). |
| `butterfold_top.svg` | yosys `show` of the integrated top — the 6 module instances wired together. |
| `core_sram.svg` | yosys `show` of the SRAM core — the 4 SRAM macros + the butterfly FSM and multiplier. |

Regenerate with `bash scripts/gen_schematics.sh` (inside the container).

---

## 6. Honest scope

- **Pre-layout** estimate (ideal wires, no clock tree). The SRAM version's critical
  path is clean logic, so its 23 ns is trustworthy; the register-file "violation"
  is a fanout artifact. Post-layout signoff needs a LibreLane PnR→GDS run.
- **PPA only.** Functional golden-EVM verification of the modular RTL is out of
  scope here. Because the authored FDIQ/TDIQ adapters don't yet drive their output
  bytes, `dout` is structurally constant; an **observability tie-off** on the scan
  pin keeps the datapath from being optimized away so the area/power are faithful.
- Power is a **default-switching-activity** estimate; the SRAM macro power assumes
  the RAMs are clocked every cycle, so a real workload draws less.

---

## 7. Reproduce

```bash
git clone https://github.com/aravindustries/butterfold.git
cd butterfold && git checkout harissh
# --- inside the IIC-OSIC-TOOLS container (yosys, sta, GF180 PDK) ---
bash scripts/ppa_regfile.sh     # register-file memory -> area, timing, power, schematic
bash scripts/ppa_sram.sh        # SRAM-macro memory    -> area, timing, power
bash scripts/gen_schematics.sh  # (re)generate the schematics
```

Full details and per-metric commands: [`PPA.md`](PPA.md).

### File inventory
| Artifact | Path |
|---|---|
| Spec (single source of truth) | `butterfold_module_io.md` |
| 6 modules + structural top | `rtl/` |
| SRAM-macro core + macro blackbox | `rtl_sram/` |
| PPA + schematic scripts | `scripts/ppa_regfile.sh`, `scripts/ppa_sram.sh`, `scripts/gen_schematics.sh` |
| Schematics | `schematics/` |
| PPA guide | `PPA.md` |

**Next step:** the SRAM version closes timing, so it is the sensible candidate to
push through LibreLane PnR→GDS for signoff-grade (post-layout) numbers.
