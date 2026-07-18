# ADR-002: Six narrow MCP tools instead of one general deploy tool

## Status

**Accepted**

## Date

2026-07-18 (decision from the build design; recorded retrospectively)

## Author

Mustafa Aksu

## Context

The agent needs "hands" in the org. The maximal design is one general tool
("run any sf CLI command" / "execute any anonymous Apex") — flexible, and
impossible to reason about: its capability surface is the org itself, every
prompt-injection or model mistake has unbounded blast radius, and audit
logs show only "ran something". The minimal design is a tool per *intent*,
where each tool's name IS its capability statement.

## Decision

Six purpose-built MCP tools, each doing one thing:
`MetadataObjectDeployer`, `ApexClassDeployer`, `ApexTriggerDeployer`,
`ApexTestRunner`, `RecordCreator`, `AppBuilder`. They are exposed to Claude
over **Salesforce Hosted MCP Servers** (an External Client App + an MCP
server definition), so every call runs in the org's own security context,
as an authenticated user, fully audited.

## Consequences

### Positive

- The capability surface is enumerable in one sentence — deploy metadata,
  deploy classes, deploy triggers, run tests, create records, build the
  app. Nothing else is possible, whatever the model decides.
- Audit is per-intent: the org's logs show *which kind* of action happened,
  not an opaque shell string.
- Tool constraints teach the loop real platform semantics: when the test
  runner rejected a malformed request, the loop diagnosed the
  single-class-per-call constraint and adapted — a general tool would have
  let it stay sloppy.
- The verifier (`ApexTestRunner`) being a *separate tool* is what makes
  ADR-001's discipline mechanical rather than aspirational.

### Negative / Trade-offs

- Six tools to build, test, and maintain before the loop can run at all —
  the upfront cost IS the design.
- A genuinely new intent (e.g. deploying a Flow) needs a new tool, not a
  new prompt. Deliberate: capability growth should be a human decision.

## Alternatives Considered

### Alternative A — one general "run sf command" tool

Rejected: unbounded capability surface, unauditable intent, and every
model error becomes a potential org-wide action.

### Alternative B — local CLI scripting (no MCP, no org-side tools)

Rejected for the demonstration goal: the point was an agent operating
through governed, org-hosted capabilities — the same trust shape a real
enterprise would demand — not a workstation with admin credentials.

## References

- Source: README ("The agent's hands" row + Hosted MCP paragraph)
- Related ADRs: ADR-001 (verifier as its own tool), ADR-003 (tools as tested org citizens)
