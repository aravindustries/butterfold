"""
golden/reference.py — the whole-chain golden model + the per-module reference
stages it decomposes into.

`butterfold_sim/*.py` is the validated numpy DFT-s-OFDM math. Here we:
  1. expose the WHOLE-CHAIN golden (tx_reference / rx_reference), and
  2. define each MODULE's reference stage (fdiq / core / map / cp / ...), so that
     chaining the per-module stages reproduces the whole chain exactly.

This module is the oracle the golden agent's per-module .py files are checked
against (Phase 1), and the source of the input/expected vectors the Verilog
testbenches are checked against (Phase 2).

Frozen params (5G-NR DFT-s-OFDM proof-of-concept, matching butterfold_sim):
  K=12 subcarriers, M=128 FFT, CP=9 (normal), START=(M-K)//2=58, Q1.7 int8 (scale 127).
"""
from __future__ import annotations
import pathlib, sys
import numpy as np

ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))
from butterfold_sim.folded_transforms import mixed_radix_dft, radix2_fft, radix2_ifft
from butterfold_sim.fixed_point import (
    quantize_complex_to_int8, dequantize_complex_from_int8,
    interleave_iq_bytes, deinterleave_iq_bytes, quantized_twiddles,
)

# ── frozen parameters ────────────────────────────────────────────────────────
K, M, CP_NORMAL, CP_LONG = 12, 128, 9, 10
START = (M - K) // 2          # 58
SCALE = 127.0
N_TIME = M + CP_NORMAL        # 137 complex time samples per symbol (with CP)
N_BYTES = 2 * N_TIME          # 274 interleaved I/Q bytes out


# ── per-module reference stages ──────────────────────────────────────────────
# Each function is the numerical "golden" for one module's data path. Chaining
# them in order == the whole chain (proved in the self-test below).

def fdiq_unpack(iq_bytes: np.ndarray) -> np.ndarray:
    """FDIQ adapter (TX in): 24 interleaved I/Q bytes -> 12 complex samples."""
    i, q = deinterleave_iq_bytes(np.asarray(iq_bytes, dtype=np.int8))
    return dequantize_complex_from_int8(i, q, scale=SCALE)

def fdiq_pack(symbols: np.ndarray) -> np.ndarray:
    """FDIQ adapter (RX out): 12 complex samples -> 24 interleaved I/Q bytes."""
    i, q, _ = quantize_complex_to_int8(symbols, scale=SCALE)
    return interleave_iq_bytes(i, q)

def core_dft12(symbols: np.ndarray) -> np.ndarray:
    """Unified mixed-radix core, forward DFT-12 (spreading)."""
    return mixed_radix_dft(np.asarray(symbols), inverse=False)

def core_idft12(spread: np.ndarray) -> np.ndarray:
    """Unified mixed-radix core, inverse DFT-12 (de-spreading, RX)."""
    return mixed_radix_dft(np.asarray(spread), inverse=True)

def core_ifft128(grid: np.ndarray) -> np.ndarray:
    """Unified mixed-radix core, 128-pt IFFT (frequency -> time)."""
    return radix2_ifft(np.asarray(grid))

def core_fft128(time_no_cp: np.ndarray) -> np.ndarray:
    """Unified mixed-radix core, 128-pt FFT (time -> frequency, RX)."""
    return radix2_fft(np.asarray(time_no_cp))

def map_tx(spread: np.ndarray) -> np.ndarray:
    """Subcarrier map (TX): 12 spread symbols -> 128-bin grid, centered at START."""
    grid = np.zeros(M, dtype=np.complex128)
    grid[START:START + K] = spread
    return grid

def extract_rx(spectrum: np.ndarray) -> np.ndarray:
    """Subcarrier extract (RX): 128-bin spectrum -> 12 active bins."""
    return np.asarray(spectrum)[START:START + K].copy()

def tdiq_cp_insert(time_no_cp: np.ndarray, cp_len: int = CP_NORMAL) -> np.ndarray:
    """TDIQ+CP (TX): 128 time samples -> 137 with cyclic prefix prepended."""
    t = np.asarray(time_no_cp)
    return np.concatenate([t[-cp_len:], t])

def tdiq_cp_remove(time_with_cp: np.ndarray, cp_len: int = CP_NORMAL) -> np.ndarray:
    """TDIQ+CP (RX): 137 time samples -> 128 useful (drop the CP)."""
    t = np.asarray(time_with_cp)
    return t[cp_len:cp_len + M]

def tdiq_pack(time_with_cp: np.ndarray) -> np.ndarray:
    """TDIQ adapter (TX out): 137 complex -> 274 interleaved I/Q bytes."""
    i, q, _ = quantize_complex_to_int8(time_with_cp, scale=SCALE)
    return interleave_iq_bytes(i, q)

