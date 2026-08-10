# Authoritative two-SRAM physical flow

This directory implements the real synthesized ButterFold netlist. It is not
the historical area-only macro harness.

Prerequisites: installed `/foss/pdks/gf180mcuD`, Yosys/OpenSTA, and OpenROAD.
The default corner is GF180 SS 125 C, 4.50 V and the target clock is 61.44 MHz.

```sh
make -C physical floorplan ARRANGEMENT=C
make -C physical place ARRANGEMENT=C
make -C physical cts ARRANGEMENT=C
make -C physical route ARRANGEMENT=C
make -C physical timing ARRANGEMENT=C
```

Arrangements A/B/C are horizontal, vertical, and horizontally mirrored macro
experiments. Results are written under `physical/results/<arrangement>/`.
Every target regenerates the audited mapped netlist before invoking OpenROAD.

Arrangement C is the retained default: the byte macros are horizontally
adjacent with the high-byte macro mirrored so the two signal-pin edges face
the shared standard-cell channel. The flow builds a preliminary Metal1/4/5
PDN, inserts tap/endcap cells, performs timing/routability-driven placement,
CTS, setup/hold repair, global and detailed routing, and OpenRCX extraction.

The mapped netlist calls the constant supply nets `one_` and `zero_`; the
physical scripts use those names as the VDD/VSS domain aliases and verify
connectivity for both the standard cells and the two SRAM macros.

## Extracted I/O and corner study

The retained `results/C/route.odb` can be re-analyzed with matching GF180
standard-cell/SRAM corners and max/nom/min OpenRCX rules:

```sh
make -C physical physical-signoff-setup
make -C physical physical-signoff-hold
make -C physical physical-signoff-io
make -C physical physical-signoff-summary
```

`signoff_sta.tcl` never changes the routed database.  The baseline runs retain
the historical zero-delay core-pin constraints.  Contract runs are a clearly
labelled sensitivity analysis using the candidate die-pad timing contract in
`PAD_IO_MULTICORNER_TIMING_REPORT.md`.  The installed PDK contains generic
GF180 I/O cells, but the repository does not identify authoritative Padframe-A
pad cells or package/board parasitics.  Consequently these targets establish a
reproducible conditional timing envelope, not package-level signoff.
