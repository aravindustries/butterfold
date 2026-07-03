# ButterFold — agentic modular RTL flow

A minimum-area 5G-NR-inspired DFT-s-OFDM transform core, built by deep
(reason+act) agents that **author each hardware module from a single spec** and
carry it through to GDS.

## Single source of truth

Everything is generated from **`butterfold_module_io.md`** — the port/function
contract for the 6 modules + the top level. There is no second spec, no flat
generator, and no hand-locked kernel: every module is written from its contract
and checked on its own.

The 6 modules (+ top):

| module | role |
|---|---|
| `twiddle_source` | quantized twiddle factors (with conjugation for inverse) |
| `unified_mixed_radix_core` | shared radix-2/3 butterfly + complex multiplier over scratch memory |
| `subcarrier_map_extract` | TX map / RX extract between 12 subcarriers and the 128-bin grid |
| `fdiq_io_adapter` | frequency-domain I/Q byte ↔ 16-bit complex packing |
| `tdiq_io_adapter_cp` | time-domain I/Q packing + CP insert/remove (9/10 samples) |
| `scheduler_addr_control` | sequences DFT-12 / FFT-128 / IFFT-128, addresses, CP, mapping |
| `butterfold_top` | wires all six together to the chip interface |

## Pipeline (one button)

```
butterfold_module_io.md
      │  module_spec.py        parse the spec into structured contracts
      ▼
   planner.py                  ordered module build plan
      ▼
   code_agent.py               ReAct agent AUTHORS each module (compile→elaborate→tb loop)
      ▼
   verify_agent.py             per-module compile/elaborate/testbench + top integration
      ▼   (repair: re-author any failing module)
   synth_agent.py              Yosys full synthesis → GF180 area
      ▼
   librelane_agent.py          RTL→GDS signoff  (only if BUTTERFOLD_GDS=1)
      ▼
   generated/summary.md
```

## Run (inside the IIC-OSIC-TOOLS container)

```bash
python agents/orchestrator.py                 # spec → verified, synthesized RTL
BUTTERFOLD_GDS=1 python agents/orchestrator.py # …all the way to GDS (long)
```

Individual stages also run standalone, e.g.:

```bash
python agents/module_spec.py                  # show the parsed contract + a skeleton
python agents/planner.py                       # write generated/plan.json
python agents/code_agent.py --module twiddle_source
python agents/verify_agent.py
```

## Agents (no API key required)

`OPENAI_API_KEY` (in `.env`) drives the ReAct authoring loop. **Without a key**,
each module falls back to a compile-clean port skeleton, so the whole pipeline
still runs end-to-end and produces elaborable RTL — the LLM only makes the bodies
real. See `REPO_LAYOUT.md` for the canonical-vs-mirror repo rule.
