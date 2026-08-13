# ButterFold OFDM_RX integration

This revision adds two OFDM receive commands to the existing standalone transform scheduler:

| Command | Operation |
|---|---|
| `0x40` | FFT2 |
| `0x41` | FFT128 |
| `0x42` | IFFT128 |
| `0x43` | IFFT2 |
| `0x44` | FFT3 |
| `0x45` | DFT12 |
| `0x46` | OFDM_RX, 9-sample CP |
| `0x47` | OFDM_RX, 10-sample CP |

## OFDM_RX request format

After command `0x46`, send 9 CP complex samples followed by 128 useful complex samples. After command `0x47`, send 10 CP complex samples followed by 128 useful samples. Every complex sample is sent as an 8-bit signed Q1.7 I byte followed by an 8-bit signed Q1.7 Q byte.

No configuration byte is used.

## OFDM_RX datapath

```text
8-bit interleaved TDIQ
    -> tdiq_input_cp_remove
       - reassembles I/Q
       - discards 9 or 10 complex CP samples
       - sign-extends useful samples to signed 16-bit F=7
       - supplies useful sample indices 0..127
    -> bit-reversed writes into the existing 128-sample FFT RAM
    -> existing folded FFT128 engine
       - 7 stages
       - 64 radix-2 butterflies per stage
       - 448 total butterfly operations
    -> natural-order FFT bins retained in FFT RAM
    -> fdiq_output_adapter
       - reads bins 0..127
       - silently saturates each 16-bit F=7 component to 8-bit Q1.7
       - emits I then Q
```

The output is exactly 256 consecutive valid bytes:

```text
X[0].i, X[0].q, X[1].i, X[1].q, ... X[127].i, X[127].q
```

The order is raw natural FFT order. No `fftshift` or subcarrier extraction is applied.

## Output handshake

There is deliberately no `dout_ready_i`. Whenever `dout_valid_o` is asserted, the receiver must accept `dout` on that clock edge. Once an OFDM output burst starts, `dout_valid_o` remains asserted for 256 consecutive cycles.

## Files

- `scheduler_ofdm_rx.sv`: existing transform scheduler plus OFDM command arbitration.
- `tdiq_input_cp_remove.sv`: interleaved TDIQ input and CP-removal adapter.
- `fdiq_output_adapter.sv`: natural-order FDIQ byte output adapter with silent saturation.
- `mixed_radix_butterfly.sv`: unchanged radix-2/radix-3 arithmetic core.
- `scheduler_ofdm_rx_tb.sv`: self-checking normal/extended-CP OFDM testbench.
- `scheduler_dft12_tb.sv`: previous standalone-mode regression testbench.
- `gen_ofdm_rx_vectors.py`: bit-accurate OFDM golden-vector generator.
- `gen_dft12_vectors.py`: existing standalone-mode golden generator.

## Verification model

The OFDM golden model does not use rounded `numpy.fft` values for pass/fail. It reproduces the RTL schedule and arithmetic:

- natural input written to bit-reversed RAM locations;
- seven iterative radix-2 DIT stages;
- Q1.7 twiddle ROM;
- exact-unity `W=-1`, `x1=-x1` proxy;
- 8x17 fixed-point complex multiplication;
- arithmetic right shift by 7 after each complex product;
- 16-bit wrapping between butterflies;
- final silent clamp to `[-128, 127]`.

The CP values are randomized independently and never enter the FFT model, so the test detects incorrect CP removal.

## Run OFDM_RX verification

```bash
python3 gen_ofdm_rx_vectors.py

iverilog -g2012 -Wall \
    -o sim_ofdm.out \
    scheduler_ofdm_rx_tb.sv \
    scheduler_ofdm_rx.sv \
    tdiq_input_cp_remove.sv \
    fdiq_output_adapter.sv \
    mixed_radix_butterfly.sv

vvp sim_ofdm.out
```

## Run the previous standalone regression against the updated scheduler

```bash
python3 gen_dft12_vectors.py

iverilog -g2012 -Wall \
    -o sim_standalone.out \
    scheduler_dft12_tb.sv \
    scheduler_ofdm_rx.sv \
    tdiq_input_cp_remove.sv \
    fdiq_output_adapter.sv \
    mixed_radix_butterfly.sv

vvp sim_standalone.out
```

The updated scheduler retains the parallel standalone result ports for regression and internal integration. The new `dout` interface is used by the two OFDM_RX modes.
