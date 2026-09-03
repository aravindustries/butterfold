# Final ACH-envelope density

Official GF180 KLayout density deck, exact final candidate SHA
`12876f003ed41f9b6229ef95207e50af71b16ef45a63ffb8516eb1be5dd71d2d`,
unclipped 1110 × 1675 µm bbox:

| Rule/layer | Result |
|---|---:|
| DCF.1b / COMP | 23.7218939021% (below 25% minimum) |
| DCF.1d | PASS (no maximum-density marker) |
| Poly2 / PL.8 | 18.0377605271% |
| M1 | 21.7776902783% (below 30% minimum) |
| M2 | 13.9113826166% (below 30% minimum) |
| M3 | 16.8522996289% (below 30% minimum) |
| M4 | 4.3077573430% (below 30% minimum) |
| M5 | 2.7698428506% (below 30% minimum) |
| MT | 2.7698428506% (below 30% minimum) |

These are final ACH envelope results, not compact-core values. No density
failure is hidden or converted into a false PASS; fill across the unoccupied
organizer envelope remains a top-level/package fill responsibility.
