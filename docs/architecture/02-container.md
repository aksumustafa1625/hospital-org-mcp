# 02 — Container Diagram (C4 Level 2)

## Purpose

The two populations of Apex in this org — the **tools** (the agent's hands)
and the **product** (what the hands built) — and the rule that both are
held to the same testing bar.

## Diagram

```mermaid
graph TB
    subgraph ToolLayer["The agent's hands — six MCP tools (each with its own test class)"]
        MOD["MetadataObjectDeployer<br/><i>objects, fields, list views</i>"]
        ACD["ApexClassDeployer<br/><i>classes (one per call)</i>"]
        ATD["ApexTriggerDeployer<br/><i>triggers</i>"]
        ATR["ApexTestRunner<br/><b>THE VERIFIER</b><br/><i>runs tests, reports coverage<br/>+ actual failures</i>"]
        RC["RecordCreator<br/><i>seed data; returns Ids<br/>for parent references</i>"]
        AB["AppBuilder<br/><i>Lightning app, tabs</i>"]
    end

    subgraph Product["The product — what the loop built"]
        OBJ["7 custom objects<br/><i>Department, Patient, Doctor, Room,<br/>Appointment, Prescription, Admission</i>"]
        TRG["3 triggers → 3 handlers<br/><i>on the O'Hara TriggerHandler base</i>"]
        TST["3 handler test classes<br/><i>92 / 100 / 90% coverage</i>"]
        APP["Hospital_Management app<br/><i>tabs, list views, layouts</i>"]
    end

    MOD --> OBJ
    ACD --> TRG
    ACD --> TST
    ATD --> TRG
    RC --> OBJ
    AB --> APP
    ATR -.->|"verdict on"| TST
    ATR -.->|"and on the tools' own tests"| ToolLayer

    style ATR fill:#B03A2E,stroke:#78281F,color:#fff,stroke-width:2px
    style OBJ fill:#28B463,stroke:#1D7E45,color:#fff
```

## Rules that shaped this picture

| Rule | Consequence | ADR |
|---|---|---|
| Verifier ends the loop, not the agent | ATR's report (incl. the 88% no) is the only exit | 001 |
| One tool per intent | six named capabilities, nothing general-purpose | 002 |
| Hands are tested like product | every `*Deployer`/`Runner`/`Creator`/`Builder` has a `*Test` | 003 |
| Parents before children | deploy/seed order follows the lookup graph | 004 |
| Trigger logic in handlers | triggers are thin dispatchers on the vendored base | 006 |

## Drill-down

- The loop in time order, with its two teachable failures: [03 — Sequence](03-sequence.md)
- The 7-object lookup graph, measured from source: [04 — Data Model](04-data-model.md)
