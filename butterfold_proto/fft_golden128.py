from pathlib import Path
import numpy as np

NUM_TESTS = 5
SEED = 1234

rng = np.random.default_rng(SEED)

output_dir = Path("vectors")
output_dir.mkdir(exist_ok=True)


def q17(x):
    """Convert float to signed 8-bit Q1.7."""
    return np.clip(np.round(x * 128), -128, 127).astype(np.int16)


def hex8(x):
    """Convert signed integer to 8-bit two's-complement hex."""
    return f"{int(x) & 0xffff:04x}"


with (
    (output_dir / "two_point_inputs.hex").open("w") as input_file,
    (output_dir / "two_point_expected.hex").open("w") as expected_file,
):
    for _ in range(NUM_TESTS):
        # Two complex input samples
        i = q17(rng.uniform(-1.0, 1.0, 2))
        q = q17(rng.uniform(-1.0, 1.0, 2))

        # 2-point FFT:
        # X[0] = x[0] + x[1]
        # X[1] = x[0] - x[1]
        out_i = np.array([
            i[0] + i[1],
            i[0] - i[1],
        ])

        out_q = np.array([
            q[0] + q[1],
            q[0] - q[1],
        ])


        input_file.write(
            f"{hex8(i[0])}{hex8(q[0])}"
            f"{hex8(i[1])}{hex8(q[1])}\n"
        )

        expected_file.write(
            f"{hex8(out_i[0])}{hex8(out_q[0])}"
            f"{hex8(out_i[1])}{hex8(out_q[1])}\n"
        )

print(f"Generated {NUM_TESTS} test vectors.")
