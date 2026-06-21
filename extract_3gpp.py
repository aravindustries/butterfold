#!/usr/bin/env python3
"""
extract_3gpp.py — Extract ButterFold-relevant clauses from 3GPP spec PDFs.

Usage:
    python extract_3gpp.py TS_38.211.pdf [TS_38.212.pdf ...]
    python extract_3gpp.py TS_38.211.pdf --dry-run      # preview without writing
    python extract_3gpp.py TS_38.211.pdf --out other.md # custom output file

Finds sections matching DFT-s-OFDM / CP-OFDM / cyclic-prefix / subcarrier-spacing
keywords, formats them with clause number + source citation, and appends them to
3GPP_ButterFold_Spec_Extract.md so the planner and verify agents can cite them.

Output format matches the existing hand-curated entries in that file, so both
human-written and auto-extracted clauses can coexist cleanly.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from datetime import datetime

try:
    import pdfplumber
except ImportError:
    sys.exit("pdfplumber not installed — run: pip install pdfplumber>=0.11.0")

# ── Keywords that mark a section as relevant to ButterFold ───────────────────

_KEYWORDS = [
    r"DFT.s.OFDM",           # matches DFT-s-OFDM, DFTs-OFDM, DFT/s-OFDM etc.
    r"transform\s+precod",   # transform precoding / precoded
    r"CP.OFDM",
    r"cyclic\s+prefix",
    r"subcarrier\s+spacing",
    r"OFDM\s+baseband",
    r"resource\s+element\s+mapping",
    r"numerology",
    r"slot\s+format",
    r"IFFT",
    r"FFT\s+size",
    r"uplink\s+waveform",
    r"downlink\s+waveform",
    r"SC.FDMA",
    r"spread\w*\s+signal",
]

_KW_RE = re.compile("|".join(_KEYWORDS), re.IGNORECASE)

# 3GPP section headings look like "5.3.2   OFDM baseband signal generation"
# — a clause number followed by 2+ spaces then a title starting with a capital.
_HEADING_RE = re.compile(
    r"^(\d+(?:\.\d+)+)\s{2,}([A-Z].{3,100})$",
    re.MULTILINE,
)

# Lines that are just page headers/footers (document title, page numbers, dates)
_NOISE_RE = re.compile(
    r"^(3GPP\s+TS|ETSI\s+TS|Release\s+\d+|Technical\s+Specification|"
    r"Post-Rel-\d+|Page\s+\d+|\d{4}-\d{2}|\bConfidential\b)",
    re.IGNORECASE,
)


# ── PDF reading ───────────────────────────────────────────────────────────────

def _clean(text: str) -> str:
    """Strip page headers/footers that pollute extracted text."""
    lines = [ln for ln in text.splitlines() if not _NOISE_RE.match(ln.strip())]
    return "\n".join(lines)


def _read_pdf(path: pathlib.Path) -> tuple[str, list[tuple[int, list]]]:
    """
    Return (full_clean_text, [(page_num, tables), ...]).
    Raises RuntimeError if pdfplumber can't extract any text (scanned PDF).
    """
    full_text = ""
    page_offsets: list[tuple[int, int]] = []   # (char_offset, page_num)
    all_tables:   list[tuple[int, list]] = []

    with pdfplumber.open(path) as pdf:
        for i, page in enumerate(pdf.pages, start=1):
            raw = page.extract_text() or ""
            clean = _clean(raw)
            page_offsets.append((len(full_text), i))
            full_text += clean + "\n"

            tables = page.extract_tables() or []
            if tables:
                all_tables.append((i, tables))

    if not full_text.strip():
        raise RuntimeError(
            f"{path.name} produced no extractable text — it may be a scanned PDF. "
            "Convert it to text-layer PDF first (e.g. with OCRmyPDF)."
        )

    return full_text, page_offsets, all_tables


# ── Section splitting ─────────────────────────────────────────────────────────

def _page_for(offset: int, page_offsets: list[tuple[int, int]]) -> int:
    result = 1
    for char_off, pnum in page_offsets:
        if char_off <= offset:
            result = pnum
    return result


def _split_sections(
    full_text: str,
    page_offsets: list[tuple[int, int]],
    all_tables: list[tuple[int, list]],
) -> list[dict]:
    """Split full document text into section dicts by detected headings."""
    matches = list(_HEADING_RE.finditer(full_text))
    sections: list[dict] = []

    for idx, m in enumerate(matches):
        start = m.start()
        end   = matches[idx + 1].start() if idx + 1 < len(matches) else len(full_text)
        page  = _page_for(start, page_offsets)

        # Attach tables from the same page
        section_tables = []
        for pnum, tables in all_tables:
            if pnum == page:
                section_tables.extend(tables)

        sections.append({
            "clause":     m.group(1),
            "title":      m.group(2).strip(),
            "text":       full_text[start:end].strip(),
            "page":       page,
            "tables":     section_tables,
        })

    return sections


# ── Relevance filter ──────────────────────────────────────────────────────────

def _is_relevant(section: dict) -> bool:
    # Search in title + first 800 chars of body
    probe = section["title"] + "\n" + section["text"][:800]
    return bool(_KW_RE.search(probe))


# ── Markdown formatting ───────────────────────────────────────────────────────

def _fmt_table(table: list[list]) -> str:
    if not table or not table[0]:
        return ""
    rows = []
    for i, row in enumerate(table):
        cells = [str(c or "").replace("\n", " ").strip() for c in row]
        rows.append("| " + " | ".join(cells) + " |")
        if i == 0:
            rows.append("|" + "|".join("---" for _ in cells) + "|")
    return "\n".join(rows)


def _fmt_section(s: dict, pdf_name: str) -> str:
    lines = [
        f"### {s['clause']}  {s['title']}",
        f"*Source: {pdf_name}, p. {s['page']}*",
        "",
        s["text"],
    ]
    for tbl in s["tables"]:
        rendered = _fmt_table(tbl)
        if rendered:
            lines += ["", rendered, ""]
    lines.append("")
    return "\n".join(lines)


def _build_block(sections: list[dict], pdf_path: pathlib.Path) -> str:
    stamp  = datetime.now().strftime("%Y-%m-%d")
    header = (
        f"\n---\n\n"
        f"## Auto-extracted from {pdf_path.name}  *(extracted {stamp})*\n\n"
        f"{len(sections)} relevant sections found.\n\n"
    )
    body = "\n".join(_fmt_section(s, pdf_path.name) for s in sections)
    return header + body


# ── Main ─────────────────────────────────────────────────────────────────────

def process_pdf(pdf_path: pathlib.Path, out_path: pathlib.Path, dry_run: bool) -> int:
    """Extract and (optionally) append relevant sections from one PDF. Returns count."""
    print(f"\n[extract] {pdf_path.name}")

    try:
        full_text, page_offsets, all_tables = _read_pdf(pdf_path)
    except RuntimeError as e:
        print(f"[extract]   ERROR: {e}")
        return 0

    sections = _split_sections(full_text, page_offsets, all_tables)
    relevant = [s for s in sections if _is_relevant(s)]

    print(f"[extract]   {len(sections)} sections parsed, {len(relevant)} relevant")

    if not relevant:
        print("[extract]   Nothing to append.")
        return 0

    # Preview the clause list regardless of dry-run
    for s in relevant:
        print(f"[extract]   + {s['clause']:12s}  {s['title']}")

    block = _build_block(relevant, pdf_path)

    if dry_run:
        print("\n[extract]   --dry-run: output preview (first 2000 chars) ---")
        print(block[:2000])
        print("[extract]   --- (not written) ---")
    else:
        with open(out_path, "a", encoding="utf-8") as f:
            f.write(block)
        print(f"[extract]   Appended to {out_path.name}")

    return len(relevant)


def main() -> None:
    default_out = pathlib.Path(__file__).parent / "3GPP_ButterFold_Spec_Extract.md"

    parser = argparse.ArgumentParser(
        description="Extract ButterFold-relevant clauses from 3GPP PDF(s)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("pdfs", nargs="+", type=pathlib.Path, metavar="PDF",
                        help="3GPP spec PDF file(s) to process")
    parser.add_argument("--out", type=pathlib.Path, default=default_out,
                        help=f"Append target (default: {default_out.name})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print extracted text without writing to disk")
    args = parser.parse_args()

    total = 0
    for pdf_path in args.pdfs:
        if not pdf_path.exists():
            print(f"[extract] ERROR: {pdf_path} not found — skipping")
            continue
        total += process_pdf(pdf_path, args.out, dry_run=args.dry_run)

    print(f"\n[extract] Done — {total} sections total.")
    if not args.dry_run and total:
        print(f"[extract] Review {args.out} before committing.")


if __name__ == "__main__":
    main()
