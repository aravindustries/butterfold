# 10 — Final artifacts

| Artifact | Path |
|---|---|
| Canonical GDS | repo-root `gds/butterfold_top.gds` |
| SHA-256 | `31dbce1e19295c6678531c205bba780898b013a69976e6056837821c3de9a64e` |
| Magic streamout | `physical/results/pin22_signoff/magic_streamout/butterfold_top.magic.gds` |
| Candidate copy | `physical/results/pin22_signoff/candidate/butterfold_top.gds` |
| Filled ODB | `physical/results/pin22_signoff/filled.odb` |
| Powered netlist | `physical/results/pin22_signoff/butterfold_top.final.pnl.v` |
| Unique-fixed spice | `physical/results/pin22_signoff/lvs/butterfold_top.unique_fixed.spice` |

Same SHA is used for density, antenna, MSLOT, Magic extract, and Netgen LVS.
KLayout main/contact DRC uses that same candidate GDS.

Do not git-add the GDS if it exceeds the 100 MB blob policy (this stream is ~21 MB).
Do not auto-commit.
