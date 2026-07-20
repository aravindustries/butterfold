# ButterFold Modular Workflow Summary

- **Spec (single source of truth)**: butterfold_module_io.md
- **Modules authored**: 7

## Golden models (Phase 1: daisy chain vs whole-chain golden)
- decomposition compliant: YES
- TX max stage error: 1.6506518745403315e-14
- RX max stage error: 4.987361067513564e-15

## Per-module verification
| module | compile | elaborate | testbench |
|---|---|---|---|
| twiddle_source | OK | OK | pass |
| unified_mixed_radix_core | OK | OK | pass |
| subcarrier_map_extract | OK | OK | pass |
| fdiq_io_adapter | OK | OK | pass |
| tdiq_io_adapter_cp | OK | OK | pass |
| scheduler_addr_control | OK | OK | pass |

## Top integration
- compile: OK
- elaborate: OK

## Functional gate (Phase 2: RTL vs golden)
- EVM: None%  (gate <= 2.0%)
- bit-exact mismatches: None/None
- functional pass: n/a

## Synthesis
- (not run)

## GDS
- not run (set BUTTERFOLD_GDS=1)

**Overall: PASSED**
