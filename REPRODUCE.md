# Reproducing ButterFold

There are two levels. **Level 1 (verify the chip works) is deterministic and needs
no API key** — that's what most people want. Level 2 re-runs the LLM agents.

## Prerequisites
- The **IIC-OSIC-TOOLS** container (`hpretl/iic-osic-tools:chipathon26`) — it has
  `iverilog`, `vvp`, `yosys`, `python3` + `numpy`, and `librelane`.
- The repo, on branch `harissh`:
  ```bash
  git clone https://github.com/aravindustries/butterfold.git
  cd butterfold && git checkout harissh
  ```
- Run everything from the repo root.

## Level 1 — Verify the working chip (deterministic, no API key)

The verified transceiver RTL is committed at `rtl/butterfold_top.v` (and is also
regenerated deterministically by `python gen_top.py`).

```bash
python gen_top.py                 # (optional) regenerate rtl/butterfold_top.v
python golden/vectors.py          # emit golden input/expected vectors

# --- TX: 24-byte symbol -> 274-byte waveform ---
iverilog -g2012 -o /tmp/tx.vvp tests/tb_top_golden.v rtl/butterfold_top.v && vvp /tmp/tx.vvp
python golden/evm_check.py generated/rtl/top_out.hex tests/vectors/top_gold.hex
# expect: EVM=0.0%  0/274 mismatches -> PASS

# --- RX: 274-byte waveform -> 24-byte recovered symbols ---
iverilog -g2012 -o /tmp/rx.vvp tests/tb_top_rx.v rtl/butterfold_top.v && vvp /tmp/rx.vvp
python golden/evm_check.py generated/rtl/rx_out.hex tests/vectors/rx_gold.hex
# expect: EVM=0.0%  0/24 mismatches -> PASS
```

Fixed-point golden sweeps (proves the precision closes the ≤2% gate):
```bash
python golden/top_exec.py         # TX, all seeds PASS (worst 1.28%)
python golden/rx_exec.py          # RX, all seeds PASS (worst 1.51%)
```

## Level 1b — Verify the 8 agent-authored modules (deterministic)

Each module is checked bit-exactly against its golden vectors:
```bash
python golden/vectors.py
for m in twiddle_source complex_mul butterfly fdiq_io_adapter \
         tdiq_io_adapter_cp subcarrier_map_extract; do
  iverilog -g2012 -o /tmp/$m.vvp tests/modules/tb_$m.v rtl/$m.v && vvp /tmp/$m.vvp
done
# the core and scheduler use extra vectors, same pattern:
iverilog -g2012 -o /tmp/c.vvp tests/modules/tb_unified_mixed_radix_core.v rtl/unified_mixed_radix_core.v && vvp /tmp/c.vvp
iverilog -g2012 -o /tmp/s.vvp tests/modules/tb_scheduler_addr_control.v rtl/scheduler_addr_control.v && vvp /tmp/s.vvp
# each prints PASS
```

## Level 2 — Re-run the agentic flow (needs OPENAI_API_KEY; NON-deterministic)

This re-authors RTL with the LLM. It will produce *different-but-equivalent* RTL
that passes the same functional gates — it does **not** reproduce the exact
committed `rtl/*.v` byte-for-byte (that's why those are committed).

```bash
echo "OPENAI_API_KEY=sk-..." > .env      # or export it
python agents/code_agent.py --module complex_mul   # re-author one module -> passes its gate
python agents/orchestrator.py                        # full pipeline: plan->author->golden->verify->synth
```

## Level 3 — Physical implementation (optional, slow)

```bash
# synthesis (area)
python agents/synth_agent.py
# full RTL->GDS (LibreLane / OpenROAD, GF180)
cd librelane && librelane config.yaml
```
Note: the flip-flop scratch memory makes PnR very slow (~85k cells); a GF180 SRAM
macro is the intended optimization (see REPORT.md).

## What proves what
- `rtl/*.v` — the exact verified design (Level 1/1b).
- `golden/` — the reference model + EVM scorer (the correctness oracle).
- `tests/` — the testbenches that gate the RTL.
- `agents/`, `gen_top.py` — how the RTL was produced (Level 2).
- `REPORT.md` — results, methodology, honest scope.
