# ButterFold Pad-Aware I/O and Multi-Corner Timing Study

## 1. Baseline physical timing

The retained detailed-route database is `physical/results/C/route.odb`.  It
contains the 16-bit, two-SRAM production core and has zero routing DRC
violations.  Re-analysis with the original core-pin SDC at GF180
SS/4.50 V/125 C and RCmax reproduced:

| Check | Slack / result |
|---|---:|
| Setup WNS / TNS | +0.20 ns / 0 ns |
| DFT12 setup | +0.51 ns |
| Scalar-multiplier setup | +0.90 ns |
| Internal/SRAM hold | +0.69 ns |
| Overall hold WNS / TNS | -0.65 ns / -3.25 ns |
| Failing minimum-delay paths | 8, all launched by `din[7]` |

The prior shorthand "8 din bits" was not exact: there are eight failing
paths/endpoints, but all eight start at the most-significant input bit.
There are no internal register or SRAM hold failures in this baseline.

## 2. Current I/O constraint audit

`physical/constraints.sdc` currently defines:

| Item | Core-only routed-flow value |
|---|---|
| Clock | `core_clk`, 16.2760416667 ns (61.44 MHz) |
| Clock source/network latency | no SDC value; propagated CTS clock after route |
| Clock uncertainty | 0 ns |
| `din[7:0]`, `din_valid_i` delay | one 0 ns input-delay command; effectively min=max=0 |
| `rst_n` | case-analyzed high; no recovery/removal timing mode |
| Output delays | `din_ready_o`, `dout[7:0]`, `dout_valid_o`: min=max=0 |
| Input transition | unspecified |
| Output load | unspecified |

These values are useful for core timing isolation, but are placeholders rather
than a chip-pin contract.  In the contract sensitivity runs this study used
0.50 ns input transition, 0.04 pF core output load (candidate pad input),
0.10 ns setup uncertainty, and 0.05 ns hold uncertainty.  These uncertainty
values are planning allowances, not measured oscillator/package jitter.

## 3. Pad-cell identification

The installed PDK contains the generic `gf180mcu_fd_io` library, but neither
the repository nor the Padframe-A planning collateral identifies the actual
pad-cell assignment or package parasitics.  Accordingly, the following are
candidate study cells, not an authoritative Padframe-A implementation:

| Function | Candidate | LEF / Liberty observations |
|---|---|---|
| Data/valid input | `gf180mcu_fd_io__in_c` | 75 x 350 um; PAD-to-Y combinational arc; PAD capacitance about 3.08 pF |
| Clock input | `gf180mcu_fd_io__in_c` | same candidate to make common pad delay explicit |
| Reset input | `gf180mcu_fd_io__in_c` | same candidate; no authoritative reset-pad choice found |
| Data/control output | `gf180mcu_fd_io__bi_24t` | 75 x 350 um; A-to-PAD output arc; 24 mA family; PAD capacitance about 3.46 pF |
| Power | `gf180mcu_fd_io__dvdd`, `gf180mcu_fd_io__dvss` | available, but no complete Padframe-A ring assignment exists locally |

An `in_s` input cell and other bidirectional cells also exist.  Selecting them
without the padframe specification would be guessing.  No registered pad is
used in this study.

The collateral used by the sensitivity analysis is:

- generic I/O LEF files under
  `/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/lef/`;
- I/O Liberty at `ss_125C_4v50`, `tt_025C_5v00`, and `ff_n40C_5v50`;
- matching `gf180mcu_fd_sc_mcu9t5v0` and SRAM Liberty files;
- OpenRCX `max`, `nom`, and `min` rule files.

## 4. Candidate pad timing

The isolated pad-arc model uses 0.50 ns input slew, 0.10 pF input-pad
core-side load, and 10 pF external output load.  No package parasitics are
included.

