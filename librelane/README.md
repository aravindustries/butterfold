# ButterFold RTL → GDS (LibreLane, GF180)

This runs the full physical-design flow on the generated, golden-verified RTL to
produce a GDS and real area/timing/power numbers on the GF180MCU PDK.

> Run this **after** `python agents/orchestrator.py` reports `RESULT: ✓ PASSED`,
> so `generated/rtl/butterfold_top.v` exists and matches the golden model.

---

`config.yaml` here mirrors the **proven** GF180 counter example
(`/foss/designs/01_rtl2gds_counter/config.yaml`, which routes cleanly to GDS):
same `meta`/flow, absolute `DIE_AREA`, GF180 PDN straps, `RT_MAX_LAYER: Metal4`,
`PDN_MULTILAYER: false`. Only the design-specific fields differ (name, RTL path,
a larger 700×700 die for our ~900 flops, and `DIODE_ON_PORTS: din`).

## Prerequisites (inside the IIC-OSIC-TOOLS Docker container)

| Need | Check |
|---|---|
| LibreLane installed | `librelane --version` |
| Generated RTL present | `ls ../generated/rtl/butterfold_top.v` |

---

## Run

```bash
cd /foss/designs/chipathon/butterfold/librelane
librelane config.yaml
```

LibreLane creates a `runs/<timestamp>/` directory. The flow: lint → synthesis →
floorplan → placement → CTS → routing → signoff (STA, DRC, LVS) → GDS.

### If a step still fails

- **Placement congestion / `DIE_AREA` too small** → raise `DIE_AREA` (e.g. 900×900).
- **Setup violations** → raise `CLOCK_PERIOD` (e.g. 80–100).
- When in doubt, diff against the working counter config in
  `/foss/designs/01_rtl2gds_counter/config.yaml` and copy any GF180 knob you're missing.

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
