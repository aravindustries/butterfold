# ButterFold RTL → GDS (LibreLane, GF180)

This runs the full physical-design flow on the generated, golden-verified RTL to
produce a GDS and real area/timing/power numbers on the GF180MCU PDK.

> Run this **after** `python agents/orchestrator.py` reports `RESULT: ✓ PASSED`,
> so `generated/rtl/butterfold_top.v` exists and matches the golden model.

---

## Prerequisites (inside the IIC-OSIC-TOOLS Docker container)

| Need | Check |
|---|---|
| LibreLane installed | `librelane --version` |
| GF180 PDK | `echo $PDK_ROOT` then `ls $PDK_ROOT/gf180mcuD` |
| Generated RTL present | `ls ../generated/rtl/butterfold_top.v` |

If `librelane` isn't on PATH, use the chipathon example's invocation from
`sscs-chipathon-2026/examples/librelane_rtl2gds_gf180` — the command and PDK name
there are authoritative for your container; copy them over `config.json` if they differ.

---

## Run

```bash
cd /foss/designs/chipathon/butterfold/librelane
librelane config.json
```

LibreLane creates a `runs/<timestamp>/` directory. The flow: lint → synthesis →
floorplan → placement → CTS → routing → signoff (STA, DRC, LVS) → GDS.

### If detailed routing fails on GF180 (recommended starting point)

`config.json` here is intentionally minimal. GF180 detailed routing is finicky and
needs PDK-specific PDN/routing settings. If you hit a routing error such as
`DRT-0073 No access point for clkbuf...`, **start from the chipathon example config**,
which already carries working GF180 settings, and just point it at our RTL:

```bash
cp -r ../../sscs-chipathon-2026/examples/librelane_rtl2gds_gf180 ./run_gf180
cd run_gf180
# edit its config.json:
#   "DESIGN_NAME":   "butterfold_top"
#   "VERILOG_FILES": "dir::/foss/designs/chipathon/butterfold/generated/rtl/butterfold_top.v"
#   "CLOCK_PORT":    "clk"
#   "CLOCK_PERIOD":  50
librelane config.json
```

That inherits the example's proven `FP_*`, PDN, and routing knobs for GF180 so you
only change the design-specific fields.

---

## Where the numbers land

| Metric | File under `runs/<timestamp>/` |
|---|---|
| Final GDS | `final/gds/butterfold_top.gds` |
| Area / die size | `final/metrics.json` → `design__core__area`, `design__die__area` |
| Cell count | `final/metrics.json` → `design__instance__count` |
| Timing (slack / Fmax) | `*-sta*/` reports → worst slack (Fmax ≈ 1 / (period − slack)) |
| Power | signoff STA power report in `final/metrics.json` → `power__total` |
| DRC / LVS | `*-drc*/` and `*-lvs*/` reports (must be clean for tapeout) |

Quick summary:
```bash
cat runs/*/final/metrics.json | python -m json.tool | grep -Ei "area|count|power|slack"
```

---

## Tuning (config.json)

| Key | Effect |
|---|---|
| `CLOCK_PERIOD` | ns. Start at 50 (relaxed, area-first). Lower to push Fmax once timing has margin. |
| `FP_CORE_UTIL` | core utilization %. Raise for denser/smaller die; lower if routing/placement fails. |
| `PL_TARGET_DENSITY_PCT` | placement density. Lower if congested. |

---

## Area optimizations already applied (and what remains)

The kernel in `gen_reference.py` has been trimmed for minimum area:

- **One shared complex multiplier**, now **24×12** (was 32×16) after dropping twiddle
  precision to A=B=9 — EVM is output-quantization limited, so this stayed at 1.59%.
- **Accumulators 40-bit** (was 64), **spread bins 24-bit** (was 32) — sized to worst
  case. This cut the flip-flop count / clock fanout from ~1147 toward ~900.
- **`(n*j) % 12` replaced by a 144-entry `idx12` LUT** — removes a modulo-12 divider
  from the critical path.

Remaining trim targets if area/timing still needs it:

1. **`(START+j)*tau`** — a runtime 7×7 multiply for the IFFT twiddle index. Could be
   stride accumulation (an adder) instead of a multiply.
2. **`spread` storage** (12 complex × 24-bit ≈ 576 FFs) dominates the register count;
   it could drop to ~21-bit with a small EVM margin check, or be stored at lower
   precision than it is computed.