| Corner | Input PAD-to-Y min | Input PAD-to-Y max | Output A-to-PAD min | Output A-to-PAD max |
|---|---:|---:|---:|---:|
| SS 4.50 V 125 C | 1.66 ns | 1.88 ns | 3.78 ns | 3.87 ns |
| TT 5.00 V 25 C | 1.00 ns | 1.10 ns | 2.19 ns | 2.32 ns |
| FF 5.50 V -40 C | 0.72 ns | 0.72 ns | 1.48 ns | 1.62 ns |

The clock candidate uses the same PAD-to-Y arc.  Therefore data-pad delay
cannot simply be added to the core hold margin: clock-pad delay is common and
mostly cancels it.  The conservative data-minus-clock differential is -0.22
ns at SS, -0.10 ns at TT, and 0 ns at FF.

## 5. `din` hold-path breakdown

At SS/RCmax with zero external minimum delay, all failures launch from
`din[7]`.  Required time includes propagated capture-clock arrival and the
endpoint's library hold check.

| Endpoint | Min data arrival | Library hold | Required time | Slack |
|---|---:|---:|---:|---:|
| `_20813_` | 1.64 ns | +0.24 ns | 2.29 ns | -0.65 ns |
| `_19690_` | 1.38 ns | -0.10 ns | 1.99 ns | -0.61 ns |
| `_19806_` | 1.38 ns | -0.10 ns | 1.96 ns | -0.59 ns |
| `_20901_` | 1.38 ns | -0.10 ns | 1.91 ns | -0.53 ns |
| `_19534_` | 1.88 ns | +0.12 ns | 2.20 ns | -0.32 ns |
| `_20959_` | 1.87 ns | +0.13 ns | 2.13 ns | -0.26 ns |
| `_19545_` | 1.92 ns | +0.12 ns | 2.13 ns | -0.21 ns |
| `_20977_` | 2.04 ns | +0.12 ns | 2.13 ns | -0.09 ns |

For the worst path, the minimum data path is 1.64 ns (roughly 0.82 ns
buffer, 0.58 ns NAND, and 0.24 ns OAI), the capture clock arrives at about
2.05 ns, and the +0.24 ns library check makes the requirement 2.29 ns.
At FF/RCmin the worst data path is about 0.50 ns, the capture clock is about
0.77 ns, and the library hold value is -0.02 ns, producing -0.26 ns slack.

Baseline corner results reinforce that this is an I/O constraint problem:

| Corner / RC | Input hold WNS | Internal hold WNS | Failing input paths |
|---|---:|---:|---:|
| SS125 / RCmax | -0.65 ns | +0.69 ns | 8 |
| TT25 / RCnom | -0.37 ns | +0.31 ns | 8 |
| FF-40 / RCmin | -0.26 ns | +0.15 ns | 9 |

## 6. Hold root-cause verdict

**EXTERNAL CONTRACT.**  The violation is not a false internal SRAM/register
hold failure.  It is a real die-pin relationship created when the source is
allowed to change simultaneously with the external clock.  Candidate matched
clock/data pads do not remove it; their differential delay slightly worsens
the SS condition.  The repository lacks the authoritative pads and external
source/board specification, so it is not yet legitimate to claim unconditional
padframe signoff.

An internal repair is unnecessary if the external contract below is accepted.
If the source cannot meet it, the smallest physical alternative is one
localized delay chain on the `din[7]` pad-to-core net before its fanout.  The
SS calculation requires at least 0.87 ns extra minimum delay, or 0.97 ns with
the study's 0.10 ns margin.  The available core input setup slack is 2.14 ns,
so this looks feasible, but it must be sized at FF minimum delay and checked at
SS maximum delay after authoritative pads are chosen.  No delay cell was added
in this task and the routed database was not changed.

## 7. Proposed die-level I/O timing contract

The following is a testable **candidate**, not package-level timing.  It uses
the measured generic-pad arcs and explicit 0.10 ns planning margin.

