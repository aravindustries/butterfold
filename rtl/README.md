# rtl/ — the six ButterFold modules + structural top

RTL for the modular DFT-s-OFDM chip, authored from `../butterfold_module_io.md`.

| file | role |
|---|---|
| `scheduler_addr_control.v` | control brain — sequences DFT-12 / FFT-128 / IFFT-128; addresses, CP, mapping |
| `unified_mixed_radix_core.v` | 128×16 complex scratch memory (flip-flop **register file**) + shared complex multiplier + radix-2 butterfly |
| `twiddle_source.v` | quantized Q1.7 twiddle ROM (+ conjugate for inverse) |
| `subcarrier_map_extract.v` | TX map / RX extract — bins 58..69 of the 128-bin grid |
| `fdiq_io_adapter.v` | frequency-domain I/Q byte ↔ 16-bit complex packing |
| `tdiq_io_adapter_cp.v` | time-domain I/Q packing + CP insert/remove |
| `butterfold_top.v` | **structural** top — instantiates all six and wires them to the chip interface |

`butterfold_top.v` here uses the flip-flop **register-file** scratch memory. An
**SRAM-macro** variant of the core (4× GF180 `sram128x8`) lives in `../rtl_sram/`
and is dropped in by swapping only `unified_mixed_radix_core.v`.

For area / timing / power of both, see `../REPORT.md` and run
`../scripts/ppa_regfile.sh` / `../scripts/ppa_sram.sh` inside the container.
