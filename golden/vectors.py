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
import json, pathlib
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


def _write_stage_json(path: pathlib.Path, arr) -> None:
    a = np.asarray(arr, complex)
    path.write_text(json.dumps([[float(v.real), float(v.imag)] for v in a]), encoding="utf-8")


def emit(seed: int = 42) -> dict:
    VECDIR.mkdir(parents=True, exist_ok=True)
    in_bytes = reference.random_input_bytes(seed)
    tx       = reference.tx_reference(in_bytes)
    _write_bytes(VECDIR / "top_in.hex",   in_bytes)
    _write_bytes(VECDIR / "top_gold.hex", tx["out_bytes"])

    # Per-stage golden (float) so the agent can localize WHERE the RTL breaks:
    # after DFT-12, after subcarrier map, after IFFT-128, after CP insertion.
    for name in ("spread", "grid", "time_no_cp", "time_with_cp"):
        _write_stage_json(VECDIR / f"stage_{name}.json", tx[name])

    # twiddle ROMs the transforms need: 12-pt (DFT) and 128-pt (FFT/IFFT).
    for n, tag in ((reference.K, "twiddle"), (reference.M, "tw128")):
        tre, tim = reference.twiddle_rom(n)
        _write_words(VECDIR / f"{tag}_addr.hex", list(range(n)))
        _write_bytes(VECDIR / f"{tag}_re.hex", tre)
        _write_bytes(VECDIR / f"{tag}_im.hex", tim)

    # Reference micro-op schedules (the scheduler must emit these; core executes).
    import schedule
    sched = schedule.emit()

    info = {"seed": seed, "top_in": 24, "top_gold": len(tx["out_bytes"]),
            "stages": ["spread", "grid", "time_no_cp", "time_with_cp"],
            "twiddle_n": [reference.K, reference.M], "schedule": sched,
            "dir": str(VECDIR.relative_to(ROOT))}
    print(f"[vectors] wrote top_in(24) top_gold({info['top_gold']}) + 4 stage vectors "
          f"+ tw ROMs(12,128) -> {info['dir']}")
    return info


if __name__ == "__main__":
    emit()
