# ButterFold — Codex Engineering Instructions

# Scope and Source of Truth

This directory, `butterfold_proto/`, contains the CURRENT and AUTHORITATIVE ButterFold implementation.

The parent repository contains older implementations that are known to be incorrect or obsolete.

For all normal development tasks:

* Work only inside `butterfold_proto/`.
* Do not inspect, borrow from, copy, merge, or restore RTL from elsewhere in the repository.
* Do not use files outside this directory to infer intended behavior.
* Do not use older README files, schedulers, testbenches, Python models, pinouts, or architecture documents from parent/sibling directories.
* If a needed fact is not available inside `butterfold_proto/` or its current documentation, ask or report that it is missing rather than searching the legacy implementation for an answer.
* Never modify files outside `butterfold_proto/` unless the user explicitly requests work on them.

The implementation and verification files in this directory supersede all older versions elsewhere in the repository.

## Project objective

ButterFold is a minimum-area, low-power, half-duplex digital baseband transform engine targeting GF180MCU.

The central architectural idea is aggressive hardware reuse:

* One folded mixed-radix arithmetic core is shared across TX and RX.
* The same transform hardware performs DFT12, FFT128, and IFFT128 operations.
* TX and RX share resources because the target system is half-duplex TDD.
* Area minimization is a primary design objective.
* Do not duplicate arithmetic or memory merely to make implementation easier unless throughput analysis proves duplication/banking is necessary.

The current scope is a one-RB, 15-kHz-SCS lower-PHY proof of concept.

## Frozen physical interface

THE TOP-LEVEL CHIP INTERFACE MUST NOT CHANGE.

Inputs:

* rst_n
* clk
* din[7:0]
* din_valid_i

Outputs:

* din_ready_o
* dout[7:0]
* dout_valid_o

Power:

* VDD

Total physical pin target: 22.

Do not add debug pins, mode pins, result-ready pins, SRAM pins, TDD pins, configuration pins, or any other chip-level signals.

All commands and data must pass through din/din_valid_i/din_ready_o.
All returned data must pass through dout/dout_valid_o.

Standalone transform diagnostics must also use the existing byte-stream output.

## Current operations

Command map:

* 0x40: FFT2
* 0x41: FFT128
* 0x42: IFFT128
* 0x43: IFFT2
* 0x44: FFT3
* 0x45: DFT12
* 0x46: OFDM_RX short normal CP, 9 samples
* 0x47: OFDM_RX long normal CP, 10 samples
* 0x48: OFDM_TX short normal CP, 9 samples
* 0x49: OFDM_TX long normal CP, 10 samples
* 0x4A: ECHO, one input byte returned unchanged
* 0x4B: MAGIC, returns ASCII `BFLD`
* 0x4C: SRAM READ, address byte then 16-bit big-endian response
* 0x4D: SRAM WRITE, address/data-high/data-low then ACK 0xAC

Do not describe 0x47/0x49 as "extended CP."

For the current 15-kHz numerology:

* short normal CP = 9 samples
* long normal CP = 10 samples

Slot/TDD scheduling is EXTERNAL to ButterFold and must not be implemented on-chip.

Production symbol-allocation contract at 61.44 MHz:

* maximum sustained grid-aligned allocation is 50%;
* RX→RX and TX→TX starts require two symbol positions;
* RX→TX starts require three symbol positions;
* TX→RX may be adjacent;
* this is an allocation-density restriction, not reduced FFT throughput.

## Datapath

External samples:

* signed 8-bit Q1.7
* interleaved I then Q

Internal datapath:

* signed 16-bit
* 7 fractional bits

TX:
12 FDIQ complex samples
→ DFT12
→ map to natural IFFT bins 1..12
→ IFFT128
→ CP insertion
→ TDIQ

RX:
TDIQ
→ CP removal
→ FFT128
→ extract natural FFT bins 1..12
→ 12 FDIQ complex samples

Standalone FFT128/IFFT128 remain diagnostic modes and expose full transform results through the byte-stream output.

## Arithmetic architecture

The mixed-radix butterfly is shared.

Radix-2:
X0 = x0 + W*x1
X1 = x0 - W*x1

Radix-3 uses the algebraic 3-point DFT decomposition with one shared complex multiplication by approximately -j*sqrt(3)/2.

DFT12 uses a 3×4 Good-Thomas/prime-factor decomposition:

* 4 radix-3 operations
* 12 radix-2 operations
* 16 total core operations

FFT128/IFFT128 use iterative radix-2 DIT:

* 7 stages
* 64 butterflies/stage
* 448 butterflies