| Requirement at external pad pins | Value |
|---|---:|
| Clock frequency / period | 61.44 MHz / 16.276 ns |
| `din[7:0]`, `din_valid_i` setup window | arrive no later than 1.82 ns after the rising clock edge |
| `din[7:0]`, `din_valid_i` hold | remain stable until at least 0.97 ns after the rising clock edge |
| Output maximum clock-to-pad (10 pF study load) | 14.94 ns |
| Output minimum clock-to-pad (10 pF study load) | 2.10 ns |
| Reset assertion | asynchronous, active low |
| Reset deassertion | synchronous to `clk`; until pad-aware recovery/removal is characterized, release at least one full clock before normal traffic |

Derivation of the input hold requirement is 0.65 ns core deficit + 0.22 ns
worst data/clock pad differential + 0.10 ns margin = 0.97 ns.  The setup limit
is 2.14 ns core setup slack - 0.22 ns differential - 0.10 ns margin = 1.82 ns.
Equivalent core-boundary sensitivity constraints are 0.75 ns minimum and
2.04 ns maximum input delay.  These values were applied explicitly; they were
not chosen by sweeping until timing passed.

The output envelope combines routed core clock-to-output and candidate pad
arcs while subtracting the common clock-pad delay.  At SS the maximum is
12.73 + 3.87 - 1.66 = 14.94 ns.  At FF the minimum is
1.34 + 1.48 - 0.72 = 2.10 ns.  Board/package load and interconnect are not
included.

The RTL uses asynchronous active-low reset assertion.  The standard-cell
libraries contain `recovery_falling` and `removal_falling` arcs, but the
current routed mode case-analyzes `rst_n` high and no authoritative reset pad
or deassertion waveform is available.  Consequently numerical pad-level
recovery/removal signoff remains open; synchronous deassertion is the required
integration rule.

## 8. Hold repair

No physical hold cells were added because the candidate contract closes all
reported input paths and internal timing was already clean.  Area delta is
zero, routing remains unchanged, and DRC remains zero.  If board integration
rejects the 0.97 ns source hold, the next repair should target only `din[7]`;
it must not pipeline the interface or alter RTL/protocol behavior.

## 9. Multi-corner configuration

| Analysis | Standard cells / SRAM / candidate pads | Temperature | RC |
|---|---|---:|---|
| Setup extreme | SS 4.50 V | 125 C | OpenRCX max |
| Typical | TT 5.00 V | 25 C | OpenRCX nominal |
| Hold extreme | FF 5.50 V | -40 C | OpenRCX min |

All cell and SRAM libraries use matching names.  Pads were characterized in a
separate arc model because they are not instantiated in the core route.  This
is a multi-corner extracted-STA matrix, not simultaneous MCMM optimization.

## 10. Setup matrix

Results below include the candidate contract, 0.10 ns setup uncertainty, and
extracted propagated clocks.

| Corner / RC | WNS | TNS | Violations | Worst family | DFT12 | Multiplier | Worst SRAM setup | Input setup |
|---|---:|---:|---:|---|---:|---:|---:|---:|
| SS125 / max | +0.03 | 0 | 0 | external input setup | +0.41 | +0.80 | +0.59 control | +0.03 |
| TT25 / nom | +6.55 | 0 | 0 | external input setup | +7.58 | +7.90 | +6.68 control | +6.55 |
| FF-40 / min | +9.37 | 0 | 0 | external input setup/control | +10.74 | +10.97 | +9.37 control | +9.37 |

The small +0.03 ns SS margin is conditional and not generous enough to absorb
unknown package/board effects or a materially larger jitter allocation.

## 11. Hold matrix

Results include 0.05 ns hold uncertainty.

| Corner / RC | Hold WNS | TNS | Violations | Input hold | Internal hold | SRAM-input hold | SRAM-read hold |
|---|---:|---:|---:|---:|---:|---:|---:|
| SS125 / max | +0.09 | 0 | 0 | +0.09 | +0.64 | +0.64 | +8.80 |
| TT25 / nom | +0.26 | 0 | 0 | +0.32 | +0.26 | +0.26 | +4.84 |
| FF-40 / min | +0.10 | 0 | 0 | +0.43 | +0.10 | +0.10 | +3.06 |

## 12. SRAM timing matrix

