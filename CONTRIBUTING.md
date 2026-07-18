# Contributing to Hospital Org

This repo is an **exhibit, not a live codebase**: the retrieved source of
an org an AI agent loop built (see ADR-005). That changes what
"contributing" means here — most conventional PRs would *reduce* the repo's
value.

## The standing rule: loop-first, retrieve-after

The provenance story ("no human polished this") is the product. Therefore:

- **Do not hand-edit the retrieved metadata** in `force-app/` — not to
  rename the raw-Id seed record, not to tidy list views, not to reformat
  XML. Every polish erases a fingerprint of the unattended build.
- An actual improvement goes through the loop: change it **via the six MCP
  tools, in the org**, then `sf project retrieve` and commit the new
  retrieval as exactly that ("retrieved after loop change X").
- The one exception is the documentation layer (`README.md`, `docs/`,
  `ARCHITECTURE.md`, this file) — words about the exhibit, never the
  exhibit itself.

## Vendored third-party code

`force-app/main/default/classes/TriggerHandler.cls` (+ its test) is Kevin
O'Hara's MIT-licensed framework, vendored verbatim. It is **not touched**;
LICENSE credits the upstream (ADR-006).

## Reproduce / verify it yourself

```bash
sf project deploy start --manifest manifest/package.xml -o <your-org>
sf apex run test -o <your-org> --code-coverage --wait 10
```

Expected: all tests green; compare the coverage panel to
`docs/images/tests-green.png` (9/9, 93% overall in the recorded run —
platform version drift may move decimals, not verdicts). Apex tests are
free — no Flex Credits.

## CI

The GitHub Actions workflow is deliberately modest, matching what an
org-source archive can honestly verify without an org:

- **XML well-formedness** over all retrieved metadata (a corrupted exhibit
  is worse than none) — hard gate.
- **PMD static analysis** over the Apex, warm-up mode (`|| true`): the
  Apex here is agent-written and its rawness is part of the exhibit, so
  lint findings are informative, not gating.

There is no deploy-to-scratch-org job: the repo's claims are about a
recorded build, and the reproduction command above is a one-liner any
reviewer can run against their own org.

## Commits

- Atomic; plain-English summary under 72 characters.
- Body explains the *why* — and for anything under `force-app/`, names the
  loop action that produced the new retrieval.
- Co-authored-by trailer for AI-assisted commits.

## When to write an ADR

A decision that changes the loop's design (tools, verifier, exit
criterion), the provenance rules, or the vendoring policy gets an ADR in
[docs/adr/](docs/adr/) — same Nygard format as the sibling repos.
