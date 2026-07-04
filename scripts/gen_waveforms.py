#!/usr/bin/env python3
"""
gen_waveforms.py — render the functional-verification VCDs as clean digital
timing-diagram PNGs for the report. Self-contained: a minimal VCD parser plus a
matplotlib renderer (no gtkwave GUI, no extra packages beyond numpy/matplotlib).

Inputs  (produced by the --waves runs):
  generated/core_rf.vcd    generated/core_sram.vcd   (scripts/verify_core.sh --waves)
  generated/top_tx.vcd     generated/top_rx.vcd      (scripts/verify_top.sh  --waves)
Outputs:
  waveforms/*.png

Run INSIDE the container, from the repo root:
  bash scripts/verify_core.sh --waves && bash scripts/verify_top.sh --waves
  python3 scripts/gen_waveforms.py
"""
from __future__ import annotations
import pathlib, re, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon

ROOT = pathlib.Path(__file__).parent.parent
WAVE = ROOT / "waveforms"


# ----------------------------- minimal VCD parser -----------------------------
def parse_vcd(path: pathlib.Path):
    """Return (signals, tscale_ns). signals[name] = sorted list of (time, value):
    value is 0/1/'x' for scalars, or an int (or None if x) for vectors."""
    sym2names: dict[str, list[str]] = {}
    width: dict[str, int] = {}
    scope: list[str] = []
    tscale_ns = 1.0
    changes: dict[str, list[tuple[int, object]]] = {}
    defs = True
    t = 0
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        if defs:
            # $timescale value may be inline ("$timescale 1ps $end") or on its own
            # line (iverilog writes it multi-line), so match a bare unit token too.
            tm = re.search(r"(\d+)\s*([munp]?s)\b", line)
            if tm and ("timescale" in line or re.fullmatch(r"\d+\s*[munp]?s", line)):
                unit = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3}.get(tm.group(2), 1.0)
                tscale_ns = int(tm.group(1)) * unit
            if line.startswith("$timescale"):
                pass
            elif line.startswith("$scope"):
                scope.append(line.split()[2])
            elif line.startswith("$upscope"):
                if scope:
                    scope.pop()
            elif line.startswith("$var"):
                p = line.split()
                w, sym, nm = int(p[2]), p[3], p[4]
                full = ".".join(scope + [nm])
                sym2names.setdefault(sym, []).append(full)
                width[sym] = w
                changes.setdefault(sym, [])
            elif line.startswith("$enddefinitions"):
                defs = False
            continue
        # value-change section
        c = line[0]
        if c == "$":                 # $dumpvars / $dumpall / $end / $comment ...
            continue
        if c == "#":
            t = int(line[1:])
        elif c in "bB":
            bits, sym = line[1:].split()
            val = None if ("x" in bits or "z" in bits) else int(bits, 2)
            changes.setdefault(sym, []).append((t * tscale_ns, val))   # store time in ns
        elif c in "rR":
            pass  # no reals in these TBs
        else:
            sym = line[1:]
            val = c if c in "xz" else int(c)
            changes.setdefault(sym, []).append((t * tscale_ns, val))   # store time in ns

    signals: dict[str, list[tuple[int, object]]] = {}
    for sym, names in sym2names.items():
        for nm in names:
            signals[nm] = changes.get(sym, [])
    signals["__tscale_ns__"] = tscale_ns          # type: ignore
    signals["__width__"] = width                  # type: ignore
    # width by full name
    wbyname = {}
    for sym, names in sym2names.items():
        for nm in names:
            wbyname[nm] = width[sym]
    signals["__wbyname__"] = wbyname               # type: ignore
    return signals


def _find(signals, suffix):
    """Match a signal by exact leaf name (last dotted component)."""
    for nm in signals:
        if isinstance(nm, str) and nm.split(".")[-1] == suffix:
            return nm
    return None


def _val_at(chs, t):
    v = None
    for (ct, cv) in chs:
        if ct <= t:
            v = cv
        else:
            break
    return v


def _first_rise(chs, after=0):
    for (ct, cv) in chs:
        if ct >= after and cv == 1:
            return ct
    return None


def _first_value(chs, value, after=0):
    for (ct, cv) in chs:
        if ct >= after and cv == value:
            return ct
    return None


