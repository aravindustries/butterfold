"""
code_agent.py — modular RTL authoring agent.

For each module in the build order, the deep (ReAct) agent authors the complete
Verilog file from that module's port/function contract (parsed from
butterfold_module_io.md), checking itself with compile / elaborate / testbench
between edits. No flat generator, no locked kernel: every module is written from
its contract.

With no OPENAI_API_KEY, each module falls back to its compile-clean port skeleton
so the pipeline still produces elaborable RTL end-to-end.

Run all modules:      python code_agent.py
Run one module:       python code_agent.py --module twiddle_source
"""
from __future__ import annotations
import sys, pathlib
import module_spec
import agent_core
import helpers

ROOT    = pathlib.Path(__file__).parent.parent
RTL_DIR = ROOT / "generated" / "rtl"
sys.path.insert(0, str(ROOT / "golden"))

_vectors_ready = False


def _ensure_vectors() -> None:
    """Emit the golden vectors once so the FUNCTIONAL testbenches have their
    expected data while the agent authors (the tb run_tb gate reads them)."""
    global _vectors_ready
    if _vectors_ready:
        return
    try:
        import vectors
        vectors.emit()
        _vectors_ready = True
    except Exception as exc:
        print(f"[code_agent] (golden vectors not emitted: {exc})")


def _deps(name: str) -> list[str]:
    import planner
    return planner.DEPENDS.get(name, [])


def _golden_hint(name: str) -> str:
    """Per-module 'translate the golden, don't invent' hint. The functional
    testbench enforces it; the hint makes the target explicit."""
    if name == "complex_mul":
        return (
            "\n\nIMPLEMENTATION HINT (match the golden exactly):\n"
            "Signed Q1.7 complex multiply, purely COMBINATIONAL (use `assign`).\n"
            "Treat all ports as signed. Compute with enough width, then round+saturate:\n"
            "  accr = a_re*b_re - a_im*b_im;   // signed, ~18 bits\n"
            "  acci = a_re*b_im + a_im*b_re;\n"
            "  p_re = sat8((accr + 64) >>> 7); // round-to-nearest, arithmetic >>7 (div 128)\n"
            "  p_im = sat8((acci + 64) >>> 7);\n"
            "where sat8(x) clamps to [-128,127]. Declare intermediates `signed` and wide\n"
            "enough (e.g. signed [17:0]); use $signed()/arithmetic shift >>> so negatives\n"
            "round correctly. Do NOT register — no clk/rst here.")
    if name == "tdiq_io_adapter_cp":
        return (
            "\n\nIMPLEMENTATION HINT (RX CP-removal path is what the gate checks):\n"
            "Synchronous FSM. On `cp_start` with cp_insert=0 (RX), pack the incoming\n"
            "time-domain byte stream (I then Q per sample) into complex samples and\n"
            "REMOVE the cyclic prefix:\n"
            "  - hold tdiq_in_ready high while active; accept a byte on\n"
            "    tdiq_in_valid && tdiq_in_ready; first byte = I, second = Q.\n"
            "  - count samples 0..136 (137 total). DROP the first cp_len samples\n"
            "    (the CP, cp_len=9). For sample index >= cp_len, emit\n"
            "    rx_symbol_data <= {I,Q} with rx_symbol_valid pulsed one cycle.\n"
            "  - that yields exactly 128 output samples; assert rx_symbol_last on the\n"
            "    last one (input sample index 136).\n"
            "  - busy while active; done when complete.\n"
            "Drive every output; tie unused TX-path outputs (tdiq_out_*, "
            "tx_symbol_rd_*) to 0. Assign each output reg only ONCE per always block.")
    if name == "fdiq_io_adapter":
        return (
            "\n\nIMPLEMENTATION HINT (TX packing path is what the gate checks):\n"
            "Synchronous FSM on posedge clk, active-low rst_n. On `start` with\n"
            "direction=1 (TX), pack the external interleaved byte stream into 12\n"
            "internal complex samples:\n"
            "  - hold fdiq_in_ready high while active; accept a byte when\n"
            "    fdiq_in_valid && fdiq_in_ready.\n"
            "  - the FIRST byte of each pair is I, the SECOND is Q; when both are in,\n"
            "    drive fd_in_data <= {I[7:0], Q[7:0]} and pulse fd_in_valid for one\n"
            "    cycle. Assert fd_in_last on the 12th sample.\n"
            "  - count 12 samples, then drop busy and pulse done; go idle.\n"
            "  - busy high while active; done when the block completes.\n"
            "Drive EVERY output (fd_in_valid low when not emitting). Unused RX-path\n"
            "outputs (fdiq_out_*, fd_out_ready) may be tied to 0. Register outputs;\n"
            "assign each output reg only ONCE per always block.")
    if name == "butterfly":
        return (
            "\n\nIMPLEMENTATION HINT (match the golden exactly, all signed):\n"
            "Radix-2 DIT butterfly, COMBINATIONAL. top_*/bot_* are Q5.11 signed 16-bit,\n"
            "w_* are Q1.7 signed 8-bit. Use a round-to-nearest arithmetic shift helper\n"
            "RND(x,s) = (x + (1<<(s-1))) >>> s. Compute:\n"
            "  tr = RND(bot_re*w_re - bot_im*w_im, 7);  // Q5.11\n"
            "  ti = RND(bot_re*w_im + bot_im*w_re, 7);\n"
            "  otop_re = sat16(RND(top_re + tr, 1)); otop_im = sat16(RND(top_im + ti, 1));\n"
            "  obot_re = sat16(RND(top_re - tr, 1)); obot_im = sat16(RND(top_im - ti, 1));\n"
            "sat16 clamps to [-32768,32767]. Declare intermediates signed and wide enough\n"
            "(bot*w needs ~26 bits). Use $signed()/>>>. No clk/rst — purely combinational.")
    if name == "twiddle_source":
        try:
            import reference
            re, im = reference.twiddle_rom(reference.K)
            rows = "\n".join(f"  {a}: tw_re={re[a]}, tw_im={im[a]}" for a in range(len(re)))
            return (
                "\n\nIMPLEMENTATION HINT (golden LUT — match exactly):\n"
                "twiddle_source is a ROM of quantized signed Q1.7 (int8) twiddles.\n"
                "For tw_conjugate=0, output EXACTLY these values for tw_addr=0..11:\n"
                f"{rows}\n"
                "For tw_conjugate=1, keep tw_re and NEGATE tw_im (two's complement: ~im + 1).\n"
                "Addresses >= 12 return 0. Do NOT compute trig — hardcode the table.\n"
                "STRUCTURE (avoid the non-blocking hazard): first compute base_re/base_im\n"
                "COMBINATIONALLY from a case on tw_addr (e.g. `reg signed [7:0] base_re,\n"
                "base_im; always @* case(tw_addr) ...`). Then in the clocked block register\n"
                "ONCE:  tw_re <= base_re;  tw_im <= tw_conjugate ? (~base_im + 8'd1) : base_im;\n"
                "NEVER assign tw_im (or any output reg) twice in the same always block — the\n"
                "second assignment overrides the first and reads the stale registered value.\n"
                "Assert tw_valid the cycle the registered output is valid (register tw_req).")
        except Exception:
            return ""
    return ""


