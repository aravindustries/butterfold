# 3GPP TS 38.211 Specification Extract for ButterFold
**Source:** 3GPP TS 38.211 version 18.6.0 Release 18 (2025-04)  
**Extracted:** 2026-06-13  
**Purpose:** Freeze ButterFold tapeout specs (k=12, m=128) with standards traceability

---

## 1. TRANSFORM DEFINITIONS (Pages 35-60)

### 1.1 DFT-s-OFDM (Transform Precoding)
**3GPP Reference:** Clause 6.3.1.4 (Transform precoding)

**Definition:**
- DFT-s-OFDM applies a **Discrete Fourier Transform (DFT)** to the complex-valued symbols before OFDM modulation
- Also known as **Transform Precoding** or **SC-FDM** (Single-Carrier FDMA)
- When enabled: input symbols are transformed by a DFT, then mapped to subcarriers, then OFDM-modulated

**Transform Precoding Process:**
```
Layer λ = 0, 1, ..., v-1 (v = number of layers)

If transform precoding DISABLED:
  y^(λ)(i) = x^(λ)(i)  [direct pass-through]

If transform precoding ENABLED:
  y^(λ)(i) = DFT[ x^(λ)(i) ]  [apply DFT to input symbols]
```

**Hardware Implication for ButterFold:**
- ButterFold supports **BOTH enabled and disabled** transform precoding
- TX path must include DFT option before subcarrier mapping
- RX path must include IDFT after subcarrier extraction

---

## 2. RESOURCE BLOCK & NUMEROLOGY (Pages 10-20)

### 2.1 Resource Block Definition
**3GPP Reference:** Clause 4.4.2 (Resource grid)

**Fundamental Parameter: k = 12 subcarriers**
- **1 Resource Block (RB) = 12 consecutive subcarriers in frequency domain**
- 1 RB is the **minimum allocation unit** for DFT-s-OFDM in NR uplink
- This is the **key driver for k=12** in ButterFold tapeout configuration

**ButterFold Tapeout Choice:**
```
k = 12 = minimum 1-RB DFT-s-OFDM allocation (FROZEN FOR TAPEOUT)
```

### 2.2 Subcarrier Spacing Numerology
**3GPP Reference:** Clause 4.3.2 (Subcarrier spacing)

| Numerology μ | Subcarrier Spacing Δf | Use Case |
|---|---|---|
| 0 | 15 kHz | DownLink (DL), UpLink (UL) |
| 1 | 30 kHz | DL, UL, standard |
| 2 | 60 kHz | DL, UL, faster slots |
| 3 | 120 kHz | DL, UL, mmW |
| 4 | 240 kHz | mmW high speed |

**ButterFold Tapeout:** Not fixed on numerology (application-dependent)

---

## 3. OFDM FFT SIZE (Pages 5-10, 30-35)

### 3.1 FFT Size Definition
**3GPP Reference:** Clause 4.3.4 (OFDM-based physical channels and signals)

**Standard FFT sizes for 5G NR:**

| FFT Size (m) | Occupied Bandwidth | Use Case |
|---|---|---|
| 128 | 15 MHz (μ=0) | Narrowband, IoT, low-cost |
| 256 | 30 MHz (μ=0) | Standard small cell |
| 512 | 60 MHz (μ=0) | Larger cell |
| 1024 | 120 MHz (μ=0) | Macro cell |
| 2048 | 240 MHz (μ=0) | High-bandwidth |

**ButterFold Tapeout Choice:**
```
m = 128 = minimum practical proof-of-concept FFT (FROZEN FOR TAPEOUT)
  → Occupies ~15 MHz bandwidth at μ=0 (15 kHz spacing)
  → Achievable silicon size for first tapeout
```

### 3.2 FFT/IFFT Computation
**3GPP Reference:** Clause 5.7 (Demodulation reference signals), Annex B (FFT algorithms)

