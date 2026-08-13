# ButterFold GF180 SRAM integration

This document describes the authoritative two-SRAM production architecture.
Historical three-SRAM measurements and the selection rationale remain in
`two_sram_experiment/REPORT.md` and `two_sram_experiment/TDD_WORKLOAD_STUDY.md`.

## Architecture

ButterFold retains a signed 16-bit, seven-fractional-bit datapath, one shared
mixed-radix butterfly, and one simultaneous scalar multiplier.

```text
                     +---------------------+
FDIQ -> DFT/map ---->|                     |
                     | shared 2 x 256x8    |
TDIQ -> CP removal ->| symbol/FFT scratch  |
                     |                     |
FDIQ <- extract/FFT <|                     |
                     |                     |
TDIQ <- CP/body <-----|                     |
                     +----------+----------+
                                |
                         shared butterfly
```

The two `gf180mcu_fd_ip_sram__sram256x8m8wm1` macros operate in parallel as
one 256x16 synchronous single physical port. Complex sample `n` occupies:

```text
address 2n   = I[15:0]
address 2n+1 = Q[15:0]
```

There is no 512x8 waveform SRAM. RX discards the 9/10-sample normal CP and
writes the 128 body samples directly to bit-reversed scratch addresses. TX
maps and transforms in scratch, then reads samples 119..127 or 118..127 for
short/long CP followed by samples 0..127.

The FFT engine performs 448 radix-2 butterflies at a steady eight-cycle
cadence; FFT128/IFFT128 take 3,601 compute cycles.

## External scheduling contract

Active waveform bytes retain their 16-clock cadence at a 61.44-MHz core clock.
The separate production constraint is symbol allocation density:

```text
maximum sustained grid-aligned allocation: 50%
RX -> RX: next start +2 symbol positions
TX -> TX: next start +2 symbol positions
RX -> TX: next start +3 symbol positions
TX -> RX: next start +1 symbol position (adjacent legal)
```

Measured fluid capacities are 54.38--54.56% RX and 52.79--52.97% TX. Slot/TDD
scheduling remains external.

## Commands

| Opcode | Command | Input after opcode | Output |
|---:|---|---:|---:|
| 0x40 | FFT2 | 4 bytes | 2 diagnostic records |
| 0x41 | FFT128 | 256 bytes | 128 diagnostic records |
| 0x42 | IFFT128 | 256 bytes | 128 diagnostic records |
| 0x43 | IFFT2 | 4 bytes | 2 diagnostic records |
| 0x44 | FFT3 | 6 bytes | 3 diagnostic records |
| 0x45 | DFT12 | 24 bytes | 12 diagnostic records |
| 0x46 | OFDM_RX short normal CP | 274 bytes | 24 FDIQ bytes |
| 0x47 | OFDM_RX long normal CP | 276 bytes | 24 FDIQ bytes |
| 0x48 | OFDM_TX short normal CP | 24 bytes | 274 TDIQ bytes |
| 0x49 | OFDM_TX long normal CP | 24 bytes | 276 TDIQ bytes |
| 0x4A | ECHO | 1 byte | same byte |
| 0x4B | MAGIC | 0 bytes | `42 46 4c 44` (`BFLD`) |
| 0x4C | SRAM READ | 8-bit half-word address | data high, data low |
| 0x4D | SRAM WRITE | address, data high, data low | ACK `ac` |

SRAM debug commands are accepted only while the transform engine is idle. The
logical debug address is the physical 0..255 half-word address. Backpressure is
provided only through the frozen `din_ready_o` interface.

## Functional foundry-model regression

```sh
make -f Makefile.gf180_sram behavioral

make -f Makefile.gf180_sram foundry \
  SRAM256_MODEL=/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_ip_sram/verilog/gf180mcu_fd_ip_sram__sram256x8m8wm1.v
```

The production foundry target compiles only the official 256x8 model. Do not
enable Icarus `-gspecify`; physical timing comes from Liberty/OpenSTA.
