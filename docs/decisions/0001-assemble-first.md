# ADR 0001 — Assemble proven OSS first, grow into a custom Hybrid build

**Status:** Accepted · **Date:** 2026-06-20

## Context

We need an open-source endpoint asset-management + patch-management system for ~500
Windows 10/11 devices, self-hostable (AWS for the POC). Two viable paths were compared:

- **Hybrid** — build a custom control plane (FastAPI + Postgres + React) and a lightweight
  agent, reusing osquery for telemetry and the Windows Update API/Chocolatey for patching.
- **Assemble** — deploy and integrate existing OSS (FleetDM for visibility/compliance,
  Tactical RMM for remediation/patching) with minimal custom code.

## Decision

**Start with Assemble; grow into Hybrid later.**

## Rationale

- **Fast time-to-value:** a working system in days vs. weeks, so we can put it in front of
  real endpoints and learn what "good" looks like.
- **Requirements discovery:** Fleet's policies and Tactical RMM's patch workflows teach us
  the domain — which compliance checks matter, how Windows patching really behaves — before
  we commit that knowledge to custom code.
- **Lower initial risk:** community-vetted agents and patch logic instead of us owning
  SYSTEM-level remediation code from day one.
- **Non-blocking:** nothing in the assembled stack prevents a later custom build; the
  osquery queries, compliance policies, patch logic, and AWS/IaC topology all carry forward.

## Trade-offs accepted

- Two systems with integration seams, rather than one unified data model/UI.
- Less control over the data model and dashboard during Stage 1.
- **Tactical RMM is source-available** (not OSI-open) with use restrictions — requires a
  licensing review before non-POC use. FleetDM core is MIT (some features are Premium/paid).

## Revisit when

The assembled system is running against real endpoints and we have captured the concrete
requirements (compliance policy set, patch/maintenance-window behavior, the unified view we
actually want). At that point, re-evaluate building the Stage 2 Hybrid control plane + agent.

## Related

- [docs/design.md](../design.md) — full architecture and POC plan.