def _goal(name: str, contract: str, deps: list[str], doc: dict) -> str:
    if not deps:
        return (f"Author the synthesizable Verilog-2012 module `{name}` implementing exactly "
                f"this contract. Match every port name/direction/width.\n\n{contract}")
    # For an integrating module, give the EXACT submodule contracts so it wires
    # real port names (never guessed) and instantiates the modules by name.
    sub = "\n\n".join(module_spec.contract_text(doc["modules"][d]) for d in deps)
    return (f"Author the synthesizable Verilog-2012 module `{name}` implementing exactly "
            f"this contract. Match every port name/direction/width. This is the top: it must "
            f"INSTANTIATE and wire the submodules below using their EXACT port names — do not "
            f"invent ports. The submodule files already exist in generated/rtl and are compiled "
            f"alongside your module, so instantiate them directly.\n\n"
            f"=== THIS MODULE ({name}) CONTRACT ===\n{contract}\n\n"
            f"=== SUBMODULE CONTRACTS TO INSTANTIATE ===\n{sub}")


def author_module(name: str, doc: dict, journal: agent_core.Journal) -> dict:
    _ensure_vectors()
    if helpers.is_helper(name):
        contract, skel, deps, nports = (helpers.contract_text(name),
                                        helpers.skeleton(name), [],
                                        len(helpers.HELPERS[name]["ports"]))
    else:
        mod = doc["modules"][name]
        contract, skel, deps, nports = (module_spec.contract_text(mod),
                                        module_spec.skeleton(mod), _deps(name),
                                        len(mod["ports"]))
    dep_files = [RTL_DIR / f"{d}.v" for d in deps]
    harness   = agent_core.ModuleHarness(name, contract, journal, skeleton=skel,
                                         dep_files=dep_files)

    hint = _golden_hint(name)
    goal = (_goal(name, contract, deps, doc) if not helpers.is_helper(name)
            else f"Author the synthesizable Verilog-2012 module `{name}` implementing "
                 f"exactly this contract. Match every port name/direction/width.\n\n{contract}"
            ) + hint
    # Functional rungs (golden-gated) need more iterations than a structural pass:
    # each fix costs write+compile+elaborate+run_tb (~4 steps).
    steps = 24 if hint else 14
    print(f"[code_agent] authoring {name} ({nports} ports)...")
    res = agent_core.react_loop(goal, harness, journal, agent=name, max_steps=steps)

    # Safety net: if the agent finished without leaving a file, drop the skeleton
    # so downstream integration/elaboration still has a module.
    if not harness.path.exists():
        harness.write_module(skel)
        res["summary"] = (res.get("summary", "") + " | skeleton written as fallback").strip()
    print(f"[code_agent]   {name}: {res.get('status','?')} "
          f"({res.get('summary','').strip()[:80]})")
    return res


def run(only: str | None = None) -> dict:
    doc     = module_spec.parse()
    journal = agent_core.Journal()
    order   = [only] if only else doc["order"]
    results = {}
    for name in order:
        if name not in doc["modules"] and not helpers.is_helper(name):
            print(f"[code_agent] unknown module: {name}"); continue
        results[name] = author_module(name, doc, journal)
    ok = sum(1 for r in results.values() if r.get("ok"))
    print(f"[code_agent] authored {len(results)} module(s); {ok} reached success status")
    return {"results": results, "rtl_dir": str(RTL_DIR)}


def run_react(only: str | None = None) -> dict:
    return run(only)


if __name__ == "__main__":
    only = None
    if "--module" in sys.argv:
        only = sys.argv[sys.argv.index("--module") + 1]
    run(only)