**Requirement:**
- Must support both **FFT** (RX demodulation) and **IFFT** (TX modulation)
- Both operate on m-point (128-point for tapeout)
- Both operate on complex-valued I/Q samples

---

## 4. CYCLIC PREFIX (Pages 11-18, 28-35)

### 4.1 CP Length Definition
**3GPP Reference:** Clause 4.3.3 (Cyclic Prefix)

**CP Types:**

| CP Type | Length (samples @ 15 kHz) | Purpose |
|---|---|---|
| Normal CP | 144 samples (1st OFDM symbol), 144 samples (others) | Standard channels |
| Extended CP | 512 samples | High-delay channels, high-speed scenarios |
| Short CP | -- | Not used in standard 5G NR |

**For ButterFold Tapeout (m=128):**
- Must support **Normal CP insertion/removal**
- CP length depends on subcarrier spacing and delay spread
- Typical: **16-32 samples for 15 kHz spacing**

**CP Insertion Logic:**
```
TX path: [m complex samples] → prefix copy → [m + CP_len complex samples] → DAC
RX path: [m + CP_len complex samples] → CP removal → [m complex samples] → FFT
```

---

## 5. QUANTIZATION & PRECISION (Pages 60-70)

### 5.1 I/Q Bit Width & Fixed-Point
**3GPP Reference:** Clause 5.1 (Physical layer signals)

**ButterFold Tapeout Choice: 8-bit I/Q**
```
Fixed-point quantization: 8-bit signed I/Q (2's complement)
  → Total: 16 bits per complex sample (8-bit I + 8-bit Q)
  → Interleaved I/Q byte stream over 8-bit data bus
```

**Justification:**
- Adequate for minimum proof-of-concept demonstration
- Reduces silicon area significantly
- Trade: limited PAPR reduction effectiveness (EVM ~-15 dB acceptable)

### 5.2 EVM (Error Vector Magnitude) Requirements
**3GPP Reference:** Clause 6.5.2 (Demodulation measurements)

**Standard EVM Limits:**

| Modulation | EVM Limit (dB) | Notes |
|---|---|---|
| π/2-BPSK | -16 dB | Minimum for SC-FDM |
| QPSK | -15 dB | Standard uplink |
| 16-QAM | -13 dB | Enhanced uplink |
| 64-QAM | -11 dB | Best case scenario |

**ButterFold Tapeout Target:**
```
EVM > -15 dB acceptable for 8-bit fixed-point implementation
```

---

## 6. MAPPING & SCHEDULING (Pages 60-70, 100-110)

### 6.1 Subcarrier Mapping
**3GPP Reference:** Clause 6.3.1.1 (PUSCH mapping to physical resources)

**Process for DFT-s-OFDM (k=12 → m=128 case):**

```
1. k=12 complex QAM symbols (DFT input) 
   ↓
2. k-point DFT (transform precoding)
   ↓
3. Map 12 DFT outputs to 12 RB subcarriers within m=128 grid
   (e.g., subcarriers 58-69 within 0-127)
   ↓
4. Zero-pad remaining m-12=116 subcarriers to zero
   ↓
5. m=128-point IFFT → 128 time-domain OFDM samples
```

**ButterFold Hardware:**
- Subcarrier mapper module must handle arbitrary k→m mapping
- For tapeout: k=12, m=128 (fixed)
- For simulation: support larger m (256, 512) and k (24, 36, 48...)

### 6.2 Block-Streaming I/O
**3GPP Reference:** Clause 6.2 (Physical resources)

**ButterFold I/O Contract:**

```
TX Mode:
  Input:  2k = 24 × 8-bit interleaved I/Q bytes (k=12 complex symbols)
  Process: DFT → map → IFFT → CP insert
  Output: 2(m+CP) = 2(128+16) = 288 bytes

RX Mode:
  Input:  2(m+CP) = 288 bytes
  Process: CP remove → FFT → extract → IDFT
  Output: 2k = 24 bytes (k=12 recovered complex symbols)

Timing:
  - Block boundary = slot or sub-slot (application-defined)
  - Must support variable burst lengths (testbench-driven)
```

