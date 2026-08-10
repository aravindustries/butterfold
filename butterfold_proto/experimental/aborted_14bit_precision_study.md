# Aborted 14-bit precision study

Status: **INCOMPLETE / NOT VALID FOR AN ARCHITECTURAL DECISION**

The experiment was stopped at the user's request. No production RTL, golden
model, vector, Makefile, or timing constraint was changed by the experiment.

## Partial observations

- Intended format was signed 14-bit Q6.7 architectural storage, retaining the
  existing 7 fractional bits and the physical 16-bit SRAM half-word port.
- Two generated candidates were explored outside the production source list:
  guarded wide intermediates (14B) and aggressively narrowed intermediates
  (14A).
- Preliminary synthesis results were approximately 458,457 um^2 for 14A and
  462,083 um^2 for 14B. Both were in the 450--470k physical-test band, not the
  <=450k target.
- Preliminary cycle instrumentation retained the existing 3,601-cycle FFT and
  4,211/4,187-cycle RX/TX initiation intervals.
- The generated RTL was discovered to contain an unresolved sign-extension
  defect in mechanically narrowed wide concatenations. Consequently its
  numerical and timing results are not authoritative, and no RTL/model
  bit-exactness claim is valid.
- Some low-amplitude vectors happened to match the 16-bit result, while
  directed high-magnitude cases exposed 14-bit wrap sensitivity. These data are
  diagnostic only because of the unresolved generated-RTL defect.

The complete generated tree was removed from the workspace during cleanup.
