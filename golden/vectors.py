"""
golden/vectors.py — emit the input/expected test vectors the Verilog testbenches
consume in Phase 2. Vectors come straight from the golden models, so RTL is
checked against the Python golden's I/O.

Writes (hex, one value per line, for $readmemh):
  tests/vectors/top_in.hex     24 input bytes  (12 complex Q1.7 samples, TX)
  tests/vectors/top_gold.hex   274 golden output bytes (137 complex, CP=9)
  tests/vectors/twiddle_addr.hex / twiddle_gold.hex   twiddle LUT check (n=12)

Run: python golden/vectors.py
"""
from __future__ import annotations
import pathlib
import numpy as np

ROOT   = pathlib.Path(__file__).parent.parent
VECDIR = ROOT / "tests" / "vectors"
import reference


def _write_bytes(path: pathlib.Path, data) -> None:
    """int8/byte array -> hex file (unsigned 2-hex per line)."""
    arr = np.asarray(data)
    lines = [f"{int(v) & 0xFF:02x}" for v in arr]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_words(path: pathlib.Path, data) -> None:
    """value list -> hex file (up to 16-bit, 4-hex per line)."""
    lines = [f"{int(v) & 0xFFFF:04x}" for v in data]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def emit(seed: int = 42) -> dict:
    VECDIR.mkdir(parents=True, exist_ok=True)
    in_bytes = reference.random_input_bytes(seed)
    tx       = reference.tx_reference(in_bytes)
    _write_bytes(VECDIR / "top_in.hex",   in_bytes)
    _write_bytes(VECDIR / "top_gold.hex", tx["out_bytes"])

    # twiddle_source: addresses 0..11 and expected {re,im} for the 12-pt LUT.
    tre, tim = reference.twiddle_rom(reference.K)
    _write_words(VECDIR / "twiddle_addr.hex", list(range(reference.K)))
    _write_bytes(VECDIR / "twiddle_re.hex", tre)
    _write_bytes(VECDIR / "twiddle_im.hex", tim)

    info = {"seed": seed, "top_in": 24, "top_gold": len(tx["out_bytes"]),
            "twiddle_n": reference.K, "dir": str(VECDIR.relative_to(ROOT))}
    print(f"[vectors] wrote top_in(24) top_gold({info['top_gold']}) "
          f"twiddle({reference.K}) -> {info['dir']}")
    return info


if __name__ == "__main__":
    emit()
