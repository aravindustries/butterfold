#!/usr/bin/env python3
"""Generate vectors for the real-time ping-pong wrapper regression.

The proven fixed-point generators remain the source of truth. This script:
  * regenerates all legacy standalone / OFDM vectors,
  * renames normal-CP files using short/long normal-CP terminology,
  * reduces OFDM_RX expected output to the fixed one-RB allocation (bins 1..12),
  * retains the full TX waveform expected files.
"""
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
V = ROOT / "vectors"
NUM_RX_TESTS = 4
SC_START = 1
SC_COUNT = 12


def lines(path: Path) -> list[str]:
    return [x.strip() for x in path.read_text(encoding="utf-8").splitlines() if x.strip()]


def write_lines(path: Path, values: list[str]) -> None:
    path.write_text("\n".join(values) + "\n", encoding="utf-8")


def extract_rb(src: Path, dst: Path) -> None:
    full = lines(src)
    if len(full) != NUM_RX_TESTS * 128:
        raise RuntimeError(f"{src.name}: expected {NUM_RX_TESTS*128} samples, got {len(full)}")
    selected: list[str] = []
    for test in range(NUM_RX_TESTS):
        frame = full[test*128:(test+1)*128]
        selected.extend(frame[SC_START:SC_START+SC_COUNT])
    write_lines(dst, selected)


def main() -> None:
    V.mkdir(exist_ok=True)
    subprocess.run([sys.executable, str(ROOT / "gen_full_regression_vectors.py")], cwd=ROOT, check=True)

    # RX input waveforms: terminology-only rename.
    shutil.copyfile(V / "ofdm_rx_normal_cp_inputs.hex", V / "ofdm_rx_short_normal_cp_inputs.hex")
    shutil.copyfile(V / "ofdm_rx_extended_cp_inputs.hex", V / "ofdm_rx_long_normal_cp_inputs.hex")

    # RX production output is now exactly one RB: natural bins 1..12.
    extract_rb(V / "ofdm_rx_normal_cp_expected.hex", V / "ofdm_rx_short_normal_cp_expected_rb.hex")
    extract_rb(V / "ofdm_rx_extended_cp_expected.hex", V / "ofdm_rx_long_normal_cp_expected_rb.hex")

    # TX waveform values are unchanged; only terminology changes.
    shutil.copyfile(V / "ofdm_tx_normal_cp_inputs.hex", V / "ofdm_tx_short_normal_cp_inputs.hex")
    shutil.copyfile(V / "ofdm_tx_extended_cp_inputs.hex", V / "ofdm_tx_long_normal_cp_inputs.hex")
    shutil.copyfile(V / "ofdm_tx_normal_cp_expected.hex", V / "ofdm_tx_short_normal_cp_expected.hex")
    shutil.copyfile(V / "ofdm_tx_extended_cp_expected.hex", V / "ofdm_tx_long_normal_cp_expected.hex")

    expected_counts = {
        "ofdm_rx_short_normal_cp_inputs.hex": NUM_RX_TESTS * (9 + 128),
        "ofdm_rx_long_normal_cp_inputs.hex": NUM_RX_TESTS * (10 + 128),
        "ofdm_rx_short_normal_cp_expected_rb.hex": NUM_RX_TESTS * 12,
        "ofdm_rx_long_normal_cp_expected_rb.hex": NUM_RX_TESTS * 12,
        "ofdm_tx_short_normal_cp_inputs.hex": 5 * 12,
        "ofdm_tx_long_normal_cp_inputs.hex": 5 * 12,
        "ofdm_tx_short_normal_cp_expected.hex": 5 * (9 + 128),
        "ofdm_tx_long_normal_cp_expected.hex": 5 * (10 + 128),
    }
    for name, expected in expected_counts.items():
        actual = len(lines(V / name))
        if actual != expected:
            raise RuntimeError(f"{name}: expected {expected} lines, got {actual}")

    print("Real-time wrapper vectors generated successfully.")
    print("OFDM_RX output is fixed one-RB extraction: natural FFT bins 1..12.")
    print("CP terminology: short normal CP=9, long normal CP=10.")


if __name__ == "__main__":
    main()
