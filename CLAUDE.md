# CLAUDE.md — working context for hospital-org-mcp

This file is for whoever (or whatever) opens this repo next. Read it before
changing anything, because the most natural "improvements" here are the
ones that destroy the repo's value.

## What this is

The **retrieved source of a Salesforce org that an AI agent loop built** —
Claude deploying, testing, reading failures, fixing, repeating, through six
custom MCP tools, with ApexTestRunner as the verifier (stop condition: all
green at ≥ 90% coverage; final: 92/100/90%, 9/9 tests, 93% overall). The
repo is an *exhibit*: proof of a recorded build, plus the documentation
layer around it. Full story in README.md; case study and video linked from
there.

## The one binding rule

**Never hand-edit anything under `force-app/`.** The provenance claim ("no
human polished this") is the product; the raw-Id seed record name in the
app screenshot is *evidence*, not a bug. A real change goes loop-first:
via the MCP tools, in the org, then re-retrieve and commit the new
retrieval as such. Documentation (README, docs/, root docs) is the only
hand-editable surface. (ADR-005; CONTRIBUTING.md spells it out.)

## Map

- `force-app/main/default/` — the exhibit: 7 objects, 3 triggers + O'Hara
  handlers + tests, the six MCP tools + their tests, the app
- `manifest/package.xml` — exactly what was retrieved
- `docs/images/` — the five proof screenshots the README cites by name
- `docs/adr/` — 6 decision records (verifier-driven loop; six narrow
  tools; tools as tested in-org Apex; dependency-ordered deploys;
  archive-the-retrieved-source; O'Hara framework)
- `docs/architecture/` — context / container / loop sequence / data model
  (the lookup graph there is measured from the field XML, not drawn)

## Facts worth not re-deriving

- All 7 inter-object relationships are **Lookups** (no master-detail);
  business rules live in the three handlers, not in schema.
- The deploy/seed order is the lookup graph topologically sorted:
  Department & Patient → Doctor & Room → Appointment → Prescription &
  Admission. RecordCreator's returned Ids are reused for parents.
- The tools obey platform constraints the loop had to learn:
  ApexClassDeployer is one class per call; the test runner rejects
  malformed batch requests (the loop diagnosed this, not retried it).
- README's numbers (88% → green story, 92/100/90%, 9/9 at 93%) come from
  the recorded run and its screenshots. Do not "refresh" them from a new
  org run without re-retrieving and saying so — mismatched claims are this
  portfolio's definition of a defect.

## Sibling repos (same documentation discipline)

agent-blast-radius (what an agent's code can reach — uses THIS org as its
lab), hansewatt-pruefstand (what an agent does), aktenlage (files the
evidence, EU AI Act Art. 26), TechnoStore (the Q2C build). Cross-repo
conventions: Nygard ADRs in `docs/adr/`, mermaid views in
`docs/architecture/`, measured claims only, commit messages that say what
changed AND why it was wrong before.