# ------------------------------- renderer -------------------------------------
def render(signals, names, t0, t1, title, out, tscale_ns=1.0):
    rows = []
    for label in names:
        nm = _find(signals, label)
        if nm is None:
            continue
        rows.append((label, signals[nm], signals["__wbyname__"][nm]))  # type: ignore
    n = len(rows)
    fig, ax = plt.subplots(figsize=(13, 0.62 * n + 1.0))
    span = max(1, t1 - t0)

    for i, (label, chs, w) in enumerate(rows):
        y = (n - 1 - i) * 1.0
        hi, lo = y + 0.72, y + 0.06
        # transitions inside [t0,t1], plus the value entering the window
        pts = [(t0, _val_at(chs, t0))] + [(ct, cv) for (ct, cv) in chs if t0 < ct <= t1]
        pts.append((t1, pts[-1][1]))
        if w == 1:
            xs, ys = [], []
            for j in range(len(pts) - 1):
                ct, cv = pts[j]; nt = pts[j + 1][0]
                lvl = hi if cv == 1 else lo
                xs += [ct, nt]; ys += [lvl, lvl]
                if j + 1 < len(pts) - 1 or True:
                    nv = pts[j + 1][1]
                    if nv != cv:
                        xs += [nt, nt]; ys += [lvl, (hi if nv == 1 else lo)]
            ax.plot(xs, ys, color="#1a6", lw=1.4)
        else:
            hexd = max(1, math.ceil(w / 4))
            for j in range(len(pts) - 1):
                ct, cv = pts[j]; nt = pts[j + 1][0]
                if nt <= ct:
                    continue
                ax.add_patch(Polygon([(ct, y + 0.39), (ct + span * 0.006, hi),
                                      (nt - span * 0.006, hi), (nt, y + 0.39),
                                      (nt - span * 0.006, lo), (ct + span * 0.006, lo)],
                                     closed=True, fill=False, edgecolor="#268", lw=1.2))
                txt = "x" if cv is None else f"{cv:0{hexd}x}"
                if (nt - ct) > span * 0.02:
                    ax.text((ct + nt) / 2, y + 0.39, txt, ha="center", va="center",
                            fontsize=8, family="monospace", color="#124")
        ax.text(t0 - span * 0.012, y + 0.39, label, ha="right", va="center",
                fontsize=9, family="monospace")

    ax.set_xlim(t0 - span * 0.16, t1 + span * 0.01)
    ax.set_ylim(-0.3, n)
    ax.set_yticks([])
    ax.set_xlabel("time (ns)")
    ax.set_title(title, fontsize=11, loc="left")
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="x", ls=":", alpha=0.35)
    fig.tight_layout()
    WAVE.mkdir(exist_ok=True)
    fig.savefig(out, dpi=130)
    plt.close(fig)
    print(f"[waveforms] wrote {out.relative_to(ROOT)}  ({n} signals, t=[{t0},{t1}])")


def figure(vcd_name, names, focus, out_name, title, pre, post, focus_value=None):
    vcd = ROOT / "generated" / vcd_name
    if not vcd.exists():
        print(f"[waveforms] SKIP {vcd_name} (not found — run the --waves script first)")
        return
    sig = parse_vcd(vcd)
    fnm = _find(sig, focus)
    t0 = 0
    if fnm:
        base = (_first_value(sig[fnm], focus_value) if focus_value is not None
                else _first_rise(sig[fnm]))
        if base is not None:
            t0 = max(0, base - pre)
    t1 = t0 + pre + post
    render(sig, names, t0, t1, title, WAVE / out_name, sig["__tscale_ns__"])  # type: ignore


if __name__ == "__main__":
    # 1) register-file core — the butterfly micro-op stream (one op/cycle)
    figure("core_rf.vcd",
           ["clk", "uop_valid", "uop_ready", "src_addr_0", "src_addr_1",
            "twiddle_re", "twiddle_im", "uop_done"],
           focus="uop_valid", out_name="core_rf_uops.png",
           title="Register-file core — radix-2 butterfly micro-op stream (one op/cycle)",
           pre=20, post=200)

    # 2) SRAM core — the 5-cycle single-port FSM per micro-op
    figure("core_sram.vcd",
           ["clk", "uop_valid", "uop_ready", "state", "mem_a", "mem_we",
            "uop_done"],
           focus="uop_valid", out_name="core_sram_fsm.png",
           title="SRAM-macro core — 5-cycle single-port butterfly FSM (per micro-op)",
           pre=20, post=160)

    # 3) whole chip — command + payload streaming IN (external view, same for both)
    figure("top_tx_rf.vcd",
           ["clk", "din", "din_valid_i", "din_ready_o", "dout", "dout_valid_o"],
           focus="din_valid_i", out_name="top_tx_in.png",
           title="Integrated top — TX command (0x03) + payload byte stream IN",
           pre=20, post=220)

    # 4) whole chip — 274-byte result streaming OUT (external view, same for both)
    figure("top_tx_rf.vcd",
           ["clk", "dout", "dout_valid_o", "dout_ready_i", "din_ready_o"],
           focus="dout_valid_o", out_name="top_tx_out.png",
           title="Integrated top — TX result byte stream OUT (274 bytes)",
           pre=20, post=220)

    # 5) SRAM end-to-end top — single-port scratch sequencing inside the FFT
    #    (st==5 is S_FFT; ss cycles the 5-phase read/read/write/write per butterfly)
    figure("top_tx_sram.vcd",
           ["clk", "st", "ss", "mem_a", "mem_we"],
           focus="st", focus_value=5, out_name="top_sram_fft.png",
           title="SRAM end-to-end top — single-port scratch memory sequencing during FFT",
           pre=10, post=210)
