# Design: Open-Source Endpoint Management System

**Status:** Draft · **Last updated:** 2026-06-20
**Phase:** Assemble-first (Stage 1), with a defined path to a custom Hybrid build (Stage 2)
**Companion to:** [requirements.md](requirements.md) — actors, use cases, and the
functional/non-functional requirements this design satisfies (with a traceability matrix).

---

## 1. Purpose & context

An organization managing a large Windows 10/11 fleet — **~10,000 assets ultimately** (desktops
and roaming laptops), phased in via a 50-device pilot, a ~1,000 new-machine milestone, then the
existing fleet. They cannot fund commercial endpoint-management tooling (Intune, Tanium, PDQ —
per-device, six figures/year at this scale) and want an **open-source** system they self-host
on-prem or in a cloud they operate.

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

**Non-goals for the initial POC** (all are program goals for later phases — see §13, roadmap):
- macOS / Linux endpoint management (the tools support it; out of POC scope).
- Full MDM lifecycle (device wipe, DEP/Autopilot).
- Production HA + scale-out to ~10k, and **zero-touch enrollment via gold-image pre-install**
  (the ~1,000 new-machine milestone). The POC targets correctness on a thin slice, not scale.

## 3. Key constraints

| Constraint | Implication |
|---|---|
| ~10,000 desktops + laptops (phased) | Agent-based, **phone-home over HTTPS**; at scale Fleet scales out horizontally and the management plane may run as multiple instances (see §13). |
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

![Stage 1 architecture — Windows 10/11 endpoints phoning home over HTTPS 443 to FleetDM and Tactical RMM hosted on AWS, with DuckDNS + Let's Encrypt for DNS/TLS and IT admins managing via browser](diagrams/architecture.svg)

> **For a detailed component + ports + data-flow view, see [architecture.md](architecture.md).**
>
> *Editable source: [`diagrams/architecture.drawio`](diagrams/architecture.drawio) — open in
> [draw.io / diagrams.net](https://app.diagrams.net). The SVG embeds the same source, so
> opening `architecture.svg` in draw.io round-trips for editing. Both are regenerated by
> [`diagrams/build_diagram.py`](diagrams/build_diagram.py).*

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
- **DNS + TLS:** for the POC, free **DuckDNS** dynamic DNS (not Route53) + **Let's Encrypt**.
  See [infrastructure.md](infrastructure.md) §4 for the DuckDNS wildcard approach and caveats.
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

**Resolved (2026-06-20):**
- ~~Test endpoints~~ → **2 local Win10/11 VMs** (Hyper-V/VirtualBox).
- ~~Domain name~~ → free **DuckDNS** for the POC (see infrastructure.md §4 caveats).

**Still open:**
- **Single instance vs. split:** co-host Fleet + TRMM on one EC2 (cheap) or separate
  (cleaner)? Recommendation: separate small instances; single-instance variant documented.
- **Admin access path:** SSO? VPN? IP allowlist for the admin UIs? (Default: IP allowlist.)
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

## 14. Scaling to ~10,000 & enrollment at scale

- **Compliance plane (Fleet):** scales horizontally — multiple stateless Fleet app nodes
  behind a load balancer, with a managed MySQL + Redis. Comfortable into the tens of thousands.
- **Management plane (Tactical RMM):** chosen for a ~500-device org; at ~10k it must be
  **load-tested and likely run as multiple instances** (e.g., sharded by region/business unit),
  or re-evaluated. This is the key scale risk to validate early.
- **High availability:** run components in duplicate (no single point of failure) with a
  resilient database and cache; adds modest cost. Production sizing is a defined phase (see
  requirements NFR-1 and the roadmap).
- **Enrollment at scale — two tracks:** (A) **new machines** get agents **pre-installed in the
  gold/build image** and enroll zero-touch on first boot (the ~1,000 new-machine milestone;
  imaging must not capture an already-enrolled identity — enroll on first boot for unique ids);
  (B) **existing machines** are onboarded by pushing agents via GPO / Intune / SCCM / PDQ.
  Details in [agent-install-guide.md](agent-install-guide.md) §10 and [roadmap.md](roadmap.md).
