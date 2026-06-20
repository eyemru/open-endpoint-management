# Design: Open-Source Endpoint Management System

**Status:** Draft · **Last updated:** 2026-06-20
**Phase:** Assemble-first (Stage 1), with a defined path to a custom Hybrid build (Stage 2)

---

## 1. Purpose & context

A small organization (think ~500 assets — in-office desktops and roaming laptops) runs
Windows 10 and Windows 11. They cannot fund commercial endpoint-management tooling
(Intune, Tanium, PDQ, etc.) and want an **open-source** system they can self-host on a
local server, on-prem, or in AWS.

The system must:

1. **Collect asset telemetry** and present asset details — owner, OS/build, hardware,
   installed software, patch status, compliance status.
2. **Push remediation** — OS security patches and standard software updates to Windows
   workstations, and run scripts.

This document describes the architecture, the open-source components, the AWS topology,
security considerations, and a phased proof-of-concept (POC) plan.

## 2. Goals & non-goals

**Goals**
- Self-hostable, open-source-first, no per-seat licensing cost.
- Works for **roaming laptops** (no inbound firewall / VPN dependency).
- Inventory + compliance + patch push for Windows 10/11.
- Hostable on AWS for the POC; portable to on-prem later.
- A clear, low-risk POC provable on **2 test endpoints**.

**Non-goals (for now)**
- macOS / Linux endpoint management (the tools support it; out of POC scope).
- Full MDM lifecycle (enrollment-from-zero-touch, device wipe, DEP/Autopilot).
- Production-grade HA, multi-region, or scale tuning. POC targets correctness, not scale.

## 3. Key constraints

| Constraint | Implication |
|---|---|
| ~500 mixed desktops + laptops | Agent-based, **phone-home over HTTPS** — never rely on reaching a device directly. |
| Windows 10 & 11 only (POC) | Use the Windows Update Agent API + Chocolatey for patching/software. |
| Open-source only | FleetDM (MIT core), osquery (Apache-2.0), Tactical RMM (source-available — see §9). |
| No budget for tooling | Self-host on a single modest EC2 / VM to start. |
| Bank-like security posture | Agents run with high privilege; treat enrollment secrets, TLS, and access control as first-class. |

## 4. Architecture decision (summary)

We start with **Assemble** (Stage 1) and grow into **Hybrid** (Stage 2). Full rationale
and the alternatives considered are in
[decisions/0001-assemble-first.md](decisions/0001-assemble-first.md).

- **Stage 1 — Assemble:** integrate **FleetDM** (visibility + compliance) and
  **Tactical RMM** (remediation + patching). Fast to a working system; teaches the domain.
- **Stage 2 — Hybrid:** custom control plane (FastAPI + Postgres + React) and a
  lightweight agent that embeds **osquery**, replacing integration seams with one
  unified data model and UI. Tracked in §11.

## 5. Components (Stage 1)

| Component | Role | Stack | Notes |
|---|---|---|---|
| **osquery** | The data-collection engine on each endpoint. Exposes the OS as SQL tables (installed software, patches, services, BitLocker, Defender, users, etc.). | C++ (Apache-2.0) | Shipped *inside* the Fleet agent; you rarely install it standalone. |
| **FleetDM** | Visibility & compliance control plane: host/software inventory, vulnerability data, **policies** (osquery-backed pass/fail compliance checks), live queries, dashboard, API. | Go server + **MySQL + Redis**. Agent = `fleetd` (orbit + osquery + Fleet Desktop). | Core is MIT; some features are Fleet Premium (paid). POC uses the free core. |
| **Tactical RMM** | Remediation control plane: Windows **patch management**, scripting, scheduled tasks, monitoring checks, alerting, remote access. | Django/Python + Vue + **PostgreSQL + Redis + NATS**, MeshCentral for remote sessions. Agent = Go (Windows service). | Source-available "Tactical RMM License" — review fit (§9). Handles the *push* side of the loop. |
| **MeshCentral** | Remote desktop / shell access to endpoints (bundled with Tactical RMM). | Node.js | Optional for POC; useful for hands-on remediation. |

### Why two tools

They cover complementary halves of the loop and each is best-in-class at its half:

- **Fleet** = rich, osquery-driven **read/compliance** posture. Excellent at "what is the
  fleet's state and is it compliant?"
