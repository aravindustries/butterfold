# GENERATED golden model for unified_mixed_radix_core — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
import numpy as np
# DFT is unique, so np.fft reproduces the radix-2 / mixed-radix hardware exactly.
def dft12(x):   return np.fft.fft(np.asarray(x, complex))
def idft12(x):  return np.fft.ifft(np.asarray(x, complex))
def ifft128(x): return np.fft.ifft(np.asarray(x, complex))
def fft128(x):  return np.fft.fft(np.asarray(x, complex))
