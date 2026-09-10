# Early native PDN_CORE_RING audit (pre-route)

```
PDN_CORE_RING_SUPPORTED: YES
CURRENT_PDN_CORE_RING: enabled
NATIVE_RING_COMMAND: add_pdn_ring -grid stdcell_grid
PDN_GRID_NAME: stdcell_grid
HORIZONTAL_RING_LAYER: Metal5
VERTICAL_RING_LAYER: Metal4
RING_WIDTH: 2.0 um
RING_SPACING: 1.7 um
RING_OFFSET: 0.6 um from core
CONNECT_TO_PADS_SETTING: false
GRID_TO_RING_CONNECT_METHOD: PDN_EXTEND_TO=core_ring + add_pdn_connect Metal4/Metal5
```

ODB: `physical/librelane/runs/native_pdn_ring/17-openroad-generatepdn/butterfold_top.odb`

CORE `6.72 20.16 1085.84 1088.64`

VDD ring (2.0 um):
- west Metal4 x=4.12:6.12 y=17.56:1091.24
- east Metal4 x=1086.44:1088.44 y=17.56:1091.24
- south Metal5 x=4.12:1088.44 y=17.56:19.56
- north Metal5 x=4.12:1088.44 y=1089.24:1091.24

VSS ring (2.0 um, concentric outside VDD):
- west Metal4 x=0.42:2.42
- east Metal4 x=1090.14:1092.14
- south Metal5 y=13.86:15.86
- north Metal5 y=1092.94:1094.94

```
VDD_CORE_RING_PRESENT = YES
VSS_CORE_RING_PRESENT = YES
VDD_CORE_RING_CLOSED = YES
VSS_CORE_RING_CLOSED = YES
RING_SURROUNDS_ACTUAL_CORE = YES
RAW_HAND_DRAWN_CRITICAL_VIA_CUTS = 0
min via cuts on VDD/VSS special nets = 3
```

PDN-0110 Metal3-Metal4 via skip at one VSS SRAM location is the historical
macro-grid warning, not a hand-drawn cut.