---

## 7. COMPLIANCE BOUNDARIES (Pages 2-10, tapeout section)

### 7.1 Minimum NR Proof-of-Concept
**ButterFold Tapeout = FROZEN COMPLIANCE POINT**

| Aspect | Tapeout Config | Why Frozen |
|---|---|---|
| **Transform sizes** | k=12, m=128 | Minimum 1-RB DFT-s-OFDM |
| **I/Q precision** | 8-bit fixed-point | Area budget, first silicon |
| **CP support** | Normal CP only | Simplify first tapeout |
| **Numerology** | Any μ (application-determined) | IP-level parameterization |
| **RX/TX reuse** | TDD half-duplex assumption | Area minimization |
| **Frame structure** | Block-streaming, not full 5G slot | Proof-of-concept scope |

### 7.2 Out of Scope for Tapeout

These aspects are **left to simulation models** (not on silicon):

- Full-bandwidth multi-RB support (k = 12 × N_RB)
- Commercial FFT sizes (256, 512, 1024)
- Extended CP, PTRS (Phase-Tracking Reference Signals)
- HARQ, MAC-layer multiplexing
- Frequency/time synchronization
- Channel estimation, equalization
- Full 3GPP compliance testing

---

## 8. WAVEFORM PROPERTIES (Pages 70-80, annex B)

### 8.1 Linearity Requirement
**3GPP Reference:** Clause 5.1.1 (General)

**Property:**
- DFT-s-OFDM must preserve **linearity** of QAM encoding
- Zero input → zero output (required for testbench validation)
- Impulse input → known frequency-domain response

**ButterFold Verification:**
```
Testbench requirement:
  all_zero_tx: zero input → zero output (L2 norm = 0)
  impulse_tx: single '1' input → FFT magnitude is flat (+/- 0.5 dB)
```

### 8.2 PAPR Reduction
**3GPP Reference:** Clause 5.1.2 (Waveform properties)

**Definition:**
- Peak-to-Average Power Ratio (PAPR) = max(|s(n)|²) / avg(|s(n)|²)
- DFT-s-OFDM reduces PAPR vs. standard OFDM due to single-carrier-like structure

**ButterFold Benefit:**
- With 8-bit fixed-point: **PAPR reduction ~3-6 dB** vs. OFDM
- Allows power amplifier (PA) to operate more efficiently
- **Critical for low-power devices** (drones, sensors, tags)

---

## 9. KEY PARAMETERS SUMMARY

### Tapeout (Silicon) Parameters

```json
{
  "DFT_size_k": {
    "value": 12,
    "frozen": true,
    "rationale": "Minimum 1-RB NR allocation",
    "source": "3GPP TS 38.211 Clause 4.4.2"
  },
  "IFFT_FFT_size_m": {
    "value": 128,
    "frozen": true,
    "rationale": "Minimum proof-of-concept bandwidth (~15 MHz @ 15kHz spacing)",
    "source": "3GPP TS 38.211 Clause 4.3.4"
  },
  "i_q_bit_width": {
    "value": 8,
    "frozen": true,
    "rationale": "Area-minimized fixed-point quantization",
    "source": "ButterFold design choice"
  },
  "cp_type": {
    "value": "normal",
    "frozen": true,
    "rationale": "Standard channels, simplest implementation",
    "source": "3GPP TS 38.211 Clause 4.3.3"
  },
  "transform_precoding": {
    "value": "both_enabled_and_disabled",
    "frozen": true,
    "rationale": "Support both DFT-s-OFDM (TX) and standard OFDM (RX)",
    "source": "3GPP TS 38.211 Clause 6.3.1.4"
  },
  "system_duplex": {
    "value": "TDD_half_duplex",
    "frozen": true,
    "rationale": "Enables RX/TX hardware reuse",
    "source": "ButterFold architecture"
  }
}
```

