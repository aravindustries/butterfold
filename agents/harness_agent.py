"""
Harness Agent — generates per-module simulation testbench skeletons from the
authoritative 6-module I/O contract (butterfold_module_io.md), so every module
(FDIQ/TDIQ adapters, unified mixed-radix core, twiddle source, scheduler,
subcarrier map/extract, top) is independently checkable as it is built.

Design mirrors the kernel philosophy: a DETERMINISTIC core (parse the spec, emit
Verilog-2005 testbench skeletons) that works with NO API key. Each skeleton has
the DUT instantiation, clock/reset, valid/ready handshake helpers, a watchdog,
and TODO markers for module-specific checks. An optional LLM pass (future) can
fill the checks in — but the skeleton always exists.

Input : butterfold_module_io.md
Output: tests/modules/tb_<module>.v   +   tests/modules/harness_manifest.json

Run standalone:
    python agents/harness_agent.py
"""
from __future__ import annotations
import re, json, pathlib

ROOT      = pathlib.Path(__file__).parent.parent
SPEC_IO   = ROOT / "butterfold_module_io.md"
OUT_DIR   = ROOT / "tests" / "modules"

# Functional section title (from the doc) -> assumed RTL module name.
_MODULE_NAMES = {
    "FDIQ I/O ADAPTER":            "fdiq_io_adapter",
    "UNIFIED MIXED-RADIX CORE":    "unified_mixed_radix_core",
    "TWIDDLE SOURCE":              "twiddle_source",
    "SCHEDULER + ADDRESS CONTROL": "scheduler_addr_control",
    "SUBCARRIER MAP / EXTRACT":    "subcarrier_map_extract",
    "TDIQ I/O ADAPTER WITH CP":    "tdiq_io_adapter_cp",
    "TOP-LEVEL CHIP INTERFACE":    "butterfold_top",
}

# Signal line:  "- name[hi:lo]   Input/Output   description"
_SIG_RE = re.compile(r"^\s*-\s*([A-Za-z_]\w*)\s*(\[[0-9]+:[0-9]+\])?\s+(Input|Output)\b")
# Section heading: "1. FDIQ I/O ADAPTER"  or  "TOP-LEVEL CHIP INTERFACE"
_NUM_HEAD_RE = re.compile(r"^\s*\d+\.\s+(.+?)\s*$")


def parse_modules(text: str):
    """Return {module_rtl_name: [(signal, width_or_'', 'Input'|'Output'), ...]}.

    Signals under 'Common signals for all modules' (clk, rst_n) are applied to
    every module. Duplicate signal names within a module are de-duplicated.
    """
    lines = text.splitlines()
    common: list = []
    modules: dict = {}
    cur = None
    in_common = False

    for ln in lines:
        stripped = ln.strip()

        if stripped.lower().startswith("common signals for all modules"):
            in_common, cur = True, None
            continue

        title = None
        m = _NUM_HEAD_RE.match(ln)
        if m and m.group(1).upper() in _MODULE_NAMES:
            title = m.group(1).upper()
        elif stripped.upper() in _MODULE_NAMES:           # TOP-LEVEL CHIP INTERFACE
            title = stripped.upper()
        if title:
            in_common = False
            cur = _MODULE_NAMES[title]
            modules.setdefault(cur, [])
            continue

        sm = _SIG_RE.match(ln)
        if not sm:
            continue
        sig = (sm.group(1), sm.group(2) or "", sm.group(3))
        if in_common:
            common.append(sig)
        elif cur:
            modules[cur].append(sig)

    # Merge common signals first, de-dup by name (module-local wins on conflict).
    out = {}
    for mod, sigs in modules.items():
        seen, merged = set(), []
        for name, width, direc in common + sigs:
            if name in seen:
                continue
            seen.add(name)
            merged.append((name, width, direc))
        out[mod] = merged
    return out


def _decl(name, width, direc):
    kind = "reg " if direc == "Input" else "wire"
    w = f"{width} " if width else ""
    return f"  {kind} {w}{name};"


