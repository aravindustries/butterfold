BUTTERFOLD MODULE BREAKDOWN
===========================

Internal sample format:
- Complex sample: 16 bits total
- I[7:0] and Q[7:0], signed Q1.7
- Recommended packing: {I[7:0], Q[7:0]}
- Streaming transfers occur when valid = 1 and ready = 1
- All modules use one shared synchronous clock domain

Common signals for all modules:
- clk                 Input   Shared chip clock
- rst_n               Input   Active-low reset


1. FDIQ I/O ADAPTER
===================

Function:
- Interfaces ButterFold to external frequency-domain I/Q data.
- Packs external 8-bit interleaved I/Q bytes into 16-bit complex samples.
- Unpacks internal 16-bit complex samples into external interleaved I/Q bytes.
- Accepts 12 QAM samples for TX.
- Outputs 12 extracted subcarrier samples for RX.
- Tracks I/Q byte alignment and block boundaries.

External input interface:
- fdiq_in_data[7:0]       Input    Interleaved I/Q input byte
- fdiq_in_valid           Input    Input byte is valid
- fdiq_in_ready           Output   Adapter can accept input byte

External output interface:
- fdiq_out_data[7:0]      Output   Interleaved I/Q output byte
- fdiq_out_valid          Output   Output byte is valid
- fdiq_out_ready          Input    External receiver can accept output byte

Internal complex-sample interface:
- fd_in_data[15:0]        Output   Packed complex sample toward DFT/map path
- fd_in_valid             Output   Internal input sample is valid
- fd_in_ready             Input    Downstream block can accept sample
- fd_in_last              Output   Last sample in 12-sample block

- fd_out_data[15:0]       Input    Packed complex sample from extraction path
- fd_out_valid            Input    Internal output sample is valid
- fd_out_ready            Output   Adapter can accept sample
- fd_out_last             Input    Last sample in 12-sample block

Control and status:
- start                   Input    Begin FDIQ transaction
- direction               Input    0 = receive FDIQ, 1 = transmit FDIQ
- busy                    Output   Adapter is active
- done                    Output   Transaction completed
- iq_alignment_error      Output   Incorrect or incomplete I/Q byte pair


2. UNIFIED MIXED-RADIX CORE
===========================

Function:
- Performs the arithmetic used by:
  - 12-point forward DFT
  - 128-point forward FFT
  - 128-point inverse FFT
- Contains the radix-2 butterfly.
- Contains the radix-3 or 3-point kernel.
- Contains the shared complex multiplier.
- Contains widened internal arithmetic, scaling, rounding, and saturation.
- Reads and writes transform scratch memory.
- Executes micro-operations issued by the scheduler.
- Does not independently schedule complete transforms.

Scheduler micro-operation interface:
- uop_valid              Input    Micro-operation command is valid
- uop_ready              Output   Core can accept a micro-operation
- uop_radix[1:0]         Input    Select radix-2 or radix-3 operation
- uop_inverse            Input    0 = forward operation, 1 = inverse operation
- uop_scale_shift[2:0]   Input    Right-shift amount after operation
- uop_last               Input    Final micro-operation of current transform

Source addresses:
- src_addr_0[6:0]        Input    First source scratch-memory address
- src_addr_1[6:0]        Input    Second source scratch-memory address
- src_addr_2[6:0]        Input    Third source address for radix-3

Destination addresses:
- dst_addr_0[6:0]        Input    First destination scratch-memory address
- dst_addr_1[6:0]        Input    Second destination scratch-memory address
- dst_addr_2[6:0]        Input    Third destination address for radix-3

Twiddle input:
- twiddle_re[7:0]        Input    Signed Q1.7 real twiddle component
- twiddle_im[7:0]        Input    Signed Q1.7 imaginary twiddle component
- twiddle_valid          Input    Twiddle value is valid

External scratch-memory load interface:
- load_addr[6:0]         Input    Address to load
- load_data[15:0]        Input    Packed complex sample to store
- load_valid             Input    Load request is valid
- load_ready             Output   Core can accept load request

External scratch-memory read interface:
- read_addr[6:0]         Input    Address to read
- read_req               Input    Read request
- read_data[15:0]        Output   Packed complex sample read from memory
- read_valid             Output   Read data is valid

Status:
- uop_done               Output   Current micro-operation completed
- overflow               Output   Arithmetic overflow detected
- saturation_occurred    Output   One or more values were saturated


3. TWIDDLE SOURCE
=================

Function:
- Stores or generates quantized twiddle factors.
- Supplies one packed complex twiddle to the transform core.
- Supports conjugation for inverse transforms.
- Uses a fixed, documented lookup latency.

Interface:
- tw_req                 Input    Twiddle lookup request
- tw_addr[6:0]           Input    Twiddle lookup address
- tw_conjugate           Input    Conjugate twiddle for inverse operation
- tw_re[7:0]             Output   Signed Q1.7 real twiddle component
- tw_im[7:0]             Output   Signed Q1.7 imaginary twiddle component
- tw_valid               Output   Twiddle output is valid


