## FINAL PIN CONFIGURATION

Total physical terminals: **22** including VDD and VSS.

### INPUT (11)

- rst_n
- clk
- din[7:0]
- din_valid_i

### OUTPUT (9)

- stream_status_o
- dout[7:0]

### POWER (2)

- VDD
- VSS

### stream_status_o protocol

ButterFold is command-driven and half-duplex.

- **Input / command phase:** `stream_status_o` means INPUT READY.
- **Output phase:** `stream_status_o` means OUTPUT VALID.

The external controller knows which phase it is in from the command it issued.
Internal `din_ready` / `dout_valid` are not chip pins.
