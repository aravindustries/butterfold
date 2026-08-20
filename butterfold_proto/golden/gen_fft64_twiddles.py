from pathlib import Path
import math

N = 64
FRAC_BITS = 7
SCALE = 1 << FRAC_BITS

out_dir = Path("vectors")
out_dir.mkdir(parents=True, exist_ok=True)


def q17(value: float) -> int:
    return max(-128, min(127, round(value * SCALE)))


def hex8(value: int) -> str:
    return f"{value & 0xFF:02x}"


with (
    (out_dir / "fft64_twiddle_re.hex").open("w", encoding="utf-8") as re_file,
    (out_dir / "fft64_twiddle_im.hex").open("w", encoding="utf-8") as im_file,
):
    for k in range(N // 2):
        angle = -2.0 * math.pi * k / N
        re = q17(math.cos(angle))
        im = q17(math.sin(angle))

        # Index zero is overridden by the scheduler's exact-unity proxy.
        re_file.write(hex8(re) + "\n")
        im_file.write(hex8(im) + "\n")

print("Generated vectors/fft64_twiddle_re.hex")
print("Generated vectors/fft64_twiddle_im.hex")
