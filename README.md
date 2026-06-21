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

- [Requirements & use cases](docs/requirements.md) — actors, use cases, functional/non-functional requirements, POC acceptance criteria.
- [Design document](docs/design.md) — architecture, components, AWS topology, POC plan.
- [Architecture decisions](docs/decisions/) — ADRs recording the why behind key choices.

## Status

Planning / design. No code yet.
