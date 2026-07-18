# Hospital Org — Source Layout

This repository is an **exhibit**: the retrieved, unpolished source of an
org built by an AI agent loop (ADR-005). The layout below is what
`sf project retrieve` handed back; the reasoning behind it lives in
[docs/adr/](docs/adr/).

```
hospital-org-mcp/
├── manifest/package.xml          exactly what was retrieved from the org
├── docs/
│   ├── images/                   the five proof screenshots the README cites
│   ├── adr/                      6 decision records of the loop design
│   └── architecture/             context / container / loop sequence / data model
└── force-app/main/default/
    ├── objects/                  7 custom objects (fields, list views)
    │                             Department, Patient, Doctor, Room,
    │                             Appointment, Prescription, Admission
    ├── triggers/                 AppointmentTrigger, PrescriptionTrigger,
    │                             AdmissionTrigger — thin dispatchers
    ├── classes/
    │   ├── *TriggerHandler.cls        the product: 3 handlers + 3 tests
    │   ├── TriggerHandler.cls         vendored O'Hara base (MIT) + test
    │   └── the six MCP tools + tests  the agent's hands, as tested Apex:
    │       MetadataObjectDeployer · ApexClassDeployer · ApexTriggerDeployer
    │       ApexTestRunner (the verifier) · RecordCreator · AppBuilder
    └── applications/             Hospital_Management app
```

## The rules that shaped it

1. **The verifier ends the loop** (ADR-001): ApexTestRunner's report — all
   green at ≥ 90% coverage — is the only exit; the agent never grades
   itself. The recorded 88% → green correction is the design working.
2. **One tool per intent** (ADR-002): six named capabilities over Hosted
   MCP, running in the org's own security context, fully audited.
3. **The hands are tested like the product** (ADR-003): every tool has its
   own test class and shows up in the coverage panel.
4. **Parents before children** (ADR-004): the lookup graph (measured in
   [docs/architecture/04-data-model.md](docs/architecture/04-data-model.md))
   dictates deploy and seed order; RecordCreator's returned Ids are reused.
5. **No hand-polish after retrieval** (ADR-005): raw edges are provenance.
   Improvements go loop-first — change via the tools, in the org,
   re-retrieve.
6. **Trigger logic lives in handlers** (ADR-006), on the vendored O'Hara
   base.

## Reading order

`README.md` (the story + proofs) → [docs/architecture/](docs/architecture/)
(the shape) → [docs/adr/](docs/adr/) (the decisions) → the source itself —
start with `ApexTestRunner.cls`, because everything else is downstream of
the verifier.