IFFT128 performs final /128 normalization.
DFT12 is currently unnormalized unless explicitly changed as part of a separately reviewed fixed-point decision.

Do not silently change arithmetic scaling.

## Memory architecture

Current production physical SRAM architecture:

FFT/IFFT compute storage:

* logical 256×16-bit physical-half-word single-port memory
* physically 2 × gf180mcu_fd_ip_sram__sram256x8m8wm1 in parallel
* complex sample `n` mapping:
  * address `2n` = I[15:0]
  * address `2n+1` = Q[15:0]
* RX discards CP and captures the 128-sample body directly into scratch.
* TX generates CP and body output by reading IFFT results directly from scratch.
* There is no dedicated waveform SRAM.

Total intended foundry SRAM count:

* 2 × 256×8
* 2 macros

The shared scratch SRAM is intentionally single-port for minimum area.
Do not bank or duplicate it unless throughput analysis later demonstrates that the single-port architecture cannot meet requirements.

The SRAM scheduler must respect:

* synchronous read
* one read OR one write per logical memory port per cycle
* explicit operand read and result write states

Small storage stays in registers:

* 12-point DFT scratch
* 12-point TX DFT result buffer
* shallow FIFOs
* metadata
* small TX input buffers
* small RX extracted-output buffers
* butterfly pipeline/elastic state

FFT twiddles are hard-coded constant ROM/logic, not SRAM.

## GF180 SRAM

Installed PDK:

PDKPATH=/foss/pdks/gf180mcuD
PDK=gf180mcuD

SRAM root:

/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram

Views:

* verilog/ : functional macro models
* lib/     : Liberty timing
* lef/     : P&R abstract
* gds/     : physical macro layout
* cdl/     : LVS/netlist
* spice/   : circuit models

Used macros:

* gf180mcu_fd_ip_sram__sram256x8m8wm1

The official GF Verilog macro contains specify/timing constructs that Icarus may not fully support.

Do NOT modify foundry PDK files.

Functional RTL simulation should validate macro behavior.
Final timing must ultimately be evaluated from GF Liberty/STA rather than by altering RTL to satisfy Icarus's incomplete specify support.

## Golden-model policy — CRITICAL

THE PYTHON GOLDEN MODELS ARE THE SPECIFICATION.

Unless the user explicitly requests a mathematical/specification change, do not modify:

* gen_dft12_vectors.py
* gen_ofdm_rx_vectors.py
* gen_ofdm_tx_vectors.py
* gen_realtime_vectors.py
* existing NumPy/reference-model code
* existing golden vector CSV files

Never make RTL pass by changing expected outputs.

Never weaken comparisons, tolerances, assertions, byte counts, expected addresses, expected transform ordering, CP-copy checks, or pass/fail criteria.

If RTL disagrees with the golden model, assume the RTL/control/memory integration is wrong until proven otherwise.

If you believe the golden model itself is incorrect:

1. stop,
2. explain the suspected mathematical/specification error,
3. provide evidence,
4. do not edit the model without explicit user approval.

Generated vector files may only be regenerated by the existing unchanged generators.

## Regression policy

A successful fix must preserve all previously passing modes.

Relevant expected regressions include:

* GF180 SRAM wrapper regression
* full final-pin regression
* ping-pong/continuous-operation regression
* foundry SRAM functional-model regression

A fix is not accepted merely because one failing target passes.

Always inspect git diff after changes.

Report:

1. root cause,
2. files changed,
3. why each file changed,
4. tests executed,
5. whether any golden/reference files changed,
6. remaining risks.

## Debugging policy

When given a failure:

1. Reproduce it before editing.
2. Diagnose the root cause.
3. Explain the likely root cause before making a broad architectural change.
4. Prefer the smallest RTL/build-system fix.
5. Preserve the architecture above.
6. Do not redesign working blocks merely to remove simulator warnings.
7. Do not optimize throughput until cycle measurements demonstrate a need.
8. Never change the frozen top-level interface.

Warnings from Icarus do not automatically indicate functional errors.
Distinguish:

* RTL bugs,
* wrapper/protocol bugs,
* simulator limitations,
* foundry model limitations,
* actual SRAM timing limitations.

## Current development objective

The current objective is:

1. validate ButterFold against the official GF180 SRAM functional models,
2. preserve numerical correctness,
3. measure exact memory-realistic TX/RX cycle counts,
4. analyze sustainable continuous 15-kHz OFDM-symbol throughput,
5. use GF180 Liberty/STA to choose the final internal clock,
6. only then decide whether additional FFT memory banking is required.

Do not prematurely implement the on-chip slot/TDD scheduler. Scheduling remains external.
