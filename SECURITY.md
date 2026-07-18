# Security Model

What it means, security-wise, to hand an AI agent deployment power over a
Salesforce org — and how this build bounded it. Honest about what is demo
posture versus what would change in production.

## The capability surface, enumerated

The agent could do exactly six things (ADR-002) — deploy objects, deploy
classes, deploy triggers, run tests, create records, build an app — through
Apex tools it could not modify mid-run without those changes being
themselves deploys (visible, audited). There was no general "run any
command" channel, no anonymous-Apex escape hatch, no direct API access with
stored credentials.

## Authentication and audit

- Tools are exposed over **Salesforce Hosted MCP Servers** via an External
  Client App: every call is an authenticated org user's action, inside the
  org's own security context, and lands in the org's audit surface like any
  API client's would.
- **No credentials in this repo, ever**: no auth URLs, tokens, session ids,
  or connected-app secrets. The repo is retrieved metadata + documentation.

## Data

- The domain is **fictional**: patients, doctors, prescriptions are demo
  records invented by the loop (some named by raw Ids — kept as provenance,
  ADR-005). No real health data exists anywhere in this project.
- Note the irony this portfolio addresses elsewhere: a *hospital* org is
  exactly where an over-privileged agent is most dangerous — the sibling
  project **Agent Blast Radius** uses this same org as its lab for
  measuring agent over-reach (PS506: a GDPR-labelled field reaching a
  model past the user's FLS).

## Production deltas (demo posture, stated)

In a production adaptation of this pattern, the following would change:

1. **Separate build and target orgs** — here the org hosts its own
   construction tools (ADR-003 trade-off). In production: tools in a
   dedicated integration org or removed after the build window.
2. **Least-privilege integration user** — the demo ran with a developer's
   breadth; production tools would run as a permission-set-scoped user
   whose blast radius is itself reviewed (the sibling tool exists to do
   exactly that review).
3. **Per-tool rate/size guards** — governor limits bounded the demo
   naturally; production would add explicit caps and approval steps for
   destructive verbs (this build had none: no delete tool existed at all).

## Reporting

If you find a way this pattern's trust story breaks — a path by which the
agent could have acted outside the six tools, or a claim in the README the
retrieved source does not support — open a GitHub issue. The second kind
matters as much as the first: this portfolio treats an unsupported claim
as a defect of the same class as a vulnerability.
