# ButterFold Modular Workflow Summary

- **Spec (single source of truth)**: butterfold_module_io.md
- **Modules authored**: 7

## Golden models (Phase 1: daisy chain vs whole-chain golden)
- decomposition compliant: YES
- TX max stage error: 1.6232432605603574e-14
- RX max stage error: 4.987361067513564e-15

## Per-module verification
| module | compile | elaborate | testbench |
|---|---|---|---|
| twiddle_source | XX | XX | FAIL |
| unified_mixed_radix_core | XX | XX | FAIL |
| subcarrier_map_extract | XX | XX | FAIL |
| fdiq_io_adapter | XX | XX | FAIL |
| tdiq_io_adapter_cp | XX | XX | FAIL |
| scheduler_addr_control | XX | XX | FAIL |

## Top integration
- compile: XX
- elaborate: XX

## Functional gate (Phase 2: RTL vs golden)
- EVM: None%  (gate <= 2.0%)
- bit-exact mismatches: None/None
- functional pass: n/a

## Synthesis
- (not run)

## GDS
- not run (set BUTTERFOLD_GDS=1)

**Overall: NEEDS WORK**