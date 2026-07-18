# ADR-006: Kevin O'Hara TriggerHandler framework for all trigger logic

## Status

**Accepted**

## Date

2026-07-18 (decision from the build design; recorded retrospectively)

## Author

Mustafa Aksu

## Context

The org needs three pieces of trigger automation (double-booking blocked on
Appointment, prescriptions only on Completed appointments, room
availability synced on admission/discharge). Trigger logic written directly
in trigger bodies is untestable in isolation and accumulates into the
classic one-giant-trigger mess. This is also the pattern question the
author had already settled in TechnoStore (its ADR-005) — and an agentic
build is the *worst* place to improvise a new trigger architecture, because
the loop reproduces whatever pattern it is given, three times.

## Decision

Every trigger is a thin dispatcher extending **Kevin O'Hara's
`TriggerHandler`** (vendored verbatim, MIT-licensed, with its own test);
logic lives in one handler class per sObject
(`AppointmentTriggerHandler`, `PrescriptionTriggerHandler`,
`AdmissionTriggerHandler`), each with a dedicated test class.

## Consequences

### Positive

- Handlers are unit-testable classes — which is what let the verifier
  discipline work at the class level (the 88% → green moment of ADR-001
  happened *in a handler test*, not in an untestable trigger body).
- One pattern, three consistent instances: the loop deployed
  trigger + handler + test as a repeatable unit, which is exactly the kind
  of structure agentic construction thrives on.
- Portfolio-level consistency: the same framework and vendoring rules as
  TechnoStore, so a reviewer moving between repos re-reads nothing.

### Negative / Trade-offs

- A third-party file lives in the archive; it is excluded from this repo's
  MIT grant scope-confusion by an explicit LICENSE note crediting the
  upstream (the file is itself MIT, so terms are compatible — the note is
  about authorship, not permission).
- For three simple triggers the framework is arguably heavier than
  `if (Trigger.isBefore) ...` — accepted for the testability and the
  consistency above.

## Alternatives Considered

### Alternative A — logic directly in trigger bodies

Rejected: untestable in isolation; the verifier-driven loop (ADR-001)
depends on class-level tests.

### Alternative B — hand-rolled minimal dispatcher

Rejected: reinventing a solved problem inside a demo whose point is the
loop, not trigger frameworks — and losing the cross-repo consistency.

## References

- Source: README (automation row); `force-app/main/default/classes/TriggerHandler.cls` + test
- Upstream: https://github.com/kevinohara80/sfdc-trigger-framework (MIT)
- Related ADRs: ADR-001, ADR-005; TechnoStore ADR-005 (the precedent)
