#!/usr/bin/env python3
"""Build a memory-bounded hierarchical LVS view from the candidate GDS.

The top-level routed metal/vias and labels are copied verbatim from the GDS.
Foundry leaf cells are retained as hierarchy boundaries with only the labelled
pin-metal shapes that touch their CDL ports.  This is the standard hierarchical
macro abstraction: it removes already-characterized leaf internals, not any
ButterFold interconnect.
"""

from pathlib import Path
import argparse
import re
import klayout.db as db

METALS = [34, 36, 42, 46, 81]
VIAS = [35, 38, 40, 41]
LEF_METALS = {"Metal1": 34, "Metal2": 36, "Metal3": 42,
              "Metal4": 46, "Metal5": 81}


def copy_shape(dst, shape, trans=None):
    obj = shape.polygon if shape.is_polygon() else shape.box if shape.is_box() else \
          shape.path if shape.is_path() else shape.text if shape.is_text() else None
    if obj is None:
        return
    if trans is not None:
        obj = obj.transformed(trans)
    dst.insert(obj)


def parse_lef_pins(paths):
    result = {}
    for path in paths:
        macro = pin = layer = None
        for raw in path.read_text(errors="replace").splitlines():
            line = raw.strip()
            m = re.match(r"MACRO\s+(\S+)", line)
            if m:
                macro = m.group(1); result.setdefault(macro, {})
                continue
            m = re.match(r"PIN\s+(\S+)", line)
            if m and macro:
                pin = m.group(1); result[macro].setdefault(pin, [])
                continue
            m = re.match(r"LAYER\s+(\S+)\s*;", line)
            if m and pin:
                layer = m.group(1)
                continue
            m = re.match(r"RECT\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s*;", line)
            if m and pin and layer in LEF_METALS:
                result[macro][pin].append((layer, *map(float, m.groups())))
            if pin and line == f"END {pin}":
                pin = layer = None
            elif macro and not pin and line == f"END {macro}":
                macro = None
    return result


def pin_abstract(lef_layout, lef_cell, pin_rects, dst_layout, dst_cell):
    """Translate authoritative LEF PIN/LABEL shapes to GF180 GDS layers."""
    for index in lef_layout.layer_indexes():
        info = lef_layout.get_info(index)
        name = str(info.name)
        base, _, purpose = name.partition(".")
        if base not in LEF_METALS or purpose not in {"PIN", "LABEL"}:
            continue
        datatype = 0 if purpose == "PIN" else 10
        target = dst_layout.layer(LEF_METALS[base], datatype)
        # The installed LEF database imports at half the integer coordinate
        # scale of the foundry GDS (same physical units, 2:1 database grid).
        scale = db.ICplxTrans(2.0, 0, False, 0, 0)
        for shape in lef_cell.shapes(index).each():
            copy_shape(dst_cell.shapes(target), shape, scale)
    # Put the formal pin name on every disconnected LEF access rectangle.
    # Magic otherwise names unlabeled alternate accesses as m1_*# and splits a
    # single logical pin into multiple hierarchical terminals.
    for pin, rects in pin_rects.items():
        for layer, x1, y1, x2, y2 in rects:
            x = round((x1 + x2) * 1000)
            y = round((y1 + y2) * 1000)
            dst_cell.shapes(dst_layout.layer(LEF_METALS[layer], 10)).insert(
                db.Text(pin, db.Trans(x, y)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gds", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--top", default="butterfold_padframe_top")
    args = ap.parse_args()
    src = db.Layout(); src.read(str(args.gds))
    src_top = src.cell(args.top)
    if src_top is None:
        raise SystemExit("missing top")
    dst = db.Layout(); dst.dbu = src.dbu
    dst_top = dst.create_cell(args.top)

    sc_lef = Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef")
    io_lefs = list(Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_io/lef").glob("*.lef"))
    sram_lef = Path("/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef")
    all_lefs = [sc_lef, *io_lefs, sram_lef]
    lef_pins = parse_lef_pins(all_lefs)
    lef = db.Layout()
    lef.read(str(sc_lef))
    for path in io_lefs:
        lef.read(str(path))
    lef.read(str(sram_lef))

    keep_layers = [(n, 0) for n in METALS + VIAS] + [(n, 10) for n in METALS]
    for number, datatype in keep_layers:
        si = src.layer(number, datatype); di = dst.layer(number, datatype)
        for shape in src_top.shapes(si).each():
            copy_shape(dst_top.shapes(di), shape)

    abstracted = {}
    via_instances = leaf_instances = 0
    for inst in src_top.each_inst():
        master = inst.cell
        if master.name.startswith("VIA_"):
            for trans in inst.cell_inst.each_cplx_trans():
                for number in VIAS:
                    si = src.layer(number, 0); di = dst.layer(number, 0)
                    iterator = master.begin_shapes_rec(si)
                    while not iterator.at_end():
                        copy_shape(dst_top.shapes(di), iterator.shape(),
                                   trans * iterator.trans())
                        iterator.next()
            via_instances += inst.size()
            continue
        if not master.name.startswith("gf180mcu_"):
            continue
        if master.name not in abstracted:
            abstract = dst.create_cell(master.name)
            lef_cell = lef.cell(master.name)
            if lef_cell is None:
                raise SystemExit(f"missing LEF leaf for {master.name}")
            pin_abstract(lef, lef_cell, lef_pins.get(master.name, {}), dst, abstract)
            abstracted[master.name] = abstract
        cia = inst.cell_inst
        new_cia = db.CellInstArray(abstracted[master.name].cell_index(),
                                   cia.cplx_trans, cia.a, cia.b, cia.na, cia.nb)
        dst_top.insert(new_cia)
        leaf_instances += inst.size()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    dst.write(str(args.output))
    print(f"leaf_cell_types={len(abstracted)}")
    print(f"leaf_instances={leaf_instances}")
    print(f"flattened_via_instances={via_instances}")
    print(f"output={args.output}")


if __name__ == "__main__":
    main()
