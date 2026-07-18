# ADR-001: The loop's stop condition is the verifier, not the agent's self-assessment

## Status

**Accepted**

## Date

2026-07-18 (decision from the build design; recorded retrospectively)

## Author

Mustafa Aksu

## Context

By 2026, "can a model write an Apex class?" is settled. The open question is
loop engineering: can an agent do multi-step platform work — governor
limits, metadata dependencies, deployment order — without a human typing
each step, *and can the result be trusted*? A loop whose exit is the model
saying "done" is an expensive way to generate plausible-looking code: the
same model that wrote the bug decides whether the bug exists.

## Decision

The loop's stop condition is **objective and external**: `ApexTestRunner`
must report all tests green at ≥ 90% coverage. The cycle is
deploy metadata → deploy Apex → run tests → read the ACTUAL failures →
fix → repeat. The agent never grades itself; the test runner does.

## Consequences

### Positive

- The recorded run contains the proof this design exists for:
  `PrescriptionTriggerHandler` came back at **88%**, under target — and the
  loop did not declare success. It read *which* lines were uncovered (the
  two `addError` guard branches), wrote a null-appointment test for the
  missing path, and re-ran to green. A self-grading loop would have shipped
  at 88 with a confident summary.
- Failures drive diagnosis, not retries: on an opaque script-exception the
  loop enumerated root causes (object already exists? permissions? an
  in-flight deploy?) instead of hammering the same call.
- The final numbers (92 / 100 / 90%, 9/9 green, 93% overall) are readable
  in the org's own Developer Console — verification lives outside the chat.

### Negative / Trade-offs

- Coverage is a floor, not a semantic guarantee: 90% proves the tests run
  the code, not that the tests encode the right requirements. The
  requirements (double-booking blocked, prescriptions only on Completed
  appointments, room sync) were human-specified.
- The loop is only as honest as the verifier's output parsing — reading
  "the ACTUAL failures" verbatim is load-bearing; summarising them away
  would reopen the self-grading hole.

## Alternatives Considered

### Alternative A — the agent declares completion

Rejected: shared-mind problem. The whole build exists to demonstrate the
opposite discipline.

### Alternative B — human reviews each step

Rejected for the goal: that is not an agent loop, it is autocomplete with
extra latency. The human designs the loop and the stop condition; the loop
runs.

## References

- Source: README ("The loop, as it actually ran" + the 88% screenshot `docs/images/loop-verifier.png`)
- Related ADRs: ADR-002 (the hands), ADR-003 (the verifier is itself tested Apex)
