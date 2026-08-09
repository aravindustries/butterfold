# GENERATED golden model for twiddle_source — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
import numpy as np
def twiddle_rom(n, scale=127.0, conjugate=False):
    """Quantized Q1.7 twiddle LUT for an n-point transform; conjugate for inverse."""
    idx = np.arange(n); tw = np.exp(-2j*np.pi*idx/n)
    if conjugate: tw = np.conj(tw)
    re = np.clip(np.rint(tw.real*scale), -128, 127).astype(int).tolist()
    im = np.clip(np.rint(tw.imag*scale), -128, 127).astype(int).tolist()
    return re, im
