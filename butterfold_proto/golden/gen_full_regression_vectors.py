#!/usr/bin/env python3
"""Generate and validate every vector set used by the full scheduler regression."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
VECTOR_DIR = ROOT / "vectors"

GENERATORS = (
    "gen_dft12_vectors.py",
    "gen_ofdm_rx_vectors.py",
    "gen_ofdm_tx_vectors.py",
)

EXPECTED_LINE_COUNTS = {
    "two_point_commands.hex": 8,
    "two_point_inputs.hex": 8,
    "two_point_expected.hex": 8,
    "fft3_inputs.hex": 8,
    "fft3_expected.hex": 8,
    "dft12_inputs.hex": 8 * 12,
    "dft12_expected.hex": 8 * 12,
    "fft128_inputs.hex": 5 * 128,
    "fft128_expected.hex": 5 * 128,
    "ifft128_inputs.hex": 5 * 128,
    "ifft128_expected.hex": 5 * 128,
    "fft128_twiddle_re.hex": 64,
    "fft128_twiddle_im.hex": 64,
    "ofdm_rx_normal_cp_inputs.hex": 4 * (9 + 128),
    "ofdm_rx_extended_cp_inputs.hex": 4 * (10 + 128),
    "ofdm_rx_normal_cp_expected.hex": 4 * 128,
    "ofdm_rx_extended_cp_expected.hex": 4 * 128,
    "ofdm_tx_normal_cp_inputs.hex": 5 * 12,
    "ofdm_tx_extended_cp_inputs.hex": 5 * 12,
    "ofdm_tx_normal_cp_expected.hex": 5 * (9 + 128),
    "ofdm_tx_extended_cp_expected.hex": 5 * (10 + 128),
}


def count_nonempty_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as stream:
        return sum(1 for line in stream if line.strip())


def validate_tx_cp(path: Path, cp_length: int, num_tests: int) -> None:
    samples = [line.strip().lower() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    samples_per_test = 128 + cp_length
    expected_total = num_tests * samples_per_test
    if len(samples) != expected_total:
        raise RuntimeError(
            f"{path.name}: expected {expected_total} samples, found {len(samples)}"
        )

    for test_index in range(num_tests):
        start = test_index * samples_per_test
        frame = samples[start : start + samples_per_test]
        prefix = frame[:cp_length]
        body = frame[cp_length:]
        if prefix != body[-cp_length:]:
            raise RuntimeError(
                f"{path.name}: CP copy check failed for test {test_index}"
            )


def main() -> None:
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    for generator in GENERATORS:
        print(f"\n=== Running {generator} ===")
        subprocess.run(
            [sys.executable, str(ROOT / generator)],
            cwd=ROOT,
            check=True,
        )

    errors: list[str] = []
    for name, expected_count in EXPECTED_LINE_COUNTS.items():
        path = VECTOR_DIR / name
        if not path.is_file():
            errors.append(f"missing {name}")
            continue
        actual_count = count_nonempty_lines(path)
        if actual_count != expected_count:
            errors.append(
                f"{name}: expected {expected_count} lines, found {actual_count}"
            )

    if errors:
        raise RuntimeError("Vector validation failed:\n  " + "\n  ".join(errors))

    validate_tx_cp(VECTOR_DIR / "ofdm_tx_normal_cp_expected.hex", 9, 5)
    validate_tx_cp(VECTOR_DIR / "ofdm_tx_extended_cp_expected.hex", 10, 5)

    print("\nAll full-regression vector files passed count and TX CP-copy checks.")


if __name__ == "__main__":
    main()
