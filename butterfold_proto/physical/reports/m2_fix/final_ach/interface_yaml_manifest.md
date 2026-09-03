# Final ACH interface YAML manifest

Source: `D03_ACH_interface.yaml`  
SHA256: `89fa2b488644c8902c422f40a186ef2216db7e6b5b816005b46cb3320301fb60`

The interface was parsed programmatically by
`physical/scripts/generate_final_ach_shell.py`. The complete per-terminal,
per-PORT record is in `evidence/interface_yaml_manifest.json`.

| Classification | Terminals | Physical PORT shapes | Treatment |
|---|---:|---:|---|
| ButterFold functional and power | 23 | 33 | Preserve the core connection and organizer geometry |
| Application-selected pad controls | 102 | 102 | Drive with GF180 tie cells using the documented policy |
| Disabled bidirectional receiver outputs | 10 | 10 | Preserve as shell terminals with explicit internal loads |
| **Total** | **135** | **145** | **135/135 resolved** |

The 23-terminal ButterFold logical API is unchanged. The other 112 terminals
belong to the final ACH integration shell and are not new user-facing core
ports. No interface-net mapping was guessed.

Pad configuration policy:

- Input-only pads: `PU=0`, `PD=0`; receiver type is fixed by the selected
  `in_c` or `in_s` master.
- Output `bi_t` pads: `CS=0`, `SL=0`, `IE=0`, `OE=1`, `PU=0`, `PD=0`,
  `PDRV1:PDRV0=00` (fast-slew 4 mA mode).
- Disabled receiver `Y` terminals on output pads are retained and loaded; they
  are not treated as unused routing space.

The programmable values follow the installed GF180 PDK truth tables. The YAML
remains the sole authority for signal-to-instance and signal-to-terminal
mapping.

At `ss_125C_4v50`, the installed `gf180mcu_fd_io__bi_t` Liberty view sets PAD
`max_capacitance` to 30 pF and provides the `!IE&OE&!PDRV0&!PDRV1&!SL`
timing arc. At its largest characterized load point (32.900766 pF including
pad capacitance), the worst tabulated A-to-PAD delay is 10.108150 ns. This is
below ButterFold's 26.041667 ns interface period, so the minimum 4 mA,
fast-slew setting is retained; there is no timing evidence requiring 8/12/16
mA drive.

The installed worst-case I/O Liberty
`gf180mcu_fd_io__ss_125C_4v50.lib` explicitly characterizes the selected
`!IE&OE&!PDRV0&!PDRV1&!SL` mode through a 30 pF external load
(`max_capacitance: 30.0`). At its largest characterized load/slew point the
listed A-to-PAD delays are 10.10815 ns rise and 9.328285 ns fall, both below
the 26.041667 ns interface clock period. No evidence justified increasing
drive above the minimum 4 mA selection.
