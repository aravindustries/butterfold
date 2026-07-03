#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  header: context {
    let chapters = query(heading.where(level: 1).before(here(), inclusive: true))

    if chapters.len() != 0 {
      let current_chapter = chapters.last()
      align(right)[
        #if current_chapter.location().page() == here().page() {
          link(<contents>)[Contents]
        } else {
          link(current_chapter.location())[#current_chapter.body]
        }
      ]
    }
  },

  footer: context {
    align(center)[
      #counter(page).display()
    ]
  }
)

#set heading(numbering: "1.")

#align(center)[
  #v(30%)

  #title[Butterfold]
  #v(0.3em)
  #text(size: 12pt)[Folding all the way]

  Track: D (AI / LLM Assisted Circuits)

  Team: D3 - ButterFold

  Process: GF180MCU
]

#pagebreak()

#metadata("contents") <contents>
#outline()

#pagebreak()

= Introduction
This document describes the architecture of the ButterFold mixed-radix OFDM transform engine, designed for the GF180MCU process as part of the Chipathon 2025 Track D. The system implements a folded FFT architecture that reuses a single butterfly unit to perform 12-pt and 128-pt DFTs, targeting 5G NR PHY resource element mapping.

#pagebreak()

= Motivation
5G NR OFDM requires mixed-radix transforms (12-pt and 128-pt) that a conventional FFT accelerator can't handle efficiently. ButterFold's folded architecture replaces ~2x the area with a single butterfly unit and an SRAM buffer.

#pagebreak()

= Theory
== Number Representation
The numbers in the system are represented in ARM's variant of Q1.7 fixed-point format. All arithmetic operates in two's complement; the Q-format only determines the position of the binary point.

#figure(
  image("assets/q1.7-format.drawio.png", width:87%),
  caption: [
    Q1.7 Fixed-Point Format - Bit Breakdown
  ]
)

=== Value Range
The largest positive number representable with 8-bits is $2^(8-1)-1 = 127_(10)$ 2s complement equivalent to $01111111_(2)$.
In Q1.7 notation it would be $0 + 2^(-1) + ... + 2^(-7) = 0.9921875$.

Similarly, the smallest negative number representable is $ -2^(8-1) = -128_(10) $ 2s complement equivalent to $10000000_(2)$.
In Q1.7 notation it would be $2^0 = -1$.

== Operating on Q-formats
Adding or subtracting two Q1.7 numbers is the same as operating on two 8b numbers; the result is 9b and is represented in Q2.7 notation. The result is usually stored as Q1.8 to give additional fractional precision.
Q(m,n)
#figure(
  image("assets/q2.7-format.drawio.png", width:87%),
  caption: [
    Q2.7 Fixed-Point Format - Bit Breakdown
  ]
)
It has a value range of [-2.0, +1.96875].

Multiplying two Q1.7 numbers results in a 16b number in Q2.14. In many cases the MSB is redundant, so it is represented as Q1.15 for additional fractional precision.

Dividing two Q-format numbers is more involved. Dividing two 8b integers generally produces a result <= 8b, but in Q-format the result retains the same fractional bits while gaining additional integer bits to account for the range.

== Converting back to Q1.7 (Quantisation)
The steps are:
- `shift` = `<source fractional bits>` - `<target fractional bits>`
- Add bias of $2^("shift"-1)$
  - this is optional; omitting it creates a bias toward zero
  - bias reduces the error and brings the result closer to the true value
  - only add bias when shift > 0
- If shift >= 0, shift the source number right (>>) by `shift`; \
  otherwise, shift the source number left (<<) by `shift`
- Saturate the value to fit in the target representation's range
  - hardware optimisation
  #table(
    columns: (auto, auto, auto),
    align: horizon,
    table.header(
      [MSB], [MSB-1], [Description]
    ),
    [0], [0], [no overflow],
    [0], [1], [clamp to MAX],
    [1], [0], [clamp to MIN],
    [1], [1], [no overflow]
  )

With Q1.7/Q1.8 arithmetic defined, we can now look at the system that uses it.

#pagebreak()

= Ideal 5G flow
#figure(
  image("assets/5G-PHY-Ideal PHY Data-Flow.drawio.png", width: 86%),
  caption: [
    Folded PHY Top Level Architecture
  ]
)


