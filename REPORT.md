# ButterFold — Progress Report

**Design:** minimum-area 5G-NR-inspired DFT-s-OFDM transform core (K=12 subcarriers,
M=128 FFT, CP=9), built by an **agentic RTL flow** from a single specification.

## 1. What ButterFold is

A one-button **spec → silicon** flow driven from a single source of truth,
`butterfold_module_io.md`. Deep (reason+act) LLM agents author each hardware
module from its port/function contract; a fully deterministic golden-model layer
judges correctness. The split is deliberate: **agents create, deterministic code
verifies** — the correctness oracle is never an LLM.

## 2. Pipeline

```
butterfold_module_io.md (single spec)
  → planner            ordered module build plan
  → code agents        ReAct agents AUTHOR each module (write→compile→elaborate→test loop)
  → golden Phase 1     per-module Python models, daisy-chained, checked vs the
                       whole-chain golden (butterfold_sim)  — PASS ~1e-14 (TX+RX)
  → verify             per-module compile / elaborate / functional testbench + integration
  → functional gate    RTL vs golden, EVM ≤ 2% (Phase 2)
  → synthesis          Yosys GF180 area
  → LibreLane          RTL → GDS signoff (DRC / LVS)
```

## 3. Verification methodology (the core contribution)

Correctness is defined by a **golden model** and enforced at two levels:

- **Phase 1 (decomposition):** independent per-module Python models chained in the
  scheduler's order reproduce the whole-chain golden to ~1e-14 — proving the module
  breakdown is numerically faithful (TX and RX).
- **Phase 2 (RTL functional gate):** each module's Verilog testbench drives the
  exact input its golden model received and checks the RTL output **bit-exactly**;
  the whole chip is gated on **EVM ≤ 2%** at the top (24-byte in → 274-byte out).
- **Reference micro-op schedule:** the 128-pt IFFT is emitted as 448 explicit
  butterfly micro-ops (verified to reproduce the transform to 5.7e-17), so the
  FFT core RTL *transcribes a known schedule* rather than inventing FFT addressing.
- **Fixed-point format proven before RTL:** a precision sweep pins the core's
  internal format to **signed 16-bit Q5.11**, which achieves **EVM 0.28%** vs the
  float golden (formats with <5 integer bits saturate and fail) — so the datapath
  has a target proven to clear the 2% gate before any RTL is written.

## 4. Status

**Functionally verified (agent-authored, bit-exact to golden):**
| block | check | result |
|---|---|---|
| `twiddle_source` | 12-entry Q1.7 LUT + conjugation | ✅ PASS |
| `complex_mul` | Q1.7 complex multiply (64 vectors) | ✅ PASS |
| `butterfly` | Q5.11 radix-2 DIT (64 vectors) | ✅ PASS |

These three are the complete **arithmetic core** of the FFT. Each was authored by
the LLM agent from a golden hint and passed its functional gate.

**Structurally verified (compile / elaborate / integration):** all 6 spec modules
+ top; GF180 synthesis ≈ 897 µm².

**GDS signoff (this run):**
<!-- FILLED IN AFTER THE LIBRELANE RUN -->
- die area: _pending_
- DRC violations: _pending_
- LVS: _pending_

## 5. Honest status & next steps

The **full chip is not yet functionally complete**: the streaming I/O adapters,
subcarrier map/extract, the scheduler, and the `unified_mixed_radix_core`
(128-pt FFT sequenced over scratch memory) are authored and structurally valid but
not yet gated on the golden — the top-level functional EVM is therefore not yet
under 2%. The verification layer *measures this honestly* rather than hiding it.

**Next:** climb the remaining ladder rungs — wire the verified butterfly + twiddle
into the core against the verified micro-op schedule, then the streaming adapters
and map/extract, then close the top-level EVM ≤ 2% gate. The hard unknowns (can the
core hit 2%? with what precision? what schedule?) are already answered; what
remains is authoring RTL against those proven targets.