def tdiq_unpack(iq_bytes: np.ndarray) -> np.ndarray:
    """TDIQ adapter (RX in): 274 interleaved I/Q bytes -> 137 complex."""
    i, q = deinterleave_iq_bytes(np.asarray(iq_bytes, dtype=np.int8))
    return dequantize_complex_from_int8(i, q, scale=SCALE)

def twiddle_rom(n: int) -> tuple[np.ndarray, np.ndarray]:
    """Twiddle source: quantized Q1.7 twiddle LUT for an n-point transform."""
    return quantized_twiddles(n, scale=SCALE)


# per-module stage registry (name -> callable) for the daisy-chain runner
TX_STAGES = ["fdiq_unpack", "core_dft12", "map_tx", "core_ifft128", "tdiq_cp_insert", "tdiq_pack"]
RX_STAGES = ["tdiq_unpack", "tdiq_cp_remove", "core_fft128", "extract_rx", "core_idft12", "fdiq_pack"]


# ── whole-chain golden ───────────────────────────────────────────────────────
def tx_reference(symbol_bytes: np.ndarray) -> dict:
    """Whole TX chain from 24 input I/Q bytes to 274 output I/Q bytes, with every
    intermediate stage captured (the golden the daisy chain must reproduce)."""
    symbols   = fdiq_unpack(symbol_bytes)
    spread    = core_dft12(symbols)
    grid      = map_tx(spread)
    time_nocp = core_ifft128(grid)
    time_cp   = tdiq_cp_insert(time_nocp)
    out_bytes = tdiq_pack(time_cp)
    return {"symbols": symbols, "spread": spread, "grid": grid,
            "time_no_cp": time_nocp, "time_with_cp": time_cp, "out_bytes": out_bytes}

def rx_reference(time_bytes: np.ndarray) -> dict:
    """Whole RX chain from 274 time-domain I/Q bytes back to 24 recovered bytes."""
    time_cp   = tdiq_unpack(time_bytes)
    time_nocp = tdiq_cp_remove(time_cp)
    spectrum  = core_fft128(time_nocp)
    active    = extract_rx(spectrum)
    symbols   = core_idft12(active)
    out_bytes = fdiq_pack(symbols)
    return {"time_with_cp": time_cp, "time_no_cp": time_nocp, "spectrum": spectrum,
            "active": active, "recovered": symbols, "out_bytes": out_bytes}


def random_input_bytes(seed: int = 0) -> np.ndarray:
    """Deterministic 24-byte (12 complex, 16-QAM-ish) TX input for a given seed."""
    rng = np.random.default_rng(seed)
    levels = np.array([-3, -1, 1, 3], dtype=np.float64)
    s = levels[rng.integers(0, 4, 12)] + 1j * levels[rng.integers(0, 4, 12)]
    s /= np.sqrt(np.mean(np.abs(s) ** 2))
    return fdiq_pack(s)


# ── self-test: the decomposition is faithful, and TX→RX loopback recovers ─────
if __name__ == "__main__":
    b = random_input_bytes(42)
    tx = tx_reference(b)
    assert tx["out_bytes"].shape == (N_BYTES,), tx["out_bytes"].shape
    print(f"[reference] TX: 24 bytes -> {tx['out_bytes'].shape[0]} bytes  (137 complex, CP=9)")

    # Pure-float loopback (no int8 byte packing in the middle): must be EXACT,
    # proving DFT/IFFT/map/CP invert cleanly — i.e. the decomposition is faithful.
    t_cp   = tdiq_cp_insert(core_ifft128(map_tx(core_dft12(tx["symbols"]))))
    recov  = core_idft12(extract_rx(core_fft128(tdiq_cp_remove(t_cp))))
    ferr   = np.max(np.abs(recov - tx["symbols"]))
    print(f"[reference] float loopback max symbol error = {ferr:.3e}  (must be ~0)")
    assert ferr < 1e-9, "pure-float loopback must be exact"

    # Byte loopback through int8 packing: recovers within the int8 quantization floor.
    rx  = rx_reference(tx["out_bytes"])
    err = np.max(np.abs(rx["recovered"] - tx["symbols"]))
    print(f"[reference] int8 byte loopback max symbol error = {err:.3e}  (quantization floor)")
    assert err < 0.1, "byte loopback should recover within the int8 floor"

    tre, tim = twiddle_rom(K)
    print(f"[reference] twiddle_rom(12): re[0..3]={tre[:4].tolist()} im[0..3]={tim[:4].tolist()}")
    print("[reference] self-test OK — decomposition faithful, loopback exact")
