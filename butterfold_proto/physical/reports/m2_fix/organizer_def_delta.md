# Organizer DEF delta (old main vs new M2 package)

## Package

| Item | Value |
|---|---|
| URL | https://github.com/user-attachments/files/31645362/D03.def.tgz |
| PACKAGE_SHA256 | `c14172c2129b8a25622aa9129578229995d421a763423f15255b70bf065f9978` |

## Authoritative participant DEF

`D03/project_defs/ACH/D03_ACH.def` (user-slot / `FP_DEF_TEMPLATE` source).
Padring DEF is **not** used as the template.

| DEF | SHA-256 | PINS | DIEAREA (dbu, 200/µm) | BLOCKAGES |
|---|---|---|---|---|
| Old (main) | `13a068191b9d827cc31cb0fc2fa36f25ecadb91d84730637ed9055323bc8e7c9` | 135 | (0 0) (222000 335000) = 1110 × 1675 µm | none |
| New | `79bd0dcad427802b4ad71ab030a0c649b9ead74354ce6e0ee58d16c73cff2f99` | 135 | identical | **1 Metal2** |

`D03_ACH_padring.def` SHA is unchanged:
`ac1aed87ee53b70e9db7b93c45d8a145e1a253075320fd231210cd0a3bbce95d`.

## Unified DEF diff

The only DEF text change is appending:

```
BLOCKAGES 1 ;
- LAYER Metal2 + RECT ( 0 0 ) ( 400 13000 ) ;
END BLOCKAGES
```

Pin names, layers, coordinates, and DIEAREA are identical.

## Other package files

| File | Change |
|---|---|
| `D03_ACH_pad_map.yaml` | unchanged |
| `D03_ACH_padring.v` / `.cfg` / `.svg` | unchanged |
| `D03_ACH_interface.yaml` | adds `metal2_blockages: [[0,0,400,13000]]`; label/bbox metadata |
| `D03_selected_variants.json` | same bbox/label metadata as yaml |

YAML `blockages: []` remains empty. The new keep-out is `metal2_blockages` / DEF `BLOCKAGES`.

## Conclusion

Organizer claim verified: Metal2 corner obstruction added. For the ACH
participant DEF that is **one** SW-corner rectangle. Pin interface unchanged
(23 ButterFold-facing terminals).