- **Tactical RMM** = robust **write/remediation** — actually applying Windows updates,
  installing software, running scripts on a schedule.

Fleet *can* run scripts and is growing Windows patch features via MDM; Tactical RMM *can*
inventory. We lead with each where it is strongest and revisit consolidation in Stage 2.

## 6. High-level architecture

```
   Windows 10/11 endpoints (×N)                         AWS control plane (POC: 1–2 EC2)
 ┌──────────────────────────────┐                    ┌───────────────────────────────────┐
 │  fleetd agent (osquery)       │  HTTPS 443 ──────► │  FleetDM server ─► MySQL + Redis    │
 │   • inventory + telemetry     │  ◄── live query ── │   • inventory, policies, dashboard  │
 │                               │                    │                                     │
 │  Tactical RMM agent (Go svc)  │  HTTPS 443 ──────► │  Tactical RMM ─► Postgres+Redis+NATS│
 │   • patch / software / scripts│  ◄──── jobs ────── │   • patching, scripts, alerts       │
 │   • MeshCentral (remote)      │                    │   • MeshCentral (remote access)     │
 └──────────────────────────────┘                    └───────────────────────────────────┘
        outbound only (443)                                   Route53 DNS + TLS (Let's Encrypt/ACM)

 Admin browses Fleet UI (posture) + Tactical RMM UI (remediation) over HTTPS.
```

**Data flow**
1. Agents enroll once using an enrollment secret/token, then phone home outbound over 443.
2. osquery (via fleetd) periodically reports inventory + evaluates Fleet **policies**.
3. Tactical RMM agent reports inventory + patch status, and **pulls jobs** (patch installs,
   scripts, software installs) on a schedule or on demand.
4. Admins view posture in Fleet, trigger remediation in Tactical RMM.

## 7. Compliance policy examples (Fleet policies)

Each is an osquery query that returns "compliant" rows; Fleet marks pass/fail per host.

- **BitLocker enabled** on the OS volume.
- **Microsoft Defender** real-time protection on, signatures < 3 days old.
- **Windows Firewall** enabled on all profiles.
- **No missing critical/security updates** (no pending important patches).
- **OS build is current or N-1** (latest or previous Patch Tuesday build).
- **Screen-lock timeout ≤ 15 minutes**.
- **Required software present** (e.g., EDR agent, corporate VPN).
- **Local administrators limited** to an approved set.
- **Disk free space ≥ threshold** (so patches can install).

## 8. Patch & software examples (Tactical RMM)

- **OS security patches** — monthly cumulative updates, auto-approve Critical/Security,
  install in a maintenance window, reboot policy.
- **.NET / runtime updates**.
- **Browsers** — Edge, Chrome (Chrome via Chocolatey).
- **Third-party apps via Chocolatey** — 7-Zip, Notepad++, VLC, etc.
- **Ad-hoc scripts** — e.g., enable BitLocker, set firewall, fix a misconfiguration found
  by a Fleet policy (closing the visibility → remediation loop).

## 9. Security considerations

- **Agent privilege.** Both agents run as SYSTEM. In a bank-like context this is the
  highest-risk surface: a compromise of the control plane = code execution on every
  endpoint. Lock down the servers, restrict admin UI access (SSO / VPN / IP allowlist),
  and audit script execution.
- **Enrollment secrets.** Treat Fleet enrollment secrets and Tactical RMM agent install
  tokens as credentials — never commit them (see `.gitignore`); rotate them.
