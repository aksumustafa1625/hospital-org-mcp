# ADR-005: The repo archives the RETRIEVED source — including its unpolished edges

## Status

**Accepted**

## Date

2026-07-18 (decision at publication; recorded retrospectively)

## Author

Mustafa Aksu

## Context

There are two candidate artifacts to publish after an agentic build: the
*intended* source (what the loop meant to deploy — its working files) or
the *retrieved* source (`sf project retrieve` of what the org actually
contains). They are usually identical — and "usually" is the problem. The
repo's claim is "an org built by an AI agent loop"; the only artifact that
proves the claim is the one the org itself hands back. The temptation to
tidy — rename the seed record whose Name is a raw Id, prettify a list
view — is exactly the temptation to resist, because every polish erases a
fingerprint of the unattended build.

## Decision

This repository contains the **retrieved source, verbatim**
(`manifest/package.xml` records exactly what was retrieved), plus the five
proof screenshots. No post-retrieval hand-editing: the raw-Id record name
visible in the app screenshot is kept as evidence that no human polished
the result afterwards.

## Consequences

### Positive

- The claim and the artifact match: what you read here is what
  `sf project deploy start --manifest manifest/package.xml` will recreate,
  and what the screenshots show running.
- Imperfections become evidence — the same inversion the sibling projects
  use (Aktenlage ships deliberate gaps; here, rawness proves provenance).
- Re-verification is one command per claim: deploy the manifest, run the
  tests, compare the coverage panel to `docs/images/tests-green.png`.

### Negative / Trade-offs

- The repo will never look hand-crafted, and some retrieved metadata is
  verbose (auto-generated layout/listView XML). Accepted: this is an
  exhibit, not a template library.
- Any future improvement must happen loop-first (change via the tools, in
  the org, re-retrieve) — editing this repo directly would break the
  provenance story. CONTRIBUTING.md states this as the standing rule.

## Alternatives Considered

### Alternative A — publish the intended source

Rejected: proves what the loop *tried*; the claim is about what it
*achieved*.

### Alternative B — retrieve, then polish for presentation

Rejected: every polish is a human edit inside an artifact whose entire
value is that no human edited it.

## References

- Source: README (repository layout; the app screenshot caption)
- Related ADRs: ADR-001 (the loop's honesty), ADR-004 (where the raw Ids come from)