def _handshake_helpers(sigs):
    """Emit a simple driver task for each *_valid input that has a *_ready output."""
    names = {s[0] for s in sigs}
    helpers = []
    for name, _w, direc in sigs:
        if direc == "Input" and name.endswith("_valid"):
            base  = name[:-6]
            ready = base + "_ready"
            if ready in names:
                helpers.append(
                    f"  // valid/ready handshake on '{base}': hold valid until ready\n"
                    f"  task drive_{base};\n"
                    f"    begin\n"
                    f"      {name} = 1'b1;\n"
                    f"      @(posedge clk); while (!{ready}) @(posedge clk);\n"
                    f"      {name} = 1'b0;\n"
                    f"    end\n"
                    f"  endtask")
    return "\n".join(helpers)


def emit_tb(module: str, sigs: list) -> str:
    has_clk   = any(s[0] == "clk"    for s in sigs)
    has_clki  = any(s[0] == "clk_i"  for s in sigs)
    has_rstn  = any(s[0] == "rst_n"  for s in sigs)
    has_rstni = any(s[0] == "rst_ni" for s in sigs)
    clk  = "clk_i"  if has_clki  else ("clk"  if has_clk  else None)
    rstn = "rst_ni" if has_rstni else ("rst_n" if has_rstn else None)

    decls   = "\n".join(_decl(*s) for s in sigs)
    conns   = ",\n".join(f"    .{s[0]}({s[0]})" for s in sigs)
    helpers = _handshake_helpers(sigs)
    clkgen  = f"  always #5 {clk} = ~{clk};\n" if clk else ""
    reset   = (f"      {rstn} = 1'b0; repeat(4) @(posedge {clk}); {rstn} = 1'b1;\n"
               if (rstn and clk) else "      // TODO: no clk/rst in this module's contract\n")

    inputs  = [s for s in sigs if s[2] == "Input"]
    init0   = "\n".join(f"      {s[0]} = 0;" for s in inputs)

    return f"""\
// tb_{module}.v  —  GENERATED testbench SKELETON by harness_agent.py
// Source of truth: butterfold_module_io.md  (regenerate; do not hand-edit headers).
// Module '{module}' is not yet implemented — this skeleton makes it independently
// checkable the moment its RTL exists. Fill in the TODO checks per the spec.
`timescale 1ns/1ps

module tb_{module};
  integer errors = 0;
  reg timeout_hit = 0;

  // ── DUT signals (from butterfold_module_io.md) ──────────────────────────
{decls}

  // ── DUT instantiation (port names from the I/O contract) ────────────────
  {module} dut (
{conns}
  );

{clkgen}
{helpers}

  // ── Stimulus ────────────────────────────────────────────────────────────
  initial begin
{init0}
{reset}
      // TODO: drive module-specific stimulus (use drive_<iface> helpers above)
      // TODO: $display("PASS") only when all spec checks pass; bump 'errors' otherwise

      repeat(50) @(posedge {clk if clk else 'clk'});
      if (errors == 0) $display("PASS: tb_{module} skeleton ran (add real checks)");
      else             $display("FAIL: tb_{module} (%0d errors)", errors);
      $finish;
  end

  // ── Watchdog ────────────────────────────────────────────────────────────
  initial begin
    #500000; timeout_hit = 1;
    $display("FAIL: tb_{module} TIMEOUT");
    $finish;
  end
endmodule
"""


def run() -> dict:
    if not SPEC_IO.exists():
        raise FileNotFoundError(f"I/O contract not found: {SPEC_IO}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    modules = parse_modules(SPEC_IO.read_text())
    manifest = {"source": SPEC_IO.name, "modules": {}}

    for mod, sigs in modules.items():
        tb_path = OUT_DIR / f"tb_{mod}.v"
        tb_path.write_text(emit_tb(mod, sigs), encoding="utf-8")
        n_in  = sum(1 for s in sigs if s[2] == "Input")
        n_out = sum(1 for s in sigs if s[2] == "Output")
        manifest["modules"][mod] = {
            "testbench": str(tb_path.relative_to(ROOT)).replace("\\", "/"),
            "ports": len(sigs), "inputs": n_in, "outputs": n_out,
        }
        print(f"[harness] {mod:28s} {len(sigs):3d} ports ({n_in} in / {n_out} out)  "
              f"-> {tb_path.relative_to(ROOT)}")

    (OUT_DIR / "harness_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"[harness] {len(modules)} module testbench skeletons + manifest written to "
          f"{OUT_DIR.relative_to(ROOT)}")
    return manifest


if __name__ == "__main__":
    run()