### Simulation/DSE (Design-Space Exploration) Parameters

```json
{
  "DFT_size_k_extended": {
    "values": [12, 24, 36, 48, 60],
    "frozen": false,
    "rationale": "Support multi-RB allocations for standards compliance study",
    "source": "3GPP TS 38.211"
  },
  "IFFT_FFT_size_m_extended": {
    "values": [128, 256, 512, 1024],
    "frozen": false,
    "rationale": "Study larger bandwidth configurations",
    "source": "3GPP TS 38.211"
  },
  "cp_type_extended": {
    "values": ["normal", "extended"],
    "frozen": false,
    "rationale": "Test high-delay-spread scenarios",
    "source": "3GPP TS 38.211 Clause 4.3.3"
  },
  "radix_strategies": {
    "values": ["radix2_only", "radix2_3point", "radix2_4", "goodthomas"],
    "frozen": false,
    "rationale": "Compare mixed-radix butterfly architectures",
    "source": "ButterFold DSE"
  }
}
```

---

## 10. TESTBENCH COMPLIANCE CHECKS

### Required Waveform Tests (Traced to 3GPP)

| Test | Input | Expected Output | 3GPP Reference |
|---|---|---|---|
| **Zero Test** | All zeros (k=12) | All zeros (m+CP) | Linearity, Clause 5.1.1 |
| **Impulse Test** | [1, 0, 0, ...] | DFT output, known spectrum | Linearity |
| **QAM Test** | Random QPSK/16-QAM | BER/EVM < -15 dB | Clause 6.5.2 |
| **TX→RX Loopback** | QAM symbols → TX → RX | Recovered symbols ≈ input (±0.5 LSB) | End-to-end verification |
| **PAPR Reduction** | Random OFDM vs DFT-s-OFDM | PAPR(DFT-s-OFDM) < PAPR(OFDM) - 3dB | Clause 5.1.2 |

---

## 11. INTEGRATION WITH BUTTERFOLD AGENTS

### Meta-Planner Input
```
spec_doc: "3GPP_ButterFold_Spec_Extract.md"
→ Planner extracts:
   - k=12 requires mixed-radix engine (3×4 decomposition)
   - m=128 is radix-2 (7 stages)
   - TDD reuse → single transform engine for all 4 operations
   - Fixed-point 8-bit drives register widths
→ Output: hardware_constraints block in plan.json
```

### Verify Agent: Waveform-Level Checks
```
Verify agent reads this extract and checks RTL against:
  1. zero_input_zero_output (linearity)
  2. impulse_response (DFT property)
  3. tx_rx_loopback_recovery (end-to-end)
  4. busy_done_timing (block-streaming contract)
  5. cp_insertion_removal (waveform structure)
```

### Critic Skill: Adversarial Red-Team
```
Critic pre-verification checks:
  - Does RTL respect k=12, m=128 frozen params?
  - Does subcarrier mapper handle arbitrary k→m?
  - Does CP logic match 3GPP frame structure?
  - Are there any waveform compliance violations?
  - Does RX/TX reuse assume proper TDD guard time?
```

---

## 12. REVISION HISTORY & CODEBASE LINKS

- **Spec Version:** 3GPP TS 38.211 v18.6.0 Release 18 (2025-04)
- **ButterFold Version:** Tapeout v1.0
- **Extracted:** 2026-06-13
- **Related Files:**
  - `modular_description.md` — Hardware spec for agents
  - `agents/planner.py` — Hardware constraint extraction
  - `agents/verify.agent.py` — Waveform compliance checks
  - `tests/tb_butterfold_top.v` — Testbench implementing these checks

---

**END OF SPEC EXTRACT**

This document serves as the **single source of truth** for ButterFold's relationship to 3GPP TS 38.211. All RTL decisions, verification requirements, and DSE parameters trace back to specific clauses in this extract.
