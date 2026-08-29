# Mag unique-split alias audit

GDS SHA this audit refers to (pre-CO.6a ECO Mag GDS):

```
969dff4700bc53222a869a129f7d76a89baae758be8bd68b427f83df6da23fba
```

Unmodified Mag spice: `full_lvs/extract_pgfix/butterfold_top.spice`  
SHA-256 `a0323dbcce7419f8b2b164deebac2963beb4627edc08c4f1faf5caf9a5334f87`  
(MAGIC_EXT_USE_GDS=1, MAGTYPE=mag, MAGIC_EXT_UNIQUE=all, SRAM LEFview)

Post-alias spice: `full_lvs/extract_pgfix/butterfold_top.lvsfix.spice`  
SHA-256 `d3c138503d0136f4faa44cd2ec9c36dca68bf5b048310976b46edf6973565092`  
Script: `physical/librelane/d03_lvsfix_mag_spice.py` (six string replacements, no device edits)

Source: `butterfold_top.filled.pnl.v`  
SHA-256 `035e2496a40ee00d40c8b23eacb921beab1f41670dff7d99a47af813a40e769d`  
+ official CELL_SPICE_MODELS  
Netgen: `gf180mcuD_setup.tcl` `-blackbox`  
Result: Circuits match uniquely, 11768 devices, 11769 nets.

Unaliased Mag spice is 11775 vs 11769: exactly these six extra Mag net names.

## What Mag unique-all does

`extract unique all` unique-ifies pin labels so identically named labels in different cells do not merge into a false short. Side effect: a pin label that is physically on the same conductor as a neighbor pin can keep a private net name (`inst/PIN`) instead of inheriting the parent-metal name Mag assigned from another pin on that conductor.

The alias step maps that private pin-net name onto the Mag-extracted parent name that OpenROAD/DEF already uses for the same conductor. It does not add transistors, drop transistors, or join two Mag nets that DEF keeps separate.

## Alias 1 — lo gwen_driver ZN → lo SRAM GWEN

| | |
|---|---|
| Mag net A | `u_…u_lo.u_gwen_driver/ZN` |
| Mag net B | `u_…u_lo.u_sram/GWEN` |
| Instance/pin A | `u_lo.u_gwen_driver` `clkinv_8` ZN |
| Instance/pin B | `u_lo.u_sram` GWEN (+ WEN[0..7] Mag-merged onto GWEN) |
| Mag GDS | `clkinv_8` r0 origin (460.880, 685.440) µm. Metal1 at ZN. Mag SRAM `GWEN` pin metal is the same Mag net name on all WEN/GWEN iterms in the extracted SRAM call. |
| DEF/ODB | net `u_…u_lo.macro_gwen` connects `u_lo.u_gwen_driver ZN`, `u_lo.u_sram GWEN`, and `u_lo.u_sram WEN[0..7]` |
| Source | same: `clkinv_8.ZN` drives SRAM GWEN/WEN |
| Alias | rename Mag A to Mag B |

Mag already collapsed WEN[*] onto GWEN (fanout 9) because adjacent SRAM pin metals touch. Mag then unique-split the driver ZN pin label off that conductor. DEF has one net.

## Alias 2 — hi gwen_driver ZN → hi SRAM GWEN

Same structure as alias 1 for `u_hi`. Mag GDS `clkinv_8` m0 origin (432.320, 705.600) µm. DEF net `u_…u_hi.macro_gwen`.

## Alias 3 — lo gwen_driver I → `_09886_/A1`

| | |
|---|---|
| Mag net A | `u_…u_lo.u_gwen_driver/I` |
| Mag net B | `_09886_/A1` |
| Pins | lo `clkinv_8` I vs `_09886_` A1 (and Mag already put hi `clkinv_8` I on `_09886_/A1`) |
| DEF/ODB | net `u_…macro_write` connects both gwen_driver I pins, `_09886_ A1`, `_09882_ ZN` |
| Alias | Mag unique-split the lo instance I label; hi I merged to `_09886_/A1`. Same DEF net. |

## Aliases 4–6 — `_09881_` A1/A2/A3

Mag spice:

```
X_09881_ _09881_/A1 _09881_/A2 _09881_/A3 _09882_/A2 … nor3_4
```

| Mag pin | aliased to | DEF/source |
|---|---|---|
| `_09881_/A1` | `_10416_/B` | `_09881_.A1` = `_04626_` = `_10416_.B` |
| `_09881_/A2` | `wire282/I` | `_09881_.A2` = `_04645_` |
| `_09881_/A3` | `wire81/I` | `_09881_.A3` = `_04648_` |

ZN of this `nor3_4` is already Mag-merged as `_09882_/A2` (parent name). Only the three A-pin labels were unique-split. DEF has one net per input. Alias maps each split pin name onto the Mag parent name of a neighbor pin on that same net.

## Negative checks

- Device count unchanged 11768 = 11768 (no devices added/removed).
- SRAM count 2, blackbox.
- Pins including VDD/VSS equivalent.
- Script only `str.replace` of those six net-name tokens (one occurrence each).
- Does not connect Mag nets that DEF treats as distinct.

If Mag+Netgen is re-run after a new Mag GDS, regenerate aliases only if the same unique-split names reappear; do not copy this spice onto a different GDS.