4. SCHEDULER + ADDRESS CONTROL
==============================

Function:
- Controls the complete ButterFold datapath.
- Sequences 12-point DFT, 128-point FFT, and 128-point IFFT operations.
- Generates transform stages, memory addresses, and twiddle addresses.
- Controls subcarrier mapping and extraction.
- Controls CP insertion and removal.
- Selects ping-pong buffer banks.
- Tracks operation latency and reports completion or errors.

Command interface:
- cmd_valid              Input    New command is valid
- cmd_ready              Output   Scheduler can accept command
- cmd_op[2:0]            Input    Requested operation
- long_cp                Input    0 = 9-sample CP, 1 = 10-sample CP

Suggested command encoding:
- 000                    DFT-12 only
- 001                    FFT-128 only
- 010                    IFFT-128 only
- 011                    Complete TX chain
- 100                    Complete RX chain
- 101                    CP-only test
- 110                    Digital loopback test
- 111                    Reserved/diagnostic

Transform-core control:
- uop_valid              Output   Micro-operation command is valid
- uop_ready              Input    Transform core can accept command
- uop_radix[1:0]         Output   Radix selection
- uop_inverse            Output   Forward/inverse selection
- uop_scale_shift[2:0]   Output   Fixed-point scaling control
- uop_last               Output   Final micro-operation indicator

Transform addresses:
- src_addr_0[6:0]        Output   First source address
- src_addr_1[6:0]        Output   Second source address
- src_addr_2[6:0]        Output   Third source address
- dst_addr_0[6:0]        Output   First destination address
- dst_addr_1[6:0]        Output   Second destination address
- dst_addr_2[6:0]        Output   Third destination address

Twiddle-source control:
- tw_req                 Output   Twiddle lookup request
- tw_addr[6:0]           Output   Twiddle address
- tw_conjugate           Output   Twiddle conjugation control
- tw_valid               Input    Twiddle is available

Map/extract control:
- map_start              Output   Begin map or extract operation
- map_direction          Output   0 = extract, 1 = map
- first_subcarrier[6:0]  Output   First active subcarrier index
- map_done               Input    Map/extract operation completed

CP/TDIQ control:
- cp_start               Output   Begin CP operation
- cp_insert              Output   0 = remove CP, 1 = insert CP
- cp_len[3:0]            Output   CP length in complex samples
- cp_done                Input    CP operation completed

Buffer control:
- input_bank_select      Output   Select input ping-pong bank
- output_bank_select     Output   Select output ping-pong bank

Global status:
- busy                   Output   Chip operation is active
- done                   Output   Whole command completed
- error                  Output   Control or sequencing error
- cycle_count[15:0]      Output   Number of clock cycles used


5. SUBCARRIER MAP / EXTRACT
===========================

Function:
- TX mapping:
  - Accepts 12 DFT output samples.
  - Places them into selected bins of a 128-bin frequency grid.
  - Writes zeros into unused bins.
- RX extraction:
  - Reads the selected 12 bins from a 128-bin FFT result.
  - Outputs the recovered complex subcarrier samples.

Control:
- start                  Input    Begin operation
- map_not_extract        Input    1 = map, 0 = extract
- first_subcarrier[6:0]  Input    First active bin in 128-bin grid
- busy                   Output   Operation is active
- done                   Output   Operation completed
- config_error           Output   Invalid subcarrier range or configuration

Streaming interface:
- in_data[15:0]          Input    Packed complex input sample
- in_valid               Input    Input sample is valid
- in_ready               Output   Module can accept input sample
- in_last                Input    Last input sample

- out_data[15:0]         Output   Packed complex output sample
- out_valid              Output   Output sample is valid
- out_ready              Input    Downstream block can accept output
- out_last               Output   Last output sample

Transform-memory interface:
- mem_addr[6:0]          Output   Transform-memory address
- mem_write              Output   Memory write enable
- mem_wdata[15:0]        Output   Complex data written to memory
- mem_rdata[15:0]        Input    Complex data read from memory
- mem_rvalid             Input    Read data is valid


6. TDIQ I/O ADAPTER WITH CP
===========================

Function:
- Interfaces ButterFold to external time-domain I/Q data.
- Packs external 8-bit interleaved I/Q bytes into 16-bit complex samples.
- Unpacks internal complex samples into interleaved output bytes.
- Removes the CP before the RX FFT.
- Inserts the CP after the TX IFFT.
- Supports 9-sample and 10-sample CP lengths.
- Controls time-domain ping-pong symbol buffers.
- Tracks symbol length, CP length, and I/Q byte alignment.

External input interface:
- tdiq_in_data[7:0]      Input    Interleaved time-domain I/Q input byte
- tdiq_in_valid          Input    Input byte is valid
- tdiq_in_ready          Output   Adapter can accept input byte

