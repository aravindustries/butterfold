# 10 — Final artifacts

Canonical team GDS **promoted** to `gds/butterfold_top.gds` (byte-for-byte copy
of the North/West Magic streamout after CO.6a repair + fill). Minimum-metal
density remains integrator-fill pending.

## Hashes

| Artifact | SHA-256 |
|---|---|
| Magic GDS (DRC/LVS/density/MSLOT) | `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12` |
| `gds/butterfold_top.gds` (promoted) | `6d66a47623c96dcbfb2e6258081934f7a26c033f953b57469b1730d0c5e7dd12` |
| Extracted SPICE | `c639454969fc4dc445e717157f063d197e2dc628c6e6105a2b6c4dafa5a07336` |
| Source filled.pnl.v | `32224ebbd39de4f8d80b47acec102115fa883bbc4bbd7633adc758e23d9a4cdb` |

Verified after promotion: SHA of `gds/butterfold_top.gds` equals the
signoff Magic GDS. No further stream-out after this copy.

Previous canonical SHA `5a99213a…` is superseded.

## Tools

LibreLane 3.0.2, OpenROAD 26Q1-librelane / 26Q2-254 for ECO DRT,
Magic 8.3.636, KLayout 0.30.8, Netgen 1.5.318,
open_pdks `7b70722e33c03fcb5dabcf4d479fb0822d9251c9`.

## Evidence index

See [11_signoff_summary.md](11_signoff_summary.md). GDS SHA file:
[evidence/final/gds.sha256](evidence/final/gds.sha256).
