# Final D03 ACH DEF-pin manifest

Authoritative geometry: `D03_ACH.def`  
SHA256: `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99`

All 135 DEF pins and all 145 PORT rectangles are represented in
`evidence/interface_yaml_manifest.json`, including name/net, direction, USE,
pad instance/master/terminal, routing layer, and exact rectangle coordinates.

| Classification | Pins | PORT shapes | Physical treatment |
|---|---:|---:|---|
| BUTTERFOLD_FUNCTIONAL | 21 | 21 | YAML-mapped intended connection |
| BUTTERFOLD_POWER | 2 | 12 | YAML-mapped VDD/VSS connection |
| PADFRAME_CONTROL | 102 | 102 | Routed to deterministic GF180 tie source |
| ADDITIONAL_PORT_OF_INTENDED_CONNECTION | 0 | 10 additional power shapes included above | Same intended supply net |
| UNRELATED_DEF_PIN | 0 | 0 | None in this final YAML-complete interface |
| UNKNOWN | 0 | 0 | Fail-closed classification complete |

The remaining ten physical terminals are disabled output-pad receiver `Y`
connections. They are integration terminals, explicitly preserved and loaded,
and therefore are not classified as unrelated or unknown geometry.

`UNKNOWN_DEF_PINS = 0` and `ALL_DEF_PINS_CLASSIFIED = YES`.
