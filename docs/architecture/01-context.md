# 01 — System Context (C4 Level 1)

## Purpose

Who and what took part in the build: the human designs the loop, the agent
runs it, the org verifies it. The boundary worth noticing is that **all
capability lives inside the org** — there is no credentialed middle layer.

## Diagram

```mermaid
graph TB
    Human(["Mustafa Aksu<br/><i>designs the loop, the six tools,<br/>and the stop condition — then steps back</i>"])
    Claude["Claude (AI agent)<br/><i>deploys, tests, reads failures,<br/>fixes, repeats</i>"]

    subgraph Org["Salesforce Developer Edition org"]
        MCP["Hosted MCP Server<br/><i>External Client App —<br/>authenticated, audited,<br/>org security context</i>"]
        Tools["Six MCP tools (Apex)<br/><i>MetadataObjectDeployer · ApexClassDeployer<br/>ApexTriggerDeployer · ApexTestRunner<br/>RecordCreator · AppBuilder</i>"]
        Built["The built artifact<br/><i>7 objects · 3 triggers+handlers ·<br/>tests · Hospital_Management app</i>"]
    end

    Repo[("This repository<br/><i>retrieved source, verbatim<br/>+ 5 proof screenshots</i>")]

    Human -->|"one prompt +<br/>loop design"| Claude
    Claude <-->|"MCP calls /<br/>ACTUAL failure output"| MCP
    MCP --> Tools
    Tools -->|"deploy · seed · test"| Built
    Built -->|"sf project retrieve<br/>(no hand-polish after)"| Repo

    style Claude fill:#8E44AD,stroke:#5E2D73,color:#fff
    style Tools fill:#003F7F,stroke:#001E3D,color:#fff,stroke-width:2px
    style Built fill:#28B463,stroke:#1D7E45,color:#fff
```

## Key observations

1. **The human's contribution is the loop, not the code** — the design of
   the hands (ADR-002), the ground truth (ADR-001), and the exit criterion
   (≥ 90% coverage, all green).
2. **No credentials outside the org**: Claude reaches the tools through a
   Hosted MCP Server; every call executes as an authenticated user under
   the org's own audit (ADR-003).
3. **The verifier is inside the boundary it verifies** — ApexTestRunner is
   org-resident, tested Apex, and its word (not the agent's) ends the loop.
4. **The repo is downstream of the org**, never the other way: what is
   published is what was retrieved (ADR-005).

## Drill-down

Inside the boundary: [02 — Container](02-container.md).
