# OFDM_TX DFT12 Intermediate-RAM Corruption Fix

## Symptom

The constant-input DFT-s-OFDM test passed, while impulse, QPSK, ramp, and random tests failed with deterministic output differences.

## Root cause

The standalone DFT12 engine uses `dft12_ram_i/q` as in-place intermediate storage. During DFT-s-OFDM TX, final natural-order DFT12 outputs were also written back into this same RAM.

The Good-Thomas output addresses are not confined to the currently executing four-point group. For example, group 0 emits bins 0 and 6 during its final-even operation. Writing bin 6 overwrote address 6, which still contained an intermediate needed later by group 1. Other group-0 outputs similarly overwrite addresses needed by groups 1 and 2.

Constant input passed because only DFT bin 0 is nonzero, so the overwritten later-group intermediates were zero. Nontrivial inputs exposed the aliasing.

## Fix

A dedicated 12-entry natural-order TX DFT output buffer was added:

```systemverilog
logic signed [15:0] tx_dft12_output_i [0:11];
logic signed [15:0] tx_dft12_output_q [0:11];
```

- `dft12_ram_i/q` remains exclusively in-place intermediate storage.
- Final TX DFT12 results are captured into `tx_dft12_output_i/q` using `dft12_output_address(...)`.
- `subcarrier_mapper` now reads from `tx_dft12_output_i/q`.
- Standalone DFT12 behavior and all other modes are unchanged.

The added storage is 12 complex samples × 32 bits = 384 bits.