= Proposed Architecture
#figure(
  image("assets/5G-PHY-Folded PHY Data-Flow.drawio.png", width: 86%),
  caption: [
    Folded PHY Top Level Architecture
  ]
)

== Data Flow
=== Tx
  + The Write Logic stores the input data in SRAM.
  + The 12pt FFT operates on the first 12 elements in SRAM and stores the result back.
  + The Subcarrier Mapper offsets the data in SRAM and assigns zero to all other elements for the 128pt FFT.
  + A 128pt FFT is performed on the first 128 elements of the SRAM.
  + The Read Logic reads out the data at a pace the parallel to serial block can receive, reading the last N_CP elements first and then the first 128 elements.
=== Rx
  + The Write Logic rejects the first N_CP valid input samples and stores the incoming 128-element stream in SRAM.
  + The 128pt IFFT operates on the first 128 elements in SRAM and stores the output back in order.
  + The Subcarrier De-mapper extracts 12 elements from SRAM at a given offset.
  + The Read Logic reads out the data at a pace the parallel to serial block can receive, in the same order as stored.

== FFT
// Top level functionality
The FFT block performs 12-pt FFT, 128-pt FFT, and 128-pt IFFT by serialising the operation through a single butterfly structure. The same structure may be reused for both Radix-2 and Radix-3 computations.
It reads data from memory, computes the transform, and stores the result back in the same memory.
The block operates autonomously from start to end using an internal state machine.

#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],                  [Input],  [],
  [rst],                [Input],  [],
  [mode],                 [Input],  [to switch between 12pt and 128pt FFT mode],
  [inverse],              [Input],  [to produce an IFFT output],
  [start],                [Input],  [Assert for 1 cycle to begin FFT],
  [data_addr[6:0]],       [Output], [],
  [data_in[16:0]],        [Input],  [],
  [data_in_valid],        [Input],  [],
  [twiddle_addr[6:0]],    [Output], [],
  [twiddle_in[16:0]],     [Input],  [],
  [twiddle_in_valid],     [Input],  [],
  [data_out[16:0]],       [Output], [],
  [data_out_valid],       [Output], [],
  [busy],                 [Output], [High while FFT is in progress],
  [almost_done],          [Output], [Final operation indicator],
  [overflow],             [Output], [Debug - Arithmetic overflow occurred],
  [saturation_occurred], [Output], [Debug - One or more values were saturated],
)

// Implementation details
- Using prime factorisation to get the smallest radix core needed for computing a certain FFT.
- Using Q1.8 format for the stored data and logic to quantise the computed data before storing back to memory.
// per case, timing diagrams for how those ports are supposed to interact

== Serial to Parallel
Packs incoming frequency-domain IQ data from 8-bit time-multiplexed I and Q samples into 16-bit words (8b I, 8b Q).

#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],            [Input],  [],
  [rst],            [Input],  [],
  [data_in[7:0]],   [Input],  [],
  [data_in_valid],  [Input],  [data_in_valid of the core],
  [data_out[15:0]], [Output], [],
  [data_out_valid], [Output], [used as wr-enable & addr increment for Write Logic],
)

== Write Logic
Works with the Serial to Parallel block and sets the SRAM address for incoming data.
In Tx mode, 12 samples are stored.
In Rx mode, the block discards N_CP*2 samples (each number is made up of 1 complex & 1 real component) before storing the next 128 samples.

#table(
  columns: (auto, auto),
  align: horizon,
  table.header(
    [Parameter Name], [Description]
  ),
  [N_CP], [Number of initial samples to ignore, in Rx mode],
)
#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],            [Input],  [],
  [rst],            [Input],  [],
  [mode],           [Input],  [],
  [wr],             [Input],  [SRAM write enable],
  [done],           [Output], [],
  [data_addr[6:0]], [Output], [],
)
There is a concern about timing between the SerToPar block asserting valid and the address increment. Care must be taken with the SRAM write enable, since the line transitions every alternate cycle.


== Parallel to Serial
Unpacks 16-bit SRAM data to an 8-bit Time-domain IQ data stream.

