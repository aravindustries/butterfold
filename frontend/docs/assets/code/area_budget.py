#!/usr/bin/env python3
"""Area budget pie chart — leader-line callouts for each slice.

Usage:
    from area_budget import area_budget, BlockDimensions

    # BlockDimensions with physical area (auto-computed percentage)
    area_budget([
        BlockDimensions("SRAM", length=432, breadth=269),
        BlockDimensions("FFT Butterfly", area=217800),
    ], core_area=1210000, title="Area Budget", output="budget.png")

    # dicts with direct percentage and optional subtitle (legacy)
    area_budget([
        {"name": "SRAM (data)", "pct": 32, "subtitle": "128×32b"},
        {"name": "FFT Butterfly", "pct": 18},
    ], title="Area Budget", output="budget.png")
"""

import argparse
import random

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

# ── palette: Windows-storage-bar inspired ───────────────────────────────
PALETTE = [
    "#4987D4",  # blue   (documents)
    "#E6802E",  # orange (pictures)
    "#5EB85A",  # green  (music)
    "#E6B42E",  # gold   (videos)
    "#9B5FC0",  # purple (other)
    "#D44E4E",  # red    (system)
    "#4DB8B8",  # teal
    "#C07A4D",  # brown
    "#7A8BA8",  # steel
    "#C0A06A",  # tan
]


def _normalise(items):
    """Normalise items to list of dicts with 'name', 'pct', 'subtitle'."""
    out = []
    for item in items:
        if isinstance(item, dict):
            out.append({
                "name": str(item.get("name", "")),
                "pct": float(item["pct"]),
                "subtitle": str(item.get("subtitle", "")),
            })
        elif isinstance(item, (list, tuple)):
            name, val = item[0], float(item[1])
            subtitle = str(item[2]) if len(item) > 2 else ""
            out.append({"name": str(name), "pct": val, "subtitle": subtitle})
        else:
            raise TypeError(f"Unexpected item type: {type(item)}")
    return out


def _random_colour(seed=None):
    """Generate a visually distinct random colour (avoids very dark/washed-out shades)."""
    rng = random.Random(seed)
    h = rng.random()
    s, v = 0.65, 0.80
    i = int(h * 6)
    f = h * 6 - i
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    rgb = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i % 6]
    return "#{:02x}{:02x}{:02x}".format(*(int(c * 255) for c in rgb))


def _colours(n):
    """Use palette colours first, then seeded random colours for extras."""
    if n <= len(PALETTE):
        return PALETTE[:n]
    extras = [_random_colour(seed=i) for i in range(len(PALETTE), n)]
    return list(PALETTE) + extras


def _fracs(parts):
    vals = np.asarray([p["pct"] for p in parts], dtype=float)
    is_pct = vals.max() > 1
    return vals / 100.0 if is_pct else vals / vals.sum(), is_pct


# ═══════════════════════════════════════════════════════════════════════
#  Pie chart with leader-line labels
# ═══════════════════════════════════════════════════════════════════════