| Corner / RC | Address setup | Data setup | Control setup | Read capture setup | Worst SRAM hold |
|---|---:|---:|---:|---:|---:|
| SS125 / max | +1.06 | +1.39 | +0.59 | +4.44 | +0.64 |
| TT25 / nom | +6.98 | +7.12 | +6.68 | +9.74 | +0.26 |
| FF-40 / min | +9.59 | +9.65 | +9.37 | +12.10 | +0.10 |

Both physical 256x8 macros remain present; no 512x8 macro exists.  The corner
matrix does not expose a macro-specific failure.

## 13. I/O timing matrix

| Corner / RC | Input setup | Input hold | Core output max slack vs 16.276 ns | Core output minimum |
|---|---:|---:|---:|---:|
| SS125 / max | +0.03 | +0.09 | +3.29 | 4.28 ns |
| TT25 / nom | +6.55 | +0.32 | +9.09 | 2.39 ns |
| FF-40 / min | +9.37 | +0.43 | +11.66 | 1.54 ns |

The core output columns use the sensitivity load and uncertainty.  The
pad-pin output contract is the separately combined 2.10-to-14.94 ns envelope
in Section 7.

## 14. Clock timing

The clock is propagated through the routed CTS tree from the core `clk` port.
Approximate leaf insertion ranges are 2.11--2.20 ns at SS, 1.22--1.27 ns at
TT, and 0.82--0.86 ns at FF.  Raw leaf skew is about 0.09, 0.05, and 0.04 ns,
respectively.  Contract STA adds 0.10 ns setup and 0.05 ns hold uncertainty;
the propagated skew is not also entered as source uncertainty, avoiding double
counting.  External clock-pad delay is included only when translating between
core and pad-pin timing, not in the core CTS tree.

## 15. Final extracted timing

Under the candidate die-pin contract, the worst extracted results are:

- setup WNS/TNS: +0.03 ns / 0 ns at SS125/RCmax, input endpoint;
- hold WNS/TNS: +0.09 ns / 0 ns at SS125/RCmax, input endpoint;
- worst internal hold: +0.10 ns at FF/RCmin;
- worst SRAM setup: +0.59 ns at SS125/RCmax;
- worst SRAM hold: +0.10 ns at FF/RCmin.

Without the contract, overall hold remains -0.65 ns and the design does not
support zero-hold-time external data.

## 16. Physical implementation integrity

| Item | Result |
|---|---|
| Detailed routing | PASS |
| Routing DRC | 0 violations |
| SRAM count | exactly 2 x `gf180mcu_fd_ip_sram__sram256x8m8wm1` |
| 512x8 SRAM | absent |
| Production RTL changed by this study | NO |
| Physical database changed by this study | NO |

## 17. Signoff verdict

| Category | Verdict |
|---|---|
| Internal setup | PASS |
| Internal hold | PASS |
| SRAM setup | PASS |
| SRAM hold | PASS |
| Input setup | CONTRACT REQUIRED |
| Input hold | CONTRACT REQUIRED |
| Output timing | CONTRACT REQUIRED |
| 61.44-MHz multi-corner timing | CONDITIONAL |

**61.44 MHz CONDITIONAL ON EXTERNAL INPUT-HOLD CONTRACT.**  The routed core is
clean across the analyzed cell/SRAM/RC corners.  Unconditional padframe/package
signoff is not credible until actual Padframe-A pad cells, package parasitics,
clock jitter, board/source timing, and reset recovery/removal are frozen.

## 18. Ready for clock gating?

**NO.**  The ungated core timing is well understood, but authoritative padframe
integration is missing and the conditional SS input-setup margin is only
+0.03 ns.  Clock gating would force re-CTS and invalidate this baseline before
the external boundary is frozen.

## 19. Recommended next task

Resolve the Padframe-A pad-library assignment and package/board timing contract,
then instantiate/analyze the real padframe wrapper and close reset
recovery/removal.  Clock gating should begin only after that task establishes
an unconditional pad-level baseline.

