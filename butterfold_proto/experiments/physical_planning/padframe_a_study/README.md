# Padframe-A area study harness

**AREA STUDY ONLY — NOT FUNCTIONAL RTL**

This harness places two GF180 256x8 SRAM macros and one GF180 512x8 SRAM
macro. It does not implement ButterFold and must not be used for functional
verification.

No authoritative Padframe-A DEF or core rectangle was available locally when
this harness was created. The default 1117.5 um square is only the mathematical
quarter of a 2235 um square die. Override `STUDY_CORE_W` and `STUDY_CORE_H` when
the organizer supplies the real user region.

Run, for example:

```sh
STUDY_PLACEMENT=A STUDY_HALO=20 openroad -exit scenario_floorplan.tcl
```

Supported placements are `A`, `B`, and `C`; supported planning halos are any
non-negative value in micrometres. Generated DEF and reports are written under
`results/` and are ignored by Git.
