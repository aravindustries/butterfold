// ButterFold Reference Implementation
// 12-point DFT (3x4 mixed-radix) + 128-point FFT (radix-2) folded transform core
// TX: QAM symbols (k=12) -> DFT -> OFDM mapping -> IFFT -> CP insertion -> time-domain waveform
// RX: time-domain waveform -> CP removal -> FFT -> active subcarrier extraction -> IDFT -> QAM symbols
//
// All fixed-point int8 (±127), no floating-point.
// Block-streaming: one byte per cycle on din/dout, dout_valid asserted per byte.

module butterfold_top (
  input  wire clk,
  input  wire rst_n,
  input  wire mode,           // 0 = TX, 1 = RX
  input  wire [7:0] din,
  input  wire din_valid,
  output wire [7:0] dout,
  output wire dout_valid,
  output wire busy,
  output wire done
);

  // =========================================================================
  // FSM States
  // =========================================================================
  localparam STATE_IDLE           = 4'd0;
  localparam STATE_INPUT_ACCUM    = 4'd1;
  localparam STATE_DFT_12         = 4'd2;
  localparam STATE_MAP_128        = 4'd3;
  localparam STATE_IFFT_128       = 4'd4;
  localparam STATE_CP_INSERT      = 4'd5;
  localparam STATE_OUTPUT_TX      = 4'd6;
  localparam STATE_CP_REMOVE      = 4'd7;
  localparam STATE_FFT_128        = 4'd8;
  localparam STATE_SUBCARRIER_EXT = 4'd9;
  localparam STATE_IDFT_12        = 4'd10;
  localparam STATE_OUTPUT_RX      = 4'd11;

  reg [3:0] state, next_state;

  // =========================================================================
  // Internal storage (block RAM simulation with registers)
  // =========================================================================
  // TX input: 24 bytes (12 complex samples, interleaved I/Q, int8 each)
  reg signed [7:0] tx_input [0:23];

  // After 12-point DFT: 12 complex bins
  reg signed [15:0] dft_out_real [0:11];
  reg signed [15:0] dft_out_imag [0:11];

  // After mapping to 128-point grid: 128 complex bins (zero-padded)
  reg signed [15:0] ofdm_bins_real [0:127];
  reg signed [15:0] ofdm_bins_imag [0:127];

  // After 128-point IFFT: 128 time-domain samples
  reg signed [15:0] ifft_out_real [0:127];
  reg signed [15:0] ifft_out_imag [0:127];

  // After CP insertion: 137 time-domain samples (128 + 9 CP)
  reg signed [15:0] tx_out_real [0:136];
  reg signed [15:0] tx_out_imag [0:136];

  // RX path storage
  reg signed [15:0] rx_input_real [0:127];
  reg signed [15:0] rx_input_imag [0:127];

  // After 128-point FFT: 128 frequency bins
  reg signed [15:0] fft_out_real [0:127];
  reg signed [15:0] fft_out_imag [0:127];

  // After subcarrier extraction: 12 active bins
  reg signed [15:0] extracted_real [0:11];
  reg signed [15:0] extracted_imag [0:11];

  // After 12-point IDFT: 12 output symbols
  reg signed [15:0] idft_out_real [0:11];
  reg signed [15:0] idft_out_imag [0:11];

  // =========================================================================
  // Control signals
  // =========================================================================
  reg [7:0] byte_counter;
  reg [7:0] output_counter;
  wire tx_mode = (mode == 1'b0);
  wire rx_mode = (mode == 1'b1);

  // =========================================================================
  // Output assignment
  // =========================================================================
  assign busy = (state != STATE_IDLE);
  assign done = (state != STATE_IDLE) && (next_state == STATE_IDLE);

  // Multiplex output based on current state
  reg [7:0] dout_byte;
  reg dout_valid_reg;
  assign dout = dout_byte;
  assign dout_valid = dout_valid_reg;

  // =========================================================================
  // Main FSM
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      byte_counter <= 8'd0;
      output_counter <= 8'd0;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;

    case (state)
      STATE_IDLE: begin
        if (din_valid) begin
          next_state = STATE_INPUT_ACCUM;
        end
      end

      STATE_INPUT_ACCUM: begin
        // Wait for full input block (24 bytes for TX, 274 for RX)
        if (tx_mode && byte_counter == 8'd23) begin
          next_state = STATE_DFT_12;
        end else if (rx_mode && byte_counter == 8'd273) begin
          next_state = STATE_CP_REMOVE;
        end else if (din_valid) begin
          // Keep accumulating
        end
      end

      STATE_DFT_12: begin
        next_state = STATE_MAP_128;
      end

      STATE_MAP_128: begin
        next_state = STATE_IFFT_128;
      end

      STATE_IFFT_128: begin
        next_state = STATE_CP_INSERT;
      end

      STATE_CP_INSERT: begin
        next_state = STATE_OUTPUT_TX;
      end

      STATE_OUTPUT_TX: begin
        if (output_counter == 8'd255) begin  // 274 bytes output done (simplified counter)
          next_state = STATE_IDLE;
        end
      end

      STATE_CP_REMOVE: begin
        next_state = STATE_FFT_128;
      end

      STATE_FFT_128: begin
        next_state = STATE_SUBCARRIER_EXT;
      end

      STATE_SUBCARRIER_EXT: begin
        next_state = STATE_IDFT_12;
      end

      STATE_IDFT_12: begin
        next_state = STATE_OUTPUT_RX;
      end

      STATE_OUTPUT_RX: begin
        if (output_counter == 8'd23) begin  // 24 bytes output done
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  // =========================================================================
  // Input accumulation
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_counter <= 8'd0;
    end else if (state == STATE_IDLE) begin
      byte_counter <= 8'd0;
    end else if (state == STATE_INPUT_ACCUM && din_valid) begin
      tx_input[byte_counter] <= din;
      byte_counter <= byte_counter + 1'b1;
    end
  end

  // =========================================================================
  // 12-point DFT (3x4 mixed-radix Cooley-Tukey) - SIMPLIFIED FOR CLARITY
  // Full implementation would use proper butterfly stages.
  // This is a placeholder that does basic FFT-like transform.
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Zero out DFT outputs
      for (int i = 0; i < 12; i = i + 1) begin
        dft_out_real[i] <= 16'sd0;
        dft_out_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_DFT_12) begin
      // Simple DFT: sum all inputs into bin 0, zeros elsewhere
      // Real implementation: use 3-point and 4-point butterflies with twiddles
      // For now, store I/Q in first 12 bins
      for (int k = 0; k < 12; k = k + 1) begin
        dft_out_real[k] <= {tx_input[2*k], 8'sd0};   // I sample, scaled
        dft_out_imag[k] <= {tx_input[2*k+1], 8'sd0}; // Q sample, scaled
      end
    end
  end

  // =========================================================================
  // Map 12-point DFT output to 128-point OFDM grid
  // Place DFT bins 0-11 at grid positions 0-11, zero-pad the rest.
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 128; i = i + 1) begin
        ofdm_bins_real[i] <= 16'sd0;
        ofdm_bins_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_MAP_128) begin
      // Copy DFT outputs to positions 0-11
      for (int i = 0; i < 12; i = i + 1) begin
        ofdm_bins_real[i] <= dft_out_real[i];
        ofdm_bins_imag[i] <= dft_out_imag[i];
      end
      // Zero-pad positions 12-127
      for (int i = 12; i < 128; i = i + 1) begin
        ofdm_bins_real[i] <= 16'sd0;
        ofdm_bins_imag[i] <= 16'sd0;
      end
    end
  end

  // =========================================================================
  // 128-point IFFT (radix-2 DIT) - SIMPLIFIED
  // Real implementation: 7 butterfly stages, bit-reversed addressing.
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 128; i = i + 1) begin
        ifft_out_real[i] <= 16'sd0;
        ifft_out_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_IFFT_128) begin
      // For reference: just copy (real IFFT uses twiddle factors and butterflies)
      for (int i = 0; i < 128; i = i + 1) begin
        ifft_out_real[i] <= ofdm_bins_real[i];
        ifft_out_imag[i] <= ofdm_bins_imag[i];
      end
    end
  end

  // =========================================================================
  // Cyclic Prefix Insertion (prepend last 9 samples)
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 137; i = i + 1) begin
        tx_out_real[i] <= 16'sd0;
        tx_out_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_CP_INSERT) begin
      // CP: copy last 9 samples to front
      for (int i = 0; i < 9; i = i + 1) begin
        tx_out_real[i]     <= ifft_out_real[128 - 9 + i];
        tx_out_imag[i]     <= ifft_out_imag[128 - 9 + i];
      end
      // Then main block
      for (int i = 9; i < 137; i = i + 1) begin
        tx_out_real[i]     <= ifft_out_real[i - 9];
        tx_out_imag[i]     <= ifft_out_imag[i - 9];
      end
    end
  end

  // =========================================================================
  // TX Output (serialize 274 bytes)
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dout_byte <= 8'sd0;
      dout_valid_reg <= 1'b0;
      output_counter <= 8'd0;
    end else if (state == STATE_OUTPUT_TX) begin
      dout_valid_reg <= 1'b1;
      // Serialize: even bytes = real, odd bytes = imag
      if (output_counter < 8'd137) begin
        if (output_counter[0] == 1'b0) begin
          // Even: real part of sample (output_counter / 2)
          dout_byte <= tx_out_real[output_counter >> 1][7:0];
        end else begin
          // Odd: imag part of same sample
          dout_byte <= tx_out_imag[output_counter >> 1][7:0];
        end
      end
      output_counter <= output_counter + 1'b1;
    end else begin
      dout_valid_reg <= 1'b0;
      output_counter <= 8'd0;
    end
  end

  // =========================================================================
  // RX Path: CP Removal
  // Skip first 18 bytes (9 complex CP samples), keep 256 bytes (128 complex)
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 128; i = i + 1) begin
        rx_input_real[i] <= 16'sd0;
        rx_input_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_CP_REMOVE) begin
      // De-serialize from tx_input, skipping CP
      for (int i = 0; i < 128; i = i + 1) begin
        rx_input_real[i] <= {tx_input[18 + 2*i], 8'sd0};       // byte 18+2i
        rx_input_imag[i] <= {tx_input[18 + 2*i + 1], 8'sd0};   // byte 18+2i+1
      end
    end
  end

  // =========================================================================
  // 128-point FFT (radix-2 DIT) - SIMPLIFIED
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 128; i = i + 1) begin
        fft_out_real[i] <= 16'sd0;
        fft_out_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_FFT_128) begin
      // For reference: just copy (real FFT uses twiddle factors and butterflies)
      for (int i = 0; i < 128; i = i + 1) begin
        fft_out_real[i] <= rx_input_real[i];
        fft_out_imag[i] <= rx_input_imag[i];
      end
    end
  end

  // =========================================================================
  // Subcarrier Extraction (extract bins 0-11 from 128-point FFT output)
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 12; i = i + 1) begin
        extracted_real[i] <= 16'sd0;
        extracted_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_SUBCARRIER_EXT) begin
      for (int i = 0; i < 12; i = i + 1) begin
        extracted_real[i] <= fft_out_real[i];
        extracted_imag[i] <= fft_out_imag[i];
      end
    end
  end

  // =========================================================================
  // 12-point IDFT (inverse of TX DFT) - SIMPLIFIED
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 12; i = i + 1) begin
        idft_out_real[i] <= 16'sd0;
        idft_out_imag[i] <= 16'sd0;
      end
    end else if (state == STATE_IDFT_12) begin
      for (int i = 0; i < 12; i = i + 1) begin
        idft_out_real[i] <= extracted_real[i];
        idft_out_imag[i] <= extracted_imag[i];
      end
    end
  end

  // =========================================================================
  // RX Output (serialize 24 bytes)
  // =========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dout_byte <= 8'sd0;
      dout_valid_reg <= 1'b0;
      output_counter <= 8'd0;
    end else if (state == STATE_OUTPUT_RX) begin
      dout_valid_reg <= 1'b1;
      // Serialize: even bytes = real, odd bytes = imag
      if (output_counter < 8'd24) begin
        if (output_counter[0] == 1'b0) begin
          // Even: real part
          dout_byte <= idft_out_real[output_counter >> 1][7:0];
        end else begin
          // Odd: imag part
          dout_byte <= idft_out_imag[output_counter >> 1][7:0];
        end
      end
      output_counter <= output_counter + 1'b1;
    end else begin
      dout_valid_reg <= 1'b0;
      output_counter <= 8'd0;
    end
  end

endmodule
