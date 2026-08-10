# Candidate GDS stream-out and provenance report

Date: 2026-08-10  
Classification: **CANDIDATE PHYSICAL SNAPSHOT — NOT FINAL TAPEOUT GDS**

## 1. Authoritative source database

```text
Route ODB:
physical/results/padframe/route/route.odb

Absolute ODB:
/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/padframe/route/route.odb

Route DEF:
physical/results/padframe/route/route.def

Top:
butterfold_padframe_top

ODB timestamp:
2026-08-10 11:59:39.170003249 +0200

ODB size:
21,472,927 bytes
```

OpenDB inspection reported 13,761 instances and 11,564 routed nets. The
database contains exactly two
`gf180mcu_fd_ip_sram__sram256x8m8wm1` instances, no 512x8 SRAM, and the
current padframe masters: 11 `in_c`, 10 `bi_t`, one `dvdd`, one `dvss`, and
corner/filler cells. Standard cells and CTS/timing-repair cells are present.

## 2. Provenance evidence

`physical/results/CURRENT_RUN.md` identifies `physical/results/padframe/route/`
as the current pad-aware run and points to this ODB/DEF pair. The current
`PAD_CORE_BUFFER_CTS_REPAIR_REPORT.md` documents that run's legal input-pad
transitions, valid clock root, successful detailed route, and corner timing.
The active `padframe_flow.tcl` and `padframe_route_resume.tcl` write
`detailed_route_drc.rpt`, then `route.odb`, `route.def`, and the physical
Verilog into that same directory. The database is the padframe top, not an
A/B/C core-only study, and its macro/pad inventory matches the frozen
two-SRAM 22-pin implementation.

## 3. Clean DRC report

```text
Absolute path:
/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/padframe/route/detailed_route_drc.rpt

Repo-relative path:
physical/results/padframe/route/detailed_route_drc.rpt

Timestamp:
2026-08-10 11:59:38.834704246 +0200

Size:
0 bytes

Violations:
0

ROUTING DRC STATUS:
PASS
```

The report was inspected. TritonRoute's `-output_drc` report is empty when it
has no routing violations; this zero-byte report is the exact tool output, not
a conclusion inferred from its filename.

## 4. DRC provenance

The report and ODB share the authoritative padframe route directory. In both
active route scripts, `detailed_route -output_drc ...` runs immediately before
`write_db route.odb` and `write_def route.def`. The report timestamp precedes
the ODB by 0.335 seconds and the DEF by 0.442 seconds. The selected artifacts
therefore form one route-stage output set.

```text
DRC REPORT MATCHES AUTHORITATIVE ROUTED ODB:
YES
```

## 5. Stream-out method

The installed OpenROAD build has no `write_gds` command. The retained method
is therefore:

1. `physical/streamout_odb.tcl` loads the authoritative `route.odb`, validates
   its top, SRAM/pad inventory, and routed-net count, and writes the generated
   `route_for_streamout.def`.
2. `physical/streamout_gds.py` uses KLayout 0.30.8's LEF/DEF reader and actual
   GDS macro substitution to merge routing with the installed GF180 layouts.
3. The script reopens the resulting GDS and repeats structural checks.

Reproduction command:

```bash
make -C physical candidate-gds
```

Technology and layout inputs:

```text
Technology file:
/foss/pdks/gf180mcuD/libs.tech/klayout/tech/gf180mcu.lyt

LEF/DEF layer map:
/foss/pdks/gf180mcuD/libs.tech/klayout/tech/gf180mcu.map

Technology LEF:
/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef

Standard-cell GDS:
/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/gds/gf180mcu_fd_sc_mcu9t5v0.gds

SRAM GDS:
/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/gds/gf180mcu_fd_ip_sram__sram256x8m8wm1.gds

I/O GDS:
/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/gds/gf180mcu_fd_io.gds
```

The SRAM GDS top is
`gf180mcu_fd_ip_sram__sram256x8m8wm1`, exactly matching the routed master.
The combined I/O GDS contains the instantiated `in_c`, `bi_t`, `dvdd`,
`dvss`, corner, and filler layouts. No 512x8 GDS is supplied to stream-out.

## 6. Generated GDS

```text
Absolute path:
/headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/padframe/gds/butterfold_padframe_candidate.gds

Repo-relative path:
physical/results/padframe/gds/butterfold_padframe_candidate.gds

Filename:
butterfold_padframe_candidate.gds

Timestamp:
2026-08-10 18:37:21.736449876 +0200

Size:
33,440,022 bytes

SHA-256:
f4601ed31b30a58fb2b5c8aface9db1b62759e842c79f3d53788de2ec21c5da1

Top cell:
butterfold_padframe_top
```

The GDS and generated stream-out DEF are under `physical/results/`, which is
intentionally ignored by `physical/.gitignore`. They are generated/ignored,
not tracked source. Repository ignore policy was not changed.

## 7. GDS hierarchy and content

Independent KLayout and `gdstk` reopen checks produced:

```text
2 x 256x8 SRAM: YES (2 references)
512x8 SRAM: ABSENT (0 references)
padframe: YES
input pads: YES (11 in_c references)
output pads: YES (10 bi_t references)
power pads: YES (dvdd and dvss)
standard cells: YES (13,728 placed standard-cell references)
routing: YES
```

Top-level routed-shape counts were nonzero on every routed layer:
Metal1=299, Metal2=69,097, Metal3=30,324, Metal4=1,139, Metal5=113. Actual
standard-cell, SRAM, and pad GDS cells are substituted for their LEF abstracts.

## 8. Dimensions

```text
Top bounding box: (0.0 um, 0.0 um) to (2235.0 um, 2235.0 um)
Width: 2235.0 um
Height: 2235.0 um
GDS user unit: 1 um
Database unit: 0.0005 um (0.5 nm)
```

The dimensions match the established Padframe-A die boundary. The 0.5 nm
database unit preserves the routed DEF's declared 2000 units per micron; the
1 nm library GDS views rescale exactly during merge.

## 9. Parseability

```text
KLayout reopen: PASS
gdstk independent reopen: PASS
Top-cell uniqueness: PASS
GDS REOPEN/PARSE: PASS
```

## 10. Signoff status

```text
OpenROAD routing DRC: PASS (0 violations)
Full GF180 GDS DRC: NOT RUN
LVS: NOT RUN
Output-pad electrical closure: IN PROGRESS
```

The clean report is routing-database DRC only. It is not represented as full
GF180 GDS signoff DRC. No LVS or output-pad redesign was performed.

The source ODB, source DEF, routed physical Verilog, and all routed SPEFs were
SHA-256 checked before and after stream-out and remained identical.

## 11. Final classification and verdict

```text
GDS CLASSIFICATION:
CANDIDATE PHYSICAL SNAPSHOT

AUTHORITATIVE ROUTED ODB:
VERIFIED

LATEST ROUTING DRC:
VERIFIED CLEAN

CANDIDATE GDS GENERATED:
YES

GDS PARSE:
PASS

TWO 256x8 SRAMs:
YES

512x8 SRAM:
ABSENT

PADFRAME:
PRESENT

PRODUCTION RTL MODIFIED:
NO

READY FOR FULL GDS DRC/LVS:
YES
```

“Ready” means the structurally complete candidate can be supplied to those
future checks. It does not mean output-pad electrical closure is complete or
that this is final tapeout GDS.
