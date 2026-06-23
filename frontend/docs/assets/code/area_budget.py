import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import random
from pathlib import Path

def random_color(seed=None):
    """Generate a visually distinct random color (avoids very dark or washed-out shades)."""
    rng = random.Random(seed)
    h = rng.random()
    # Convert HSV -> RGB manually for control over saturation/value
    s, v = 0.65, 0.80
    i = int(h * 6)
    f = h * 6 - i
    p, q, t = v*(1-s), v*(1-s*f), v*(1-s*(1-f))
    rgb = [(v,t,p),(q,v,p),(p,v,t),(p,q,v),(t,p,v),(v,p,q)][i % 6]
    return '#{:02x}{:02x}{:02x}'.format(*(int(c*255) for c in rgb))

def get_colors(n, palette):
    """Use palette colors first, then fall back to random for extras."""
    colors = list(palette)
    if n <= len(colors):
        return colors[:n]
    # Seed by index so colors are stable across calls
    extras = [random_color(seed=i) for i in range(len(colors), n)]
    return colors + extras

def draw_partition_table(partitions, figsize=(12, 3.2), title=None):
    PALETTE = ['#2563eb', '#16a34a', '#9333ea', '#ea580c', '#0891b2', '#be123c']
    FREE_COLOR = '#2a2a2a'

    total = sum(p['pct'] for p in partitions)
    free_pct = max(0, 100 - total)

    all_segments = partitions + ([{'name': 'Free Space', 'subtitle': f'{free_pct:.1f}%', 'pct': free_pct}] if free_pct > 0 else [])
    all_colors   = get_colors(len(partitions), PALETTE) + ([FREE_COLOR] if free_pct > 0 else [])

    fig, ax = plt.subplots(figsize=figsize)
    fig.patch.set_facecolor('#111111')
    ax.set_facecolor('#1a1a1a')

    MIN_PCT_FOR_NAME     = 18
    MIN_PCT_FOR_SUBTITLE = 6

    x = 0
    for part, color in zip(all_segments, all_colors):
        w = part['pct'] / 100
        ax.barh(0, w, left=x, height=0.65, color=color,
                linewidth=2, edgecolor='#111111')

        cx = x + w / 2
        pct = part['pct']

        if pct >= MIN_PCT_FOR_NAME:
            name = part['name']
            char_budget = int((pct / 100) * figsize[0] * 2.2)
            if len(name) > char_budget:
                name = name[:max(char_budget - 1, 3)] + '…'
            ax.text(cx, 0.12, name,
                    ha='center', va='center',
                    fontsize=8, color='white', fontweight='bold')

        if pct >= MIN_PCT_FOR_SUBTITLE:
            ax.text(cx, -0.13, part.get('subtitle', ''),
                    ha='center', va='center',
                    fontsize=7, color='#aaaaaa')

        x += w

    ax.set_xlim(0, 1)
    ax.set_ylim(-0.5, 0.5)
    ax.axis('off')

    legend_patches = [
        mpatches.Patch(facecolor=color, label=f"{part['name']}  ({part['pct']:.1f}%)  {part.get('subtitle', '')}")
        for part, color in zip(all_segments, all_colors)
    ]
    ax.legend(
        handles=legend_patches,
        loc='lower center',
        bbox_to_anchor=(0.5, -0.15),
        ncol=min(len(legend_patches), 3),
        frameon=False,
        fontsize=8,
        labelcolor='white',
        handlelength=1.2,
        handleheight=0.9,
    )
    if title:
        ax.text(0.5, 0.46, title,
                ha='center', va='top',
                fontsize=9, color='#cccccc',
                transform=ax.transData)

    plt.tight_layout(pad=0.3)
    file_name = Path(__file__).stem
    plt.savefig(f"../{file_name}.png", dpi=150, bbox_inches='tight',
                facecolor=fig.get_facecolor())

def main():
    ################# Initialisations #####################
    # Total Area
    core_length = 1.1 # mm
    core_length_um = core_length * 1000 # um
    core_width  = 1.1 # mm
    core_width_um  = core_width * 1000  # um
    total_area = core_length_um * core_width_um
    # print(f"{total_area = }")

    default_sram64x8b_length = 431.86 # um
    default_sram64x8b_width  = 232.88 # um
    default_sram64x8b_area = default_sram64x8b_length * default_sram64x8b_width

    timothy_sram64x8b_length = 301.3  # um
    timothy_sram64x8b_width  = 152.21 # um
    timothy_sram64x8b_area = timothy_sram64x8b_length * timothy_sram64x8b_width

    default_sram128x8b_length = 431.86 # um
    default_sram128x8b_width  = 268.88 # um
    default_sram128x8b_area = default_sram128x8b_length * default_sram128x8b_width
    # print(f"{sram128x8b_area = }")

    timothy_sram256x8b_length = 301.3  # um
    timothy_sram256x8b_width  = 224.93 # um
    timothy_sram256x8b_area = timothy_sram256x8b_length * timothy_sram256x8b_width

    # default_sram512x8b_length = 431.86 # um
    # default_sram512x8b_width  = 484.88 # um
    # default_sram512x8b_area = default_sram512x8b_length * default_sram512x8b_width
    # # print(f"{sram512x8b_area = }")
    ################# Initialisations #####################

    # 4 for 128x32b SRAM (data storage)
    default_sram128x16b_area = 2 * default_sram128x8b_area

    # 4 for 512x32b SRAM (twiddle storage)
    default_sram64x16b_area = 2 * default_sram64x8b_area

    partitions = [
        {'name': f'default_sram128x16b (data) Area {default_sram128x16b_area}um2', 'subtitle': '',  'pct': (default_sram128x16b_area/total_area)*100},
        {'name': f'default_sram64x16b (twiddle) Area {default_sram64x16b_area}um2', 'subtitle': '', 'pct': (default_sram64x16b_area/total_area)*100},
    ]

    draw_partition_table(partitions, title=f"Total Area {total_area}um2 ({core_length_um}um x {core_width_um}um)")

if __name__ == "__main__": main()

