# GENERATED golden model for fdiq_io_adapter — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
import numpy as np
def _q(v, scale=127.0): return int(np.clip(np.rint(v*scale), -128, 127))
def pack(symbols):
    out = []
    for c in np.asarray(symbols, complex): out += [_q(c.real), _q(c.imag)]
    return np.array(out, dtype=np.int8)
def unpack(iq_bytes):
    b = np.asarray(iq_bytes, dtype=np.int8)
    return b[0::2].astype(float)/127.0 + 1j*b[1::2].astype(float)/127.0
