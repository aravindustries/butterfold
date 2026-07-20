# GENERATED golden model for scheduler_addr_control — standalone numpy reference.
# Source of truth: butterfold_module_io.md.  K=12 M=128 CP=9 START=58 Q1.7(scale127).
# The scheduler sequences the datapath. Its golden is the ordered daisy chain:
# each stage is (module, function) applied to the running data.
def tx_stages():
    return [("fdiq_io_adapter","unpack"), ("unified_mixed_radix_core","dft12"),
            ("subcarrier_map_extract","map_tx"), ("unified_mixed_radix_core","ifft128"),
            ("tdiq_io_adapter_cp","cp_insert"), ("tdiq_io_adapter_cp","pack")]
def rx_stages():
    return [("tdiq_io_adapter_cp","unpack"), ("tdiq_io_adapter_cp","cp_remove"),
            ("unified_mixed_radix_core","fft128"), ("subcarrier_map_extract","extract_rx"),
            ("unified_mixed_radix_core","idft12"), ("fdiq_io_adapter","pack")]
