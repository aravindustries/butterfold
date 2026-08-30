# 12 — Functional regression (22-pin)

Foundry-SRAM Icarus, `TX_BYTE_INTERVAL=10`, no `-gspecify`.

| Test | Result |
|---|---|
| ECHO / MAGIC / SRAM R/W | PASS |
| FFT2 / IFFT2 / FFT3 / DFT12 | PASS |
| FFT64 (`0x41`) / IFFT64 (`0x42`) | PASS |
| OFDM RX short/long (`0x46`/`0x47`) | PASS |
| OFDM TX short/long (`0x48`/`0x49`) | PASS |
| **FINAL-PIN OVERALL RESULT** | **PASS** |
| RESET-RECOVERY | **PASS** |
| STREAM-STATUS (pin-redesign protocol) | **PASS** |

`stream_status_o` protocol proven in RTL and TB:

- input/command states: READY = internal `din_ready_int`
- output states: VALID = internal `dout_valid_int`
- processing states: both internals 0
- overlap of ready and valid is fatal
- no byte lost / duplicated versus the previous two-pin handshake

Evidence:
[interval10](evidence/functional/interval10_regression.log),
[reset](evidence/functional/reset_recovery.log),
[stream_status](evidence/functional/stream_status.log)
