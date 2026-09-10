# ACH-integrated setup failure analysis

Checkpoint GDS SHA: `80ef23f6a45332bc2434a4640072c92b3d6f93d803ee4f5aa02f24d63e0687ad`  
ODB: `physical/results/native_power_ring_ach/filled.odb`  
SPEF: `physical/results/native_power_ring_ach/spef/final.max.spef` (max_ss_125C_4v50 OpenRCX)  
Clock: `core_clk` 38.4 MHz, period 26.041667 ns.

## Headline

| Metric | Value |
|---|---|
| WNS | **−1.283599 ns** |
| TNS | **−94.298790 ns** |
| Failing endpoints | **194** |
| Path group of all 300 reported paths | `core_clk` |
| Unique launch flop of all 194 failing endpoints | **`_20041_`** (`gf180mcu_fd_sc_mcu9t5v0__dffrnq_4`, net `u_transform_scheduler_core.fft128_active`) |
| Failing endpoints that terminate at an ACH/output BTerm | **0 / 194** |
| Failing endpoints that are internal FF→FF | **194 / 194** |

The 300-path summary slack sum of negative paths is **−94.299 ns**, matching full TNS. Every reported negative endpoint is in this one cone.

## Constraint audit (apples-to-apples with native +5.35 ns)

| Item | Native STA | ACH STA | Match |
|---|---|---|---|
| Clock | `create_clock core_clk -period 26.041667 [get_ports clk]` | same SDC | YES |
| Uncertainty | `set_clock_uncertainty 0.0` | same; OpenSTA does not expose an uncertainty property | YES |
| Library | `gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50` + SRAM ss | same | YES |
| SPEF | OpenRCX max, filled ODB | OpenRCX max, filled ACH ODB | same methodology |
| Input delay | 0 on `din_valid_i din[*]` | same SDC | YES |
| Output delay | SDC 0 on `din_ready_o dout_valid_o dout[*]` plus script 0 on `_OUT` names | SDC names miss renamed ports (STA-0366); script applies 0 on `din_ready_o_OUT dout_valid_o_OUT dout_OUT[*]` | equivalent 0 ns |
| `rst_n` | `set_case_analysis 1` | same | YES |
| False / multicycle | none | none | YES |
| Duplicate clock | no | one `core_clk` after SDC | YES |
| Shell control ports as sync endpoints | n/a | 102 tie-driven outputs have **no** output delay; they are **not** the failing endpoints | no fake shell endpoints |

Conclusion: the −1.28 ns is a **real extracted-delay regression** on an internal cone, not a constraint bug and not ACH-terminal loading.

## Category breakdown of TNS

| Category | Endpoints | TNS contribution | Notes |
|---|---|---|---|
| A. Internal cell delay (deep cone, already `_4` / `clkinv_20`) | 194 (all) | −94.3 ns | ~32 combinational stages; several gates 1.4–2.0 ns |
| B. Long/slew-degraded internal nets after ACH-required signal re-route | 194 (same cone) | same TNS (shared) | Native closed this cone at +5.35 ns with different wires |
| C. ACH/output load routing | 0 | 0 | No worst-100 path ends at `_OUT` / pad |
| D. High-fanout control | 194 (shared launch) | same TNS | Launch is `fft128_active`; pin load is only 5–9, but it gates the whole butterfly cone |
| E. Placement displacement | possible contributor | not separable | Sizeup/legalize happened before last re-route |
| F. Clock / constraint | 0 | 0 | Launch clk ~2.54 ns, capture ~2.76 ns; clock helps slightly |

**Dominant cause: B + A on a single shared launch (`_20041_` / `fft128_active`).**

The ACH shell did not add the failing endpoints. The ACH-required **full signal re-route** lengthened RC/slew through an already-deep mixed-radix cone. Sizeup recovered native −4.13 → −1.28 ns; remaining slack is still this same trunk.

## Worst-path snapshot (WNS)

- Start: `_20041_` `dffrnq_4` Q, clk-to-Q **2.30 ns** (loaded).
- Then ~30 combinational stages, already mostly drive-4.
- Slowest data stages (cell delay includes load/slew):
  - `_09461_` `nand2_4` **1.84 ns**, 8 loads
  - `_09511_` `aoi21_4` **1.96 ns**, 6 loads
  - `_15855_` `oai31_4` **1.75 ns**, 6 loads
  - `_15987_` `nor3_4` **2.02 ns**, 5 loads
  - `_16112_` `aoi21_4` **1.91 ns**, 8 loads
  - `clone22` `nand2_4` **1.42 ns**, 9 loads
- Arrival 29.72 ns vs required 28.44 ns (period 26.04 + capture clock − 0.32 ns library setup).
- Mean depth of worst 100: **32 stages**. Mean summed line delay **29.16 ns**.

Those `_4` gates cannot be sized further. Recovering ~1.3 ns requires **buffering the shared slew-degraded nets**, not another global rip-up.

## Intended ECO (no full re-route)

1. Cell buffering / `repair_design` slew-cap repair on this cone.
2. `repair_timing -setup -sequence buffer` with modest setup margin.
3. Tiny legalize of new buffers only.
4. Incremental DRT of affected nets only.
5. Re-extract; require setup WNS≥0 and hold WNS≥0.

Do not move ACH terminals, PDN, or organizer pins.

## Targeted ECO attempts (this session)

| Iteration | Method | Setup (SPEF/est.) | Physical route | Hold |
|---|---|---|---|---|
| 0 | checkpoint | WNS −1.284 ns, TNS −94.3, 194 ends | existing ACH routes | +0.400 ns |
| 1 | `repair_timing -sequence buffer` after `clearGuides` (25 `load_slew*`/`wire*` clkbufs) | **WNS +0.437 ns, TNS 0** | DRT-0626 (0 guides) | not re-extracted |
| 2 | rebuild all GRT guides, keep wires | n/a | 4656 DRT vios, DRT-1231 pin `_14353_/A2` | — |
| 3 | `global_route -start_incremental` then buffer | RSZ-0074 GRT tree; **0 buffers** | no-op | — |
| 4 | `insert_buffer` with GRT live | — | **SIGSEGV** `GRouteDbCbk` / `insertBufferBeforeLoads` | — |
| 5 | `repair_timing` with original guides | — | **SIGSEGV** `swapMaster`/`addDirtyNet` | — |
| 6 | bbox guides on all nets | — | DRT-0206 including `din_ready_o_OUT` | — |
| 7 | bbox guides on 50 buffer nets only | — | 5.3 h then DRT-0206 net `_04676_` | — |
| 8 | checkpoint GRT guides + 50 new-net boxes | — | DRT immediately breaks `din_ready_o_OUT` / `dout_OUT[1]` — **killed** | — |

OpenROAD 26Q2-254 can insert the buffers that close this cone **only with guides cleared**, and then cannot incrementally detail-route those buffers without ripping ACH/core connectivity or crashing in the GRT callback.

A full signal re-route is forbidden here and previously threw the same cone from +5.35 ns to −4.13 ns.
