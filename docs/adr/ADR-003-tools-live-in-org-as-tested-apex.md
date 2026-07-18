# ADR-003: The agent's hands live IN the org, as Apex, each with its own test class

## Status

**Accepted**

## Date

2026-07-18 (decision from the build design; recorded retrospectively)

## Author

Mustafa Aksu

## Context

MCP tools can live anywhere — a local server, a cloud function, a proxy
with stored credentials. Wherever they live, they hold deployment power
over the org, which makes them the most security-sensitive code in the
system. Code with that much power should be subject to the same discipline
as the code it deploys — and hosted where the org's own security model
governs it, rather than beside an API key on a laptop.

## Decision

The six tools are **Apex classes inside the org itself**, exposed via
Salesforce Hosted MCP Servers, and **each tool has its own test class**
(`ApexClassDeployerTest`, `ApexTestRunnerTest`, ...). The tools appear in
the org's coverage panel like any other Apex — visibly tested (the 9/9
green, 93% overall screenshot includes them).

## Consequences

### Positive

- No stored credentials anywhere: calls authenticate through the External
  Client App and execute as an authenticated user, inside the org's
  sharing/FLS/audit regime. There is no side channel to leak.
- The trust story is recursive and closes: the loop's verifier is tested,
  the deployers are tested, and the tests they run are the same mechanism
  that gates the build (ADR-001).
- The tools are part of the retrieved archive (ADR-005) — a reviewer can
  read the agent's entire capability surface as source, in this repo.

### Negative / Trade-offs

- Apex governor limits bound what a tool call can do (the
  single-class-per-call constraint the loop had to learn is a direct
  consequence). Accepted: limits that force explicit steps also make the
  audit trail granular.
- The org under construction hosts its own construction tools — in a
  production migration these would be separated (build org vs target org)
  or removed after the build; in a Developer Edition demo they stay, as
  exhibits.

## Alternatives Considered

### Alternative A — local MCP server wrapping the sf CLI

Rejected: workstation credentials with org-admin power, invisible to org
audit, and nothing about the tools would be reviewable as part of the
built artifact.

### Alternative B — untested "plumbing" tools ("it's just glue code")

Rejected: the glue holds deployment power; untested glue with deployment
power is exactly the code that fails at the worst moment. Every tool
shipped with its test from the start.

## References

- Source: README (tools row, Hosted MCP paragraph, `docs/images/tests-green.png`)
- Related ADRs: ADR-001, ADR-002, ADR-005
