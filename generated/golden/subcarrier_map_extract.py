# GENERATED golden model for subcarrier_map_extract — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
import numpy as np
K, M, START = 12, 128, 58
def map_tx(spread):
    g = np.zeros(M, complex); g[START:START+K] = np.asarray(spread); return g
def extract_rx(spectrum):
    return np.asarray(spectrum)[START:START+K].copy()