def area_budget(
    items,
    title="Area Budget",
    output="area_budget.png",
    figsize=(10, 8),
    dpi=150,
    area_unit="%",
    label_radius=1.50,
    core_area=None,
    bg="white",
):
    """Draw a pie chart with leader-line callouts for each slice.

    Each wedge gets a radial leader line and a text label positioned
    outside the pie, with clean alignment (right-half labels left-aligned,
    left-half labels right-aligned).

    Parameters
    ----------
    items : list
        BlockDimensions instances (preferred), or legacy dicts/tuples.
        BlockDimensions with length+breadth or area have their percentage
        auto-computed from core_area.  If the sum of all block areas is
        less than core_area, a "Free Space" slice is added automatically.
    title : str
        Chart title.
    output : str or None
        File path.  If None, plt.show().
    figsize : tuple
        Figure dimensions — pie charts need roughly square aspect.
    dpi : int
        Image resolution.
    area_unit : str
        Unit suffix e.g. \"%\", \"µm²\", \"mm²\".
    label_radius : float
        Radial distance for label placement (default 1.50 × pie radius).
    core_area : float or None
        Total core area in µm².  Required when items contain
        BlockDimensions with physical dimensions.  When set, the
        total area is shown below the chart title.
    bg : str
        Background colour theme: ``"white"`` (default, light mode with
        dark text) or ``"black"`` (dark mode with light text).
    """
    # Pre-process: convert BlockDimensions instances to dicts.
    processed = []
    total_area = 0.0
    for item in items:
        if isinstance(item, BlockDimensions):
            if core_area is not None:
                area = item.area
                total_area += area
                pct = (area / core_area) * 100 if area else 0
                subtitle = f"{area:,.0f} µm²" if area else ""
                processed.append({"name": item.name, "pct": pct, "subtitle": subtitle})
            else:
                raise ValueError(
                    f"Block '{item.name}': physical dimensions given but "
                    "core_area is required to compute the percentage"
                )
        else:
            processed.append(item)

    # If blocks don't fully occupy core_area, add a Free Space slice.
    if core_area is not None and total_area < core_area:
        free_area = core_area - total_area
        free_pct = (free_area / core_area) * 100
        processed.append({
            "name": "Free Space",
            "pct": free_pct,
            "subtitle": f"{free_area:,.0f} µm²",
        })

    items = processed

    # ── colour scheme: light (default) or dark ───────────────────────
    if bg == "black":
        _c = {
            "fig_bg": "#111111",
            "wedge_edge": "#111111",
            "label": "#e0e0e0",
            "leader": "#777777",
            "title": "#cccccc",
            "subtitle": "#bbbbbb",
            "free_space": "#cccccc",
        }
    else:
        _c = {
            "fig_bg": "white",
            "wedge_edge": "white",
            "label": "#333333",
            "leader": "#999999",
            "title": "#555555",
            "subtitle": "#666666",
            "free_space": "#b0b0b0",
        }

    parts = _normalise(items)
    if not parts:
        raise ValueError("Need at least one item")

    fracs, is_pct = _fracs(parts)
    colours = _colours(len(parts))

    # Free Space slice gets a light grey wedge.
    if parts and parts[-1].get("name") == "Free Space":
        colours[-1] = _c["free_space"]

    fig, ax = plt.subplots(figsize=figsize)
    fig.patch.set_facecolor(_c["fig_bg"])
    ax.set_facecolor(_c["fig_bg"])

    # ── draw pie (no auto labels — we place them manually) ────────────
    wedges, _ = ax.pie(
        fracs,
        colors=colours,
        startangle=90,
        counterclock=False,
        wedgeprops={
            "linewidth": 2,
            "edgecolor": _c["wedge_edge"],
        },
    )

    # ── leader lines + labels ─────────────────────────────────────────
    for wedge, part in zip(wedges, parts):
        # centre angle of this wedge (degrees → radians)
        theta_deg = (wedge.theta1 + wedge.theta2) / 2.0
        theta = np.deg2rad(theta_deg)

        # point on the wedge edge (circle radius = 1)
        tip_x = np.cos(theta)
        tip_y = np.sin(theta)

        # label position further out along the same radius
        lab_x = label_radius * np.cos(theta)
        lab_y = label_radius * np.sin(theta)

        # alignment: right side → left-align, left side → right-align
        ha = "left" if lab_x >= 0 else "right"
        va = "center"

        # build label text
        pct_val = part["pct"]
        label_text = f"{part['name']} ({pct_val:.1f}{area_unit})"
        if part.get("subtitle"):
            label_text += f"\n{part['subtitle']}"

        # ── radial leader line ──────────────────────────────────
        ax.plot(
            [tip_x, lab_x],
            [tip_y, lab_y],
            color=_c["leader"],
            lw=0.8,
            solid_capstyle="round",
        )

        # ── text ────────────────────────────────────────────────
        ax.text(
            lab_x, lab_y, label_text,
            ha=ha, va=va,
            fontsize=8,
            color=_c["label"],
            linespacing=1.3,
        )

    # ── title ──────────────────────────────────────────────────────────
    if title:
        ax.text(
            0.5, 1.08, title,
            ha="center", va="bottom",
            fontsize=11, fontweight="bold", color=_c["title"],
            transform=ax.transAxes,
        )
    if core_area is not None:
        ax.text(
            0.5, 1.06, f"Total core area: {core_area:,.0f} µm²",
            ha="center", va="top",
            fontsize=10, fontweight="bold", color=_c["subtitle"],
            transform=ax.transAxes,
        )

    ax.axis("equal")
    fig.tight_layout(pad=1.0)
    if output:
        fig.savefig(output, dpi=dpi, bbox_inches="tight",
                    facecolor=fig.get_facecolor())
        print(f"Saved  → {output}")
    else:
        plt.show()
    plt.close(fig)


# ── convenience alias ────────────────────────────────────────────────────
area_budget_pie = area_budget


# ── BlockDimensions — physical footprint of a block ──────────────────

class BlockDimensions:
    """Physical footprint of a block.

    Provide either:
      - length + breadth  → single-instance geometry (multiply at the
        call site for multiple copies)
      - area              → total area (sum of all instances) in µm²

    The percentage contribution and subtitle are auto-computed from
    *core_area* passed to :func:`area_budget`.
    """

    def __init__(self, name, area=None, length=None, breadth=None):
        self.name = name if name is not None else "Unassigned"
        if area is not None:
            self.area = area
        elif length is not None and breadth is not None:
            self.area = self.calculate_area(length, breadth)
        else:
            self.area = 0

    @staticmethod
    def calculate_area(length, breadth):
        """Compute area from length and breadth."""
        return length * breadth

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Area budget pie chart")
    parser.add_argument(
        "--bg", choices=["white", "black"], default="white",
        help="Background colour theme (default: white)",
    )
    parser.add_argument(
        "--output", "-o", default="area_budget.png",
        help="Output file path",
    )
    args = parser.parse_args()

    default_sram64x8b_area = 431.86 * 232.88
    default_sram128x8b_area = 431.86 * 268.88

    timothy_sram64x8b_area = 301.3 * 152.21
    timothy_sram256x8b_area = 301.3 * 224.93

    area_budget(
        [
            BlockDimensions("SRAM 128×16b (data)",   area=2 * default_sram128x8b_area),
            BlockDimensions("SRAM 64×16b (twiddle)", area=2 * default_sram64x8b_area),
            BlockDimensions("128pt FFT (45nm)",      area=4002.84),
        ],
        core_area=1100 * 1100,
        title="ButterFold v1 — Area Budget",
        area_unit="%",
        output=args.output,
        bg=args.bg,
    )

