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

## Known area hotspots (for the paper / optimization)

The folded datapath already uses **one shared complex multiplier**. Two index-generation
costs remain in `gen_reference.py` and are worth trimming before final tapeout:

1. **`(n*j) % 12`** in the DFT operand mux — a runtime modulo-12 (non-power-of-2 →
   a small divider). Replace with a 144-entry index LUT or precomputed schedule.
2. **`(START+j)*tau`** — a runtime 7×7 multiply for the IFFT twiddle index. Could be
   an incremental adder (stride accumulation) instead of a multiply.

The shared `32×16` complex multiplier and the 48–64-bit accumulators are the next
width-trim targets if area/timing needs it.
