#!/usr/bin/env python3
"""Create a flat, labelled leaf-boundary extraction view from candidate GDS.

Top routing is copied verbatim.  Each foundry leaf pin shape is flattened from
the GDS hierarchy and labelled INSTANCE|PIN.  Leaf interiors are omitted under
the documented hierarchical verified-cell policy.
"""
from pathlib import Path
import re
import klayout.db as db

ROOT = Path(__file__).resolve().parent.parent
GDS = ROOT / "physical/results/padframe/gds/butterfold_padframe_candidate.gds"
DEF = ROOT / "physical/results/padframe/route/route.def"
OUT = ROOT / "physical/results/padframe/lvs/layout_boundary_flat.gds"
TOP = "butterfold_padframe_top"
METALS = [34, 36, 42, 46, 81]
VIAS = [35, 38, 40, 41]


def components():
    text = DEF.read_text()
    section = re.search(r"(?ms)^COMPONENTS\s+\d+\s*;(.*?)^END COMPONENTS", text).group(1)
    result = {}
    for entry in re.split(r"(?m)^\s*-\s+", section)[1:]:
        words = entry.split()
        name, master = words[0], words[1]
        place = re.search(r"\+\s+(?:FIXED|PLACED)\s+\(\s*(\d+)\s+(\d+)\s*\)", entry)
        if place:
            key = (master, int(place.group(1)), int(place.group(2)))
            if key in result:
                raise SystemExit(f"non-unique placed component key: {key}")
            result[key] = name
    return result


def shape_object(shape):
    if shape.is_polygon(): return shape.polygon
    if shape.is_box(): return shape.box
    if shape.is_path(): return shape.path
    if shape.is_text(): return shape.text
    return None


def main():
    names = components()
    src = db.Layout(); src.read(str(GDS)); src_top = src.cell(TOP)
    dst = db.Layout(); dst.dbu = src.dbu; top = dst.create_cell(TOP)
    for n in METALS + VIAS:
        for datatype in ([0, 10] if n in METALS else [0]):
            si, di = src.layer(n, datatype), dst.layer(n, datatype)
            for shape in src_top.shapes(si).each():
                obj = shape_object(shape)
                if obj is not None: top.shapes(di).insert(obj)

    pin_cache = {}
    leaf_count = via_count = label_count = 0
    missed = []
    for inst in src_top.each_inst():
        master = inst.cell
        if master.name.startswith("VIA_"):
            for trans in inst.cell_inst.each_cplx_trans():
                for n in VIAS:
                    iterator = master.begin_shapes_rec(src.layer(n, 0))
                    bbox = None
                    while not iterator.at_end():
                        box = (trans * iterator.trans()) * iterator.shape().bbox()
                        bbox = box if bbox is None else bbox + box
                        iterator.next()
                    if bbox is not None:
                        # Cuts in one generated via array connect the same two
                        # continuous metal landings; one bounding conductor is
                        # connectivity-equivalent and far smaller to extract.
                        top.shapes(dst.layer(n, 0)).insert(bbox)
            via_count += inst.size()
            continue
        if not master.name.startswith("gf180mcu_"):
            continue
        key = (master.name, inst.cplx_trans.disp.x, inst.cplx_trans.disp.y)
        inst_name = inst.properties().get(1) or names.get(key)
        if inst_name is None:
            missed.append(key); continue
        if master.name not in pin_cache:
            by_pin = {}
            for metal in METALS:
                labels = [s.text for s in master.shapes(src.layer(metal, 10)).each() if s.is_text()]
                for label in labels:
                    point = label.trans.disp
                    iterator = master.begin_shapes_rec(src.layer(metal, 0))
                    shapes = []
                    while not iterator.at_end():
                        shape = iterator.shape()
                        if (shape.is_polygon() or shape.is_box() or shape.is_path()) and \
                                (iterator.trans() * shape.bbox()).contains(point):
                            shapes.append(shape_object(shape).transformed(iterator.trans()))
                        iterator.next()
                    if shapes:
                        key_pin = (metal, label.string)
                        if key_pin not in by_pin:
                            by_pin[key_pin] = [label.trans.disp, []]
                        by_pin[key_pin][1].extend(shapes)
            pin_cache[master.name] = [(m, p, value[0], value[1])
                                      for (m, p), value in by_pin.items()]
        for metal, pin, point, shapes in pin_cache[master.name]:
            for obj in shapes:
                top.shapes(dst.layer(metal, 0)).insert(obj.transformed(inst.cplx_trans))
            position = inst.cplx_trans * point
            text = db.Text(f"{inst_name}|{pin}", db.Trans(position))
            top.shapes(dst.layer(metal, 10)).insert(text)
            label_count += 1
        leaf_count += 1
    if missed:
        raise SystemExit(f"{len(missed)} GDS instances did not map to DEF; first={missed[:3]}")
    OUT.parent.mkdir(parents=True, exist_ok=True); dst.write(str(OUT))
    print(f"leaf_instances={leaf_count}")
    print(f"flattened_vias={via_count}")
    print(f"instance_pin_labels={label_count}")
    print(f"output={OUT}")

if __name__ == "__main__": main()
