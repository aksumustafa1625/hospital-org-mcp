# ADR-004: Dependency-ordered deploys; returned record Ids reused for seeding

## Status

**Accepted**

## Date

2026-07-18 (decision from the build design; recorded retrospectively)

## Author

Mustafa Aksu

## Context

Seven objects with seven lookup relationships (measured from the retrieved
source: Admission→Patient, Admission→Room, Appointment→Doctor,
Appointment→Patient, Doctor→Department, Prescription→Appointment,
Room→Department) cannot be deployed or seeded in arbitrary order: a lookup
field cannot exist before its target object, and a child record cannot
reference a parent Id that does not exist yet. An agent that treats deploys
as independent calls will fail intermittently and — worse — nondeterministically,
depending on which call lands first.

## Decision

The loop deploys metadata in **strict dependency order** (parents first:
Department before Doctor/Room, Patient/Doctor before Appointment,
Appointment before Prescription, Patient/Room before Admission), and seed
data reuses the **record Ids returned by RecordCreator** for parent
references, rather than re-querying or guessing.

## Consequences

### Positive

- Deploys and seeding are deterministic — the same plan succeeds every
  run, which is what makes a *loop* (as opposed to a lucky sequence)
  possible.
- Id-reuse closes a subtle failure class: re-querying by name assumes
  names are unique and stable mid-build; the returned Id is authoritative.
- The dependency plan is itself agent-visible reasoning: the ordering is
  part of the loop transcript, reviewable like any other decision.

### Negative / Trade-offs

- The plan must be maintained as the data model grows — a new lookup edge
  reorders the build. For seven objects this is trivial; at seventy it
  would warrant computing the topological order mechanically.
- Seed records carry raw-Id names in places (visible in the app
  screenshot) — kept deliberately as evidence of no human post-polish
  (ADR-005).

## Alternatives Considered

### Alternative A — deploy everything in one call and let the platform sort it out

Rejected: a single deploy of interdependent metadata either fails opaquely
or succeeds in ways that hide which dependency mattered — and teaches the
loop nothing it can reuse.

### Alternative B — retry-until-green ordering

Rejected: retries convert a knowable ordering problem into flaky
infrastructure, and the loop's diagnosis discipline (ADR-001) is the exact
opposite of blind retries.

## References

- Source: README (data-model row: "deployed in strict dependency order;
  returned record Ids reused for seed data"); relationships measured from
  `force-app/main/default/objects/*/fields/*.field-meta.xml`
- Related ADRs: ADR-001 (diagnosis over retries), ADR-005 (raw Ids kept)
