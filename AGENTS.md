# Repository Status

IMPORTANT: This repository contains multiple generations of the ButterFold design.

## Current authoritative implementation

The ONLY current implementation is:

`butterfold_proto/`

All active RTL development, verification, GF180 SRAM integration, timing analysis, and physical-design work must use files under `butterfold_proto/`.

## Legacy implementation

Files and directories outside `butterfold_proto/` may contain older, incomplete, or incorrect versions of the ButterFold architecture.

They are retained only for historical/reference purposes.

DO NOT:

* copy RTL from outside `butterfold_proto/`
* infer current interfaces from old RTL
* use old schedulers as design references
* use old testbenches as verification specifications
* compare failures against old implementations
* "restore" features because they appear elsewhere in the repository
* modify legacy implementation files during current ButterFold work

Unless the user explicitly asks to investigate historical code, treat all implementation files outside `butterfold_proto/` as obsolete.

When there is any disagreement between legacy code and `butterfold_proto/`, the `butterfold_proto/` implementation and its documentation are authoritative.

