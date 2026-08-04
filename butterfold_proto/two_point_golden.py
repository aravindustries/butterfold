from pathlib import Path

import numpy as np


NUM_TESTS = 5
SEED = 1234

rng = np.random.default_rng(SEED)

output_dir = Path("vectors")
output_dir.mkdir(parents=True, exist_ok=True)


def q17(value: np.ndarray) -> np.ndarray:
    """Quantize floats to signed 8-bit Q1.7 integer codes."""
    scaled = np.round(value * 128.0)
    clipped = np.clip(scaled, -128, 127)

    return clipped.astype(np.int16)


def hex8(value: int) -> str:
    """Convert an integer to two-digit 8-bit two's-complement hex."""
    return f"{int(value) & 0xFF:02x}"


def hex16(value: int) -> str:
    """Convert an integer to four-digit 16-bit two's-complement hex."""
    return f"{int(value) & 0xFFFF:04x}"


with (
    (output_dir / "two_point_inputs.hex").open(
        "w",
        encoding="utf-8",
    ) as input_file,
    (output_dir / "two_point_expected.hex").open(
        "w",
        encoding="utf-8",
    ) as expected_file,
):
    for _ in range(NUM_TESTS):
        input_i = q17(rng.uniform(-1.0, 1.0, size=2))
        input_q = q17(rng.uniform(-1.0, 1.0, size=2))

        input_i_wide = input_i.astype(np.int32)
        input_q_wide = input_q.astype(np.int32)

        output_i = np.array(
            [
                input_i_wide[0] + input_i_wide[1],
                input_i_wide[0] - input_i_wide[1],
            ],
            dtype=np.int32,
        )

        output_q = np.array(
            [
                input_q_wide[0] + input_q_wide[1],
                input_q_wide[0] - input_q_wide[1],
            ],
            dtype=np.int32,
        )

        input_file.write(
            f"{hex8(input_i[0])}"
            f"{hex8(input_q[0])}"
            f"{hex8(input_i[1])}"
            f"{hex8(input_q[1])}\n"
        )

        expected_file.write(
            f"{hex16(output_i[0])}"
            f"{hex16(output_q[0])}"
            f"{hex16(output_i[1])}"
            f"{hex16(output_q[1])}\n"
        )


print(f"Generated {NUM_TESTS} FFT2 test vectors.")
print(f"Input file:    {output_dir / 'two_point_inputs.hex'}")
print(f"Expected file: {output_dir / 'two_point_expected.hex'}")
