#!/usr/bin/env python3
"""Generate OpenDB Tcl for the final YAML-defined ACH integration shell."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import yaml

OUTPUT_VALUE = {"CS": 0, "SL": 0, "IE": 0, "OE": 1, "PU": 0,
                "PD": 0, "PDRV0": 0, "PDRV1": 0}
INPUT_VALUE = {"PU": 0, "PD": 0}
FUNCTIONAL = {"Y", "A", "DVDD", "DVSS"}

def q(value: str) -> str:
    return "{" + value + "}"

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("interface_yaml", type=Path)
    ap.add_argument("output_tcl", type=Path)
    ap.add_argument("output_json", type=Path)
    args = ap.parse_args()
    data = yaml.safe_load(args.interface_yaml.read_text())
    pins = data["pins"]
    if len(pins) != 135 or data.get("participant_pin_count") != 23:
        raise SystemExit("unexpected ACH interface cardinality")

    by_user: dict[str, list[dict]] = {}
    for entry in pins:
        by_user.setdefault(entry["user_pin_name"], []).append(entry)

    functional_users = {"VDD", "VSS", "clk", "rst_n", "din_valid_i",
                        "din_ready_o", "dout_valid_o",
                        *{f"din[{i}]" for i in range(8)},
                        *{f"dout[{i}]" for i in range(8)}}
    if set(by_user) != functional_users:
        raise SystemExit("YAML user-signal set differs from ButterFold interface")

    rows = []
    lines = [
        "# Generated from D03_ACH_interface.yaml; do not hand edit.",
        "set ach_block [ord::get_db_block]",
        "set ach_db [ord::get_db]",
        "set ach_tech [$ach_db getTech]",
        "set ach_dbu [$ach_block getDefUnits]",
        "set ach_tiel [$ach_db findMaster gf180mcu_fd_sc_mcu9t5v0__tiel]",
        "set ach_tieh [$ach_db findMaster gf180mcu_fd_sc_mcu9t5v0__tieh]",
        "set ach_buf [$ach_db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_1]",
        "if {$ach_tiel eq \"NULL\" || $ach_tieh eq \"NULL\" || $ach_buf eq \"NULL\"} { error \"missing ACH shell masters\" }",
        "proc ach_add_bterm {name net_name io_type rects} {",
        "  set block [ord::get_db_block]",
        "  set bterm [$block findBTerm $name]",
        "  set net [$block findNet $net_name]",
        "  if {$net eq \"NULL\"} { set net [odb::dbNet_create $block $net_name] }",
        "  if {$bterm eq \"NULL\"} { set bterm [odb::dbBTerm_create $net $name] } else { $bterm connect $net }",
        "  $bterm setIoType $io_type",
        "  foreach old [$bterm getBPins] { odb::dbBPin_destroy $old }",
        "  set bpin [odb::dbBPin_create $bterm]",
        "  foreach r $rects {",
        "    lassign $r lname x1 y1 x2 y2",
        "    set layer [[[ord::get_db] getTech] findLayer $lname]",
        "    odb::dbBox_create $bpin $layer $x1 $y1 $x2 $y2",
        "  }",
        "  $bpin setPlacementStatus FIRM",
        "  return [list $bterm $net]",
        "}",
    ]

    # Existing ten output BTerms become integration-shell A terminals while
    # retaining their core nets. Inputs and supplies already have YAML names.
    for old, new in [("din_ready_o", "din_ready_o_OUT"),
                     ("dout_valid_o", "dout_valid_o_OUT"),
                     *[(f"dout[{i}]", f"dout_OUT[{i}]") for i in range(8)]]:
        lines += [f"set bt [$ach_block findBTerm {q(old)}]",
                  f"if {{$bt eq \"NULL\"}} {{ error \"missing BTerm {old}\" }}",
                  f"$bt rename {q(new)}"]

    control_count = load_count = 0
    for entry in pins:
        term = entry["cell_terminal"]
        name = entry["project_pin"]
        user = entry["user_pin_name"]
        rects = []
        for r in entry["rectangles"]:
            # YAML translated_user coordinates are 200 DBU/um; active ODB is
            # 2000 DBU/um.
            x1, y1, x2, y2 = (int(v) * 10 for v in r["translated_user"])
            rects.append(f"{{{r['routing_layer']} {x1} {y1} {x2} {y2}}}")
        rect_list = "{" + " ".join(rects) + "}"
        row = {k: entry[k] for k in ("user_pin_name", "project_pin",
               "cell_terminal", "padring_instance", "physical_pad_slot",
               "cell", "direction", "use")}
        row["rectangles"] = entry["rectangles"]

        # Existing functional/power terminals need geometry/name auditing but
        # no new driver/load insertion.
        if term in FUNCTIONAL and not (term == "Y" and entry["cell"].endswith("__bi_t")):
            row["treatment"] = "BUTTERFOLD_FUNCTIONAL_OR_POWER"
            rows.append(row)
            continue

        if term == "Y" and entry["cell"].endswith("__bi_t"):
            # Disabled receiver output is driven by the pad model at the full
            # hierarchy boundary; give it an explicit internal load.
            # Keep the OpenDB net name identical to the top-level BTERM name;
            # write_verilog otherwise emits a separate unaliased internal net.
            net = name
            inst = f"ach_rx_load_{entry['padring_instance']}"
            lines += [f"lassign [ach_add_bterm {q(name)} {q(net)} INPUT {rect_list}] bt net",
                      f"set inst [odb::dbInst_create $ach_block $ach_buf {q(inst)}]",
                      "$inst setLocation 13440 40320", "$inst setPlacementStatus PLACED", "[$inst findITerm I] connect $net"]
            load_count += 1
            row["treatment"] = "DISABLED_RECEIVER_EXPLICIT_LOAD"
            rows.append(row)
            continue

        values = INPUT_VALUE if entry["cell"].endswith("__in_c") or entry["cell"].endswith("__in_s") else OUTPUT_VALUE
        if term not in values:
            raise SystemExit(f"no policy for {entry['cell']} {term}")
        value = values[term]
        net = f"ach_{name.replace('[','_').replace(']','')}_tie{value}"
        inst = f"ach_tie_{control_count}_{value}"
        master = "$ach_tieh" if value else "$ach_tiel"
        pin = "Z" if value else "ZN"
        lines += [f"lassign [ach_add_bterm {q(name)} {q(net)} OUTPUT {rect_list}] bt net",
                  f"set inst [odb::dbInst_create $ach_block {master} {q(inst)}]",
                  "$inst setLocation 13440 40320", "$inst setPlacementStatus PLACED", f"[$inst findITerm {pin}] connect $net"]
        control_count += 1
        row["treatment"] = "APPLICATION_SELECTED_PAD_CONTROL"
        row["constant"] = value
        rows.append(row)

    lines += ["puts \"ACH_SHELL_BTERMS [llength [$ach_block getBTerms]]\"",
              f"puts \"ACH_SHELL_CONTROL_TIES {control_count}\"",
              f"puts \"ACH_SHELL_RX_LOADS {load_count}\""]
    if control_count != 102 or load_count != 10:
        raise SystemExit(f"unexpected controls/loads {control_count}/{load_count}")
    manifest = {
        "interface_yaml_sha256": hashlib.sha256(args.interface_yaml.read_bytes()).hexdigest(),
        "ach_terminals_total": len(pins), "butterfold_logical_terminals": 23,
        "integration_terminals": 112, "application_selected_pad_controls": control_count,
        "disabled_receiver_loads": load_count, "entries": rows,
    }
    args.output_tcl.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_tcl.write_text("\n".join(lines) + "\n")
    args.output_json.write_text(json.dumps(manifest, indent=2) + "\n")

if __name__ == "__main__":
    main()
