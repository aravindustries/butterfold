# Authoritative two-SRAM physical flow

Branch `m2-fix` contains the **FINAL ACH INTEGRATION** against the final
`D03_ACH.def` geometry and final `D03_ACH_interface.yaml` connectivity. The
reviewer/submission GDS is repo-root `gds/butterfold_top.gds`; its SHA and full
same-GDS signoff are recorded in
[`reports/m2_fix/final_ach/`](reports/m2_fix/final_ach/).

There is no later organizer integration step. The final ACH shell preserves
all 135 organizer terminals while keeping the ButterFold logical core API at
23 terminals and exactly two SRAM macros.

The final reviewer power-strengthening ECO uses GF180 technology-generated
multi-cut via arrays: three independent VDD core entries and a constrained VSS
entry strengthened to 6-cut/9-cut transitions. No critical via cuts are
hand-drawn, and no main supply entry depends on one cut.

The current routed-run pointer and artifact provenance are recorded in
[`results/CURRENT_RUN.md`](results/CURRENT_RUN.md). A GDS stream-out stage has
been added for a clearly labeled candidate snapshot; do not treat it as final
signoff or substitute an older result family.

```sh
make -C physical candidate-gds
```

This target reads the authoritative padframe `route.odb`, validates the top,
SRAM and pad masters, exports a stream-out DEF, and uses KLayout's LEF/DEF
reader plus the installed GF180 standard-cell, SRAM, and I/O GDS views. It does
not rerun or alter synthesis, placement, CTS, routing, or extracted timing.

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
