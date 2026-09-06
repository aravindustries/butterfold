# Final-ring extracted STA

ODB `physical/results/m2_fix/power_ring.odb` (unchanged).
OpenRCX max/min written to `spef/power_ring.max.spef` and `spef/power_ring.min.spef`.
Historical `spef/final_ach.max.spef` / `.min.spef` were **not** overwritten.

```
FINAL_STA_ODB = power_ring.odb
FINAL_STA_MAX_SPEF = physical/results/m2_fix/spef/power_ring.max.spef
FINAL_STA_MIN_SPEF = physical/results/m2_fix/spef/power_ring.min.spef

SETUP max_ss_125C_4v50 38.4 MHz:
  SETUP_WNS = 0.039952 ns
  SETUP_TNS = 0.000000 ns
  SETUP_VIOLATIONS = 0

HOLD min_ff_n40C_5v50:
  HOLD_WNS = 0.181811 ns
  HOLD_TNS = 0.000000 ns
  HOLD_VIOLATIONS = 0
```

No placement/routing change. Logs:
[setup_power_ring.log](evidence/sta/setup_power_ring.log),
[hold_power_ring.log](evidence/sta/hold_power_ring.log).
