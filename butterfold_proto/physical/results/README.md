# Physical result families

`CURRENT_RUN.md` is the authoritative pointer. Read it before using any
database or report in this directory.

- `padframe/` contains the current pad-aware implementation and extracted
  SS/TT/FF signoff collateral. Its routed database is authoritative.
- `A/`, `B/`, and `C/` are preserved core-only macro-placement studies.
- `signoff/` is the preserved core-only I/O-contract and corner study.

`padframe/gds/butterfold_padframe_candidate.gds` is the generated candidate
stream-out from the authoritative routed ODB. It is ignored generated output,
not source and not final tapeout GDS. Generated results are retained for
provenance; they are not source files.