- **TLS everywhere.** Tactical RMM specifically requires a real domain + valid TLS certs
  (Let's Encrypt). Fleet should also be TLS-only. Agents pin/validate certs.
- **Network.** Agents need **outbound 443 only**. Inbound to the control plane is limited
  to 443 (+ admin access path). No inbound to endpoints.
- **Licensing review.** **Tactical RMM** uses a source-available license with use
  restrictions (notably around reselling it as a managed service). Self-hosting for one's
  own internal fleet is generally within scope, but **legal/license review is an action
  item** before any real (non-POC) deployment. FleetDM core is MIT; confirm which features
  are gated behind Fleet Premium.
- **Data sensitivity.** Inventory data (software, users, hostnames) is itself sensitive.
  Encrypt at rest (RDS/EBS encryption) and in transit.

## 10. AWS deployment topology (POC)

**Control plane**
- 1 EC2 instance (Ubuntu/Debian LTS, ~t3.large to start) — can co-host or split:
  - Option A (simplest): Tactical RMM on its own instance (it expects a clean Debian/Ubuntu
    with three DNS records: `api.`, `rmm.`, `mesh.`), Fleet on a second small instance.
  - Option B (lean POC): a single instance running both via Docker Compose, accepting the
    extra fiddliness.
- **Route53** hosted zone + records; **Let's Encrypt** (or ACM behind an ALB) for TLS.
- **Security group:** inbound 443 (agents) + restricted admin access (your IP / VPN);
  outbound open. SSH via SSM Session Manager (no public 22) preferred.
- **Storage:** managed DB (RDS MySQL for Fleet, RDS Postgres for Tactical RMM) *or*
  containerized DBs on the instance for a cheap POC. EBS/RDS encryption on.

> **Test endpoints — important nuance.** EC2 offers **Windows _Server_**, not the Windows
> 10/11 *client* OS. To test true Win10/11 behavior, the cleanest POC is **local VMs**
> (Hyper-V / VirtualBox / VMware) running Win10 + Win11, with the control plane in AWS and
> agents phoning home over the internet. Alternatives: AWS WorkSpaces, or EC2 dedicated
> hosts with BYOL Windows client media (more setup, more cost). **Recommendation: 2 local
> Win10/11 VMs as the test endpoints; AWS hosts the servers.** (Open question — see §12.)

## 11. POC plan (thin slice, then breadth)

Goal of the thin slice: **2 enrolled endpoints → telemetry visible → 1 compliance check →
1 patch pushed, end to end.** Tactical RMM alone can prove the entire loop, so we lead with
it and layer Fleet in for richer compliance.

| Milestone | Deliverable | Proves |
|---|---|---|
| **M0 — Foundations** | AWS account/VPC, Route53 domain, 2 local Win10/11 VMs ready. | Environment exists. |
| **M1 — Tactical RMM up** | Tactical RMM installed on EC2 with TLS; admin UI reachable. | Control plane runs. |
| **M2 — Enroll endpoints** | TRMM agent installed on both VMs; they appear with inventory. | Telemetry loop works. |
| **M3 — First remediation** | Push one Windows security patch + one Chocolatey app to a VM. | The *push* half works end to end. ✅ thin slice complete |
| **M4 — Fleet up** | FleetDM installed (MySQL+Redis) with TLS; dashboard reachable. | Compliance plane runs. |
| **M5 — Enroll in Fleet** | `fleetd` on both VMs; inventory + software visible in Fleet. | osquery telemetry works. |
| **M6 — First policy** | One compliance policy (e.g., BitLocker on) reporting pass/fail. | Compliance evaluation works. |
| **M7 — Close the loop** | A failing Fleet policy triggers a TRMM remediation script (manual hand-off for POC). | Visibility → remediation loop. |
| **M8 — Document** | Runbook + screenshots; capture what to keep vs. rebuild in Stage 2. | Decision input for Hybrid. |

## 12. Open questions

- **Test endpoints:** confirm 2 local Win10/11 VMs vs. AWS WorkSpaces vs. EC2 Windows
  Server (recommendation: local VMs — see §10).
- **Domain name:** do we have a domain/subdomain to use for Route53 + TLS? Tactical RMM
  *requires* this.
- **Single instance vs. split:** co-host Fleet + TRMM on one EC2 (cheap) or separate
  (cleaner)? Recommendation: separate small instances if budget allows; otherwise one.
- **Admin access path:** SSO? VPN? IP allowlist for the admin UIs?
- **Licensing sign-off:** confirm Tactical RMM license fit for the intended (non-POC) use.

## 13. Roadmap to Stage 2 (Hybrid)

When the assembled system has taught us the requirements, build:
- a **custom agent** (enrollment, phone-home, job execution, Windows Update orchestration),
  embedding osquery for telemetry;
- a **control plane** — FastAPI + Postgres + a job queue;
- a **compliance engine** — policies → pass/fail, modeled on what we learned from Fleet;
- a **unified React dashboard** — one view of inventory + compliance + patching.

The Stage 1 work is not throwaway: osquery query library, compliance policy definitions,
patch/maintenance-window logic, and the AWS/Terraform topology all carry forward.
