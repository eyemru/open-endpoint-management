# Endpoint Management Experiment

An open-source endpoint asset-management and patch-management system for a small
Windows fleet (~500 Windows 10/11 desktops and laptops). Self-hostable on a local
server, on-prem, or AWS.

## What it does (target)

- **Visibility** — inventory every device: owner, hardware, OS/build, installed
  software, patch level, compliance posture.
- **Compliance** — evaluate device telemetry against policy and report pass/fail.
- **Remediation** — push OS security patches and software updates, run scripts.

## Approach

We are building in two stages:

1. **Assemble (current)** — stand up and integrate proven open-source tools
   (**FleetDM** for visibility/compliance, **Tactical RMM** for remediation/patching)
   to get a working system fast and learn the domain.
2. **Hybrid (later)** — replace the integration seams with a custom control plane
   (Python/FastAPI + Postgres + React) and a lightweight agent, while continuing to
   reuse osquery for telemetry. See [docs/design.md](docs/design.md).

## Docs

- [**Business brief**](docs/business-brief.md) — high-level overview for department leads (what's deployed, what the business gets, data/cost/rollout).
- [**Implementation & rollout plan**](docs/implementation-plan.md) — how we execute: phases, enrollment tracks, sizing/HA, environment assessment (PM/TPM + technical leads).
- [Requirements & use cases](docs/requirements.md) — actors, use cases, functional/non-functional requirements, POC acceptance criteria.
- [Design document](docs/design.md) — architecture, components, AWS topology, POC plan.
- [**Architecture & data flow (detailed)**](docs/architecture.md) — every component, ports, and end-to-end flows.
- [Compliance policy catalog](docs/compliance-policies.md) — per-policy osquery queries + remediation specs.
- [Infrastructure & setup plan](docs/infrastructure.md) — AWS network, instance sizing, DNS/TLS, install runbooks (M0–M1).
- [**Deployment guide**](docs/deployment-guide.md) — repeatable step-by-step + automated deploy/teardown of the control plane.
- [**Agent install guide**](docs/agent-install-guide.md) — enroll a Windows endpoint (with the real-world gotchas).
- [Deployment scripts — AWS](infra/scripts/) — `deploy.sh` (one-shot), step scripts, `start`/`stop`/`teardown`.
- [Deployment kit — on-prem](onprem/) — run the same stack on your own Ubuntu/Debian servers (no AWS/Terraform/SSM).
- [Architecture decisions](docs/decisions/) — ADRs recording the why behind key choices.
- [Roadmap / backlog](docs/roadmap.md) — prioritized gaps (P0/P1/P2) for going beyond the POC.
- [Executive briefing deck](presentation/) — exec-level pitch (PowerPoint) for the business case.

## Status

Planning / design. No code yet.
