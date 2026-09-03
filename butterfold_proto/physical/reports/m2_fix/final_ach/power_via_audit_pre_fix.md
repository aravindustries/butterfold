# ACH power-via audit — pre-fix

GDS SHA256: `b25fbd2fffaf138d211e33b281b8a8e248e0684ecded781003bc51f07532a5ed`

The reviewer concern is confirmed. The six physical source PORTs per supply do
not constitute six independent core-entry paths.

## VDD bottleneck

- Organizer source PORTs: 6 Metal2 shapes, collectively `(631.360, 1674.000)–(703.640, 1675.000) µm`.
- True independent core-entry paths: 1.
- Common transition: `(637.440, 1674.500) µm`.
- Metal2→Metal3: `Via2_VV`, 1×1, 1 cut.
- Metal3→Metal4: `Via3_VV`, 1×1, 1 cut.
- Upstream Metal2 width: 1.000 µm.
- Local Metal3 width: 1.000 µm.
- Downstream Metal4 width: 1.600 µm.
- Estimated paths using transition: all six VDD source PORTs and the entire core VDD load.
- Status: supply-critical single-via bottleneck.

## VSS bottleneck

- Organizer source PORTs: 6 west-edge Metal2 shapes.
- Six source Via2 transitions: `Via2_VV`, each 1×1, one cut.
- True independent core-entry paths after the shared Metal3 bus: 1.
- Common transition: `(8.800, 40.110) µm`.
- Metal3→Metal4: `Via3_VV`, 1×1, 1 cut.
- Metal4→Metal5: `Via4_VV`, 1×1, 1 cut.
- Upstream Metal3 bus width: 1.600 µm at the landing.
- Downstream Metal4 width: 1.600 µm.
- Metal5 core strap width: 1.600 µm.
- Estimated paths using transition: all VSS source PORTs and the entire core VSS load.
- Status: supply-critical single-via bottleneck.

## Gate values

- `VDD_SOURCE_PORTS = 6`
- `VSS_SOURCE_PORTS = 6`
- `TRUE_INDEPENDENT_VDD_ENTRY_PATHS = 1`
- `TRUE_INDEPENDENT_VSS_ENTRY_PATHS = 1`
- `MIN_VDD_PARALLEL_VIA_COUNT = 1`
- `MIN_VSS_PARALLEL_VIA_COUNT = 1`
- `VDD_SINGLE_VIA_BOTTLENECKS = 2` (stacked Via2 and Via3 transitions)
- `VSS_SINGLE_VIA_BOTTLENECKS = 2` (common Via3 and Via4 transitions; six source-local Via2 cuts are recorded separately)
