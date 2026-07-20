# GENERATED golden model for tdiq_io_adapter_cp — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
import numpy as np
CP, M = 9, 128
def cp_insert(t, cp=CP): t = np.asarray(t, complex); return np.concatenate([t[-cp:], t])
def cp_remove(t, cp=CP): t = np.asarray(t, complex); return t[cp:cp+M]
def _q(v, scale=127.0): return int(np.clip(np.rint(v*scale), -128, 127))
def pack(t):
    out = []
    for c in np.asarray(t, complex): out += [_q(c.real), _q(c.imag)]
    return np.array(out, dtype=np.int8)
def unpack(iq_bytes):
    b = np.asarray(iq_bytes, dtype=np.int8)
    return b[0::2].astype(float)/127.0 + 1j*b[1::2].astype(float)/127.0
