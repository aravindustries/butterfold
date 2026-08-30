# 12 — Functional regression (ACH validation)

**PASS**

Foundry-SRAM Icarus FINAL-PIN suite, `TX_BYTE_INTERVAL=10`.

`FINAL-PIN OVERALL RESULT: PASS`

ECHO, MAGIC, SRAM R/W, FFT2, IFFT2, FFT3, DFT12 (`0x45`), FFT64 (`0x41`),
IFFT64 (`0x42`), OFDM RX `0x46`/`0x47`, OFDM TX `0x48`/`0x49`.

`RESET-RECOVERY RESULT: PASS`

RTL and golden models were not modified.

Evidence: [interval10_regression.log](evidence/functional/interval10_regression.log),
[reset_recovery.log](evidence/functional/reset_recovery.log)
