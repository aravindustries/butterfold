# Final ACH-envelope density

Official GF180 KLayout density deck, exact final candidate SHA
`b25fbd2fffaf138d211e33b281b8a8e248e0684ecded781003bc51f07532a5ed`,
unclipped 1110 × 1675 µm bbox:

| Rule/layer | Result |
|---|---:|
| DCF.1b / COMP | 23.7196316566% (below 25% minimum) |
| DCF.1d | PASS (no maximum-density marker) |
| Poly2 / PL.8 | 18.0377605271% |
| M1 | 21.7704532957% (below 30% minimum) |
| M2 | 13.9080016404% (below 30% minimum) |
| M3 | 16.8357768374% (below 30% minimum) |
| M4 | 4.2068891435% (below 30% minimum) |
| M5 | 2.7698428506% (below 30% minimum) |
| MT | 2.7698428506% (below 30% minimum) |

These are final ACH envelope results, not compact-core values. No density
failure is hidden or converted into a false PASS; fill across the unoccupied
organizer envelope remains a top-level/package fill responsibility.
