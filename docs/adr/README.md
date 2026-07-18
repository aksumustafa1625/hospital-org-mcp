# Architecture Decision Records

Concise, immutable records of the decisions behind the Hospital Org agentic
build. Format: [Michael Nygard ADR](https://github.com/joelparkerhenderson/architecture-decision-record/blob/main/templates/decision-record-template-by-michael-nygard/index.md)
with light extensions (**Alternatives Considered** + **References**).

> **Provenance note.** These ADRs were written retrospectively when the
> documentation layer was added across the portfolio repos. They distill
> decisions that were made during the build and are already visible in the
> README, the retrieved source, and the five proof screenshots — nothing
> here is a new claim. Where a number appears (coverage, counts), it comes
> from the recorded run, not from memory.

## Why ADRs for a build that an agent performed

Precisely because an agent performed it. The interesting engineering is not
in any single Apex class — it is in the *loop design*: what the agent was
given as hands (six narrow tools), what it was given as ground truth
(ApexTestRunner), and what it was NOT allowed to do (grade itself, touch
anything outside the org's security context). Those are human architectural
decisions, and they are exactly the ones a reviewer asks about.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](ADR-001-verifier-driven-loop.md) | The loop's stop condition is the verifier, not the agent's self-assessment | Accepted | 2026-07-18 |
| [002](ADR-002-six-narrow-tools.md) | Six narrow MCP tools instead of one general deploy tool | Accepted | 2026-07-18 |
| [003](ADR-003-tools-live-in-org-as-tested-apex.md) | The agent's hands live IN the org, as Apex, each with its own test class | Accepted | 2026-07-18 |
| [004](ADR-004-dependency-ordered-deploys-id-reuse.md) | Dependency-ordered deploys; returned record Ids reused for seeding | Accepted | 2026-07-18 |
| [005](ADR-005-archive-the-retrieved-source.md) | The repo archives the RETRIEVED source — including its unpolished edges | Accepted | 2026-07-18 |
| [006](ADR-006-kevin-ohara-triggerhandler.md) | Kevin O'Hara TriggerHandler framework for all trigger logic | Accepted | 2026-07-18 |

## Lifecycle and template

Proposed → Accepted → Deprecated / Superseded by ADR-NNN; an Accepted ADR is
immutable — supersede, don't edit. Skeleton: Status / Date / Author /
Context / Decision / Consequences / Alternatives Considered / References
(copy from any ADR here).

## Related documentation

- [Architecture views](../architecture/) — context / container / loop sequence / data model
- [README.md](../../README.md) — the build story with the five proof screenshots
- Case study: [mustafaaksu.dev/en/projects/hospital-org-agentic-build](https://mustafaaksu.dev/en/projects/hospital-org-agentic-build)