External output interface:
- tdiq_out_data[7:0]     Output   Interleaved time-domain I/Q output byte
- tdiq_out_valid         Output   Output byte is valid
- tdiq_out_ready         Input    External receiver can accept output byte

CP control:
- cp_start               Input    Begin CP insertion/removal
- cp_insert              Input    0 = remove CP, 1 = insert CP
- cp_len[3:0]            Input    CP length in complex samples

RX output toward transform memory:
- rx_symbol_data[15:0]   Output   Useful time-domain complex sample
- rx_symbol_valid        Output   RX sample is valid
- rx_symbol_ready        Input    Transform-memory path can accept sample
- rx_symbol_last         Output   Last of 128 useful RX samples

TX transform-memory read interface:
- tx_symbol_rd_addr[6:0] Output   Requested IFFT output address
- tx_symbol_rd_req       Output   Transform-memory read request
- tx_symbol_rd_data[15:0] Input   Complex IFFT output sample
- tx_symbol_rd_valid     Input    Requested sample is valid

Status:
- busy                   Output   Adapter/CP operation is active
- done                   Output   Time-domain transaction completed
- cp_error               Output   Invalid CP configuration
- sample_count_error     Output   Incorrect number of samples received
- iq_alignment_error     Output   Incorrect or incomplete I/Q byte pair


TOP-LEVEL CHIP INTERFACE
========================

- clk_i                  Input    Shared chip clock
- rst_ni                 Input    Active-low reset

- din[7:0]               Input    Command bytes and interleaved input I/Q
- din_valid_i            Input    Input byte is valid
- din_ready_o            Output   Chip can accept input byte

- dout[7:0]              Output   Status bytes and interleaved output I/Q
- dout_valid_o           Output   Output byte is valid
- dout_ready_i           Input    External receiver can accept output byte

- done_irq_o             Output   Current transaction has completed

Optional scan/test:
- scan_en_i              Input    Enable scan mode
- scan_in_i              Input    Scan-chain input
- scan_out_o             Output   Scan-chain output


NUMERIC CONTRACT (functional verification)
==========================================

This section defines what "correct" means numerically, so RTL can be checked
against the Python golden model (butterfold_sim / golden/reference.py).

Transform math (frozen):
- K = 12 subcarriers, M = 128 FFT/IFFT points, CP = 9 samples (normal), 10 (long).
- Subcarrier mapping is CENTERED: first active bin START = (M - K) / 2 = 58,
  i.e. the 12 spread samples occupy bins 58..69; all other bins are zero.
- TX chain: DFT-12 (forward) -> centered map -> IFFT-128 -> CP insert.
- RX chain: CP remove -> FFT-128 -> extract bins 58..69 -> IDFT-12 (inverse).

Fixed-point:
- External I/Q and inter-module complex samples are signed Q1.7 (int8), packed
  {I[7:0], Q[7:0]}. Byte streams are interleaved I,Q,I,Q,...
- The unified core carries WIDENED internal precision (do not clip intermediate
  transform results to 8 bits); only the final time-domain output going to the
  TDIQ adapter is quantized to Q1.7 with saturation to [-128, 127].
- Internal transform sample format is PINNED to signed 16-bit Q5.11 (5 integer
  bits avoid mid-FFT saturation, 11 fractional bits give precision). Verified in
  golden/fixedchain.py: this format yields EVM 0.28% vs the float golden (Q5.9/
  14-bit gives 1.29%; formats with <5 integer bits saturate and fail). The DIT
  IFFT's 1/128 is applied as one round-and->>1 per stage across the 7 stages.
- Forward transforms are unscaled; the 128-pt IFFT includes the 1/128 scale
  (matching np.fft.ifft). One TX symbol => M + CP = 137 complex samples => 274
  interleaved output bytes.

Top command protocol (so the chip is drivable byte-by-byte):
- The FIRST input byte on din is the command: 0x03 = run TX chain, 0x04 = run RX
  chain (low 3 bits match the scheduler cmd_op encoding).
- The following input bytes are the interleaved I/Q payload. TX: command + 24
  payload bytes (12 complex). RX: command + 274 payload bytes (137 complex).
- All input transfers use din_valid_i / din_ready_o handshake.
- The result streams out on dout with dout_valid_o / dout_ready_i: TX emits 274
  bytes, RX emits 24 bytes. done_irq_o pulses when the transaction completes.

Acceptance (authoritative):
- Feed a 24-byte TX input (12 complex Q1.7 samples) to the chip; capture the
  274-byte output. Compare to the golden TX output.
- PASS gate: EVM <= 2.0% versus the golden (this is the authoritative criterion).
- Also REPORT the bit-exact int8 mismatch count (informational, not a gate).
- Per-module: each module's testbench drives the input its Python golden model
  (generated/golden/<module>.py) received and checks the RTL output against that
  model's output (handshake/valid-driven sampling; EVM<=2% where complex).