#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],            [Input],  [],
  [rst],            [Input],  [],
  [data_in[7:0]],   [Input],  [],
  [data_in_valid],  [Input],  [],
  [data_out[15:0]], [Output], [],
  [data_out_valid], [Output], [data_out_valid of the core],
)

== Read Logic
Works with the Parallel to Serial block and sets the SRAM read address sequence.
In Tx mode, 128 samples are read out.
In Rx mode, the block reads the last N_CP addresses first, then continues with the remaining data to produce 12 samples.

#table(
  columns: (auto, auto),
  align: horizon,
  table.header(
    [Parameter Name], [Description]
  ),
  [N_CP], [Number of initial samples to read, in Rx mode],
)
#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],            [Input],  [],
  [rst],            [Input],  [],
  [mode],           [Input],  [],
  [data_out_valid], [Input],  [Used to know when to activate rd enable of the SRAM],
  [data_addr[6:0]], [Output], [],
  [rd],             [Output], [],
)

== Subcarrier Mapper / De-mapper
In Tx, the block maps the 12pt DFT output into 128 frequency bins.
In Rx, it de-maps 12 samples from 128 frequency bins.

#table(
  columns: (auto, auto),
  align: horizon,
  table.header(
    [Parameter Name], [Description]
  ),
  [OFFSET], [amount to shift the data values by],
)
#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Signal Name], [I/O], [Description]
  ),
  [clk],            [Input],  [],
  [rst],            [Input],  [],
  [mode],           [Input],  [],
  [start],          [Input],  [],
  [busy],           [Output], [],
  [wr_rd_n],        [Output], [When not reading must always be de-asserted],
  [data_in[15:0]],  [Input],  [],
  [data_in_addr[6:0]], [Output], [],
  [data_out_addr[6:0]], [Output], [],
  [data_out[15:0]], [Output], [],
)
In Tx, the block shifts the 12 samples in the SRAM by OFFSET and assigns zero to all other elements in the 128-sample array.
In Rx, the block moves the 12 samples starting at the OFFSET address in the SRAM to address 0.


== Global Controller
It is assumed all components inside the core operate at the same clock frequency. The global controller is responsible for issuing start pulses to each block in the sequence specified by the OFDM-s-DFT 5G standard for signal transformation.
This is necessary because the SRAM is a shared resource; when one block accesses it, it is actively read from and written to, leaving no room for pipelining with other operations.
The operation sequence is described in the Data Flow section.

== Test Logic
Post-silicon validation is critical for confidence in the design under real-world conditions.
Due to a shortage of pins in the padframe, instructing the core to enter a debug state through dedicated pins is not possible. Instead, pre-existing pins are multiplexed for this purpose.
The `mode` and `busy` lines have been identified for this task.

During normal operation, `mode` selects Tx or Rx mode and `busy` goes high once all data for that mode has been loaded (12 samples for Tx, 128 for Rx).
For debugging, `mode` acts as a MOSI line: a processor toggles it to transmit an 8-bit message, and an internal sequence detector decodes these toggles to enter debug mode.
The `busy` line acts as MISO, outputting status messages as test cases are cycled through.

#pagebreak()

= Chipathon Constraints
#figure(
  image("assets/die_breakdown.jpeg", width: 53%),
  caption: [
    Team level allocation of the die
  ]
)

== Budgeting
#figure(
  table(
    columns: (auto, auto, auto),
    align: horizon,
    table.header(
      [Field], [Parameters #sub[(max)]], [Description]
    ),
    [Power], [5V #sym.times 0.5A], [Not confirmed],
    [Area], [3.05mm #sym.times 1.6mm], [Not confirmed],
    [Pins], [22 + 1(VDD) + 1(GND)], [Padframe A],
    [F#sub[clk]], [150MHz], [],
  ),
  caption: [
    Process constraints
  ]
)

#figure(
  image("assets/5G-PHY-Pinout.drawio.png", width: 50%),
  caption: [
    Expected pinout
  ]
)

#figure(
  image("assets/area_budget.png", width: 106%),
  caption: [
    Area budget
  ]
)

LibreLane standard cells operate at 5.0V (confirmed by inspecting the macros in the docker container).
SRAM can also be configured to use 5.0V.

// = Initial Specifications // and constraints
//
// = Physical Estimates
//
// = Pin Mapping
//
// = 

