# Endpoint Management Program — Business & Technical Brief

**Audience:** Program / project managers, department leads, and IT decision-makers
**Purpose:** Explain — in business terms — what this initiative deploys into your environment,
what the organization gets, how data and risk are handled, and what it costs.
**Status:** Draft for review · **Reading time:** ~10 minutes

---

## 1. Executive summary

Most organizations can't quickly answer a simple question: *"Are all of our computers
encrypted, patched, and secure right now?"* This program delivers that answer — and the
ability to act on it — using **proven open-source software**, with **no per-device licensing
fees**.

We deploy a small, self-hosted system that:
- **Knows** every Windows computer we own (an always-current inventory),
- **Proves** whether each one meets our security policy (pass/fail, on demand), and
- **Fixes** problems remotely — pushing security patches and software, at scale.

It runs on infrastructure **we control** — our own servers, or a cloud account if we operate
one — so sensitive device data never leaves the organization. A working proof-of-concept has
already been built and validated end-to-end.

---

## 2. The problem and the outcome

| Today (without this) | With this program |
|---|---|
| No single, current list of our computers | Live inventory of every device: owner, OS, software, patch level |
| Patching is manual and inconsistent | Security patches pushed centrally, on a schedule, to any device |
| Compliance evidence is a manual scramble at audit time | Compliance status (encryption, antivirus, firewall, patching) reported on demand |
| Roaming laptops are hard to reach and easy to miss | Laptops managed anywhere with internet — no office network or VPN needed |
| Commercial tools cost per device, every year | Open-source: no license fees; cost stays flat as we grow |

**Business outcome:** lower security risk, faster audits, and materially lower cost than
commercial endpoint-management suites.

---

## 3. What gets deployed in your environment

Two parts: a small **central system** (servers) and a **lightweight agent** on each computer.

### 3a. Central system — two small servers
| Server | Business role | Plain description |
|---|---|---|
| **Management server** (Tactical RMM) | "Fix it" | Pushes patches/software, runs maintenance, provides remote IT support. IT staff use a web dashboard. |
| **Compliance server** (FleetDM) | "Prove it" | Continuously checks each device against our security policy and reports pass/fail. Web dashboard for IT/security. |

- These run on standard Linux servers **sized to the fleet** — a modest VM for a pilot;
  larger, and **run in duplicate for high availability**, at full scale. They can live on
  **existing on-premises hardware, new hardware, or a cloud account (AWS/Azure/GCP) if we
  operate one** — **no specific cloud is required or assumed.**
- Access is over encrypted web (HTTPS). Only IT/security staff log in.

### 3b. On each Windows computer — lightweight agents
Small background programs (a few MB) that start automatically and run quietly:
- a **management agent** (inventory + patching + software + remote support), and
- a **compliance agent** (read-only checks of the device's security settings).

**Impact on the device and the user:**
- Minimal CPU/memory; **no interruption to the person using the computer**.
- Patches and reboots happen in **approved maintenance windows**, not mid-workday.
- The device makes only **outbound** secure connections to our servers — **nothing on the
  internet can reach into the laptop**, so roaming devices stay safe.
- *Governance note:* like all endpoint-management tools, the management agent runs with
  system-level privileges so it can install updates. That capability is controlled and
  audited (see §5).

---

## 4. What the business gets (capabilities → value)

| Capability | What it means for the business |
|---|---|
| **Asset inventory** | Always know what we own and who has it — for security, audits, budgeting, and support. |
| **Compliance posture** | Answer "are we secure/compliant?" in minutes, with evidence — instead of a spreadsheet fire-drill at audit time. |
| **Patch & vulnerability management** | Close security holes fast and consistently across the whole fleet — the #1 way to prevent breaches. |
| **Software deployment** | Roll out or update approved software centrally, no desk visits. |
| **Remote support** | IT can assist any device securely, wherever it is. |
| **Roaming coverage** | Laptops off the network are managed the same as desktops. |

**Example of what "compliant" means** (fully configurable to our policy): disk encryption on,
antivirus active and current, firewall on, no missing critical security updates, screen locks
when unattended, required security software present.

---

## 5. Data, privacy, and security (what leaders ask about)

**What data is collected:** device facts — hardware, operating system and patch level,
installed software, and security settings (e.g., "encryption on/off," "firewall on/off").

**What is *not* collected:** the system does **not** read personal files, email, or keystrokes,
and does not watch the screen. Remote-support sessions (where staff can see a screen) are
**initiated deliberately by IT** and are auditable — not always-on surveillance.

**Where the data lives:** on **our** servers — in our datacenter, or a cloud account we
operate. It does **not** go to a third-party vendor's cloud.

**Security posture:**
- All traffic is **encrypted (TLS)**, the same protection used for online banking.
- Endpoints expose **no inbound access** — they only reach out to our servers.
- The central system is powerful (it can update every device), so it is treated as
  **critical infrastructure**: restricted admin access, multi-factor login, and audit logging
  of actions. Data is encrypted at rest.

---

## 6. Deployment options and cost

**Software licensing:** the tools are open-source — **$0 in per-device license fees**. A
commercial equivalent typically runs **$3–7 per device per month**; at **~10,000 devices**
that is roughly **$360,000–$840,000 per year** (illustrative). This is the largest, most
certain saving — and because commercial pricing is per-device while our cost is
infrastructure-based, **the savings gap widens as the fleet grows**.

**Infrastructure is sized to the fleet and to our high-availability needs** — set by a short
**sizing exercise**, not a fixed number. Crucially, it is **infrastructure-based, not
per-device**, so unlike commercial licensing it does **not** grow linearly as we add devices.
Expressed as footprint rather than a speculative price:

| Stage | If hosted in a cloud we operate | If hosted on our own servers |
|---|---|---|
| **Proof of concept** (built) | a small monthly cloud subscription (two small VMs) | ≈ **$0** on spare capacity (two small VMs) |
| **Production · ~10,000 · highly available** | an ongoing monthly cloud subscription, sized in the exercise | ≈ **$0 additional** if we repurpose spare virtualization capacity — otherwise roughly **4–8 servers (Medium–Large), spread across ≥ 2 hosts** for high availability |

*Server-size guide:* **S** ≈ 2 CPU / 4 GB · **M** ≈ 4 CPU / 8–16 GB · **L** ≈ 8+ CPU / 32+ GB.
Figures are planning estimates, finalized by the sizing exercise; cost varies with the level of
high availability and data retention. The main ongoing non-infrastructure cost is a modest
amount of **existing IT staff time**.

---

## 7. Rollout plan, timeline, and what we need from you

| Phase | Scope | Rough duration | Goal |
|---|---|---|---|
| **1. Proof of concept** ✅ done | 1–2 test devices | (complete) | Prove the full loop works |
| **2. Sizing & HA design** | — | ~1 week | Size servers/database for the 10k target + high availability |
| **3. Pilot** | **50 devices** | 2–4 weeks | Validate end-to-end; tune policies |
| **4. First milestone** | **~1,000 newly acquired computers** | phased | Onboard new machines **shipped agent-ready** (zero-touch, see below) |
| **5. Scale-up** | the **existing** fleet, toward **~10,000** total | phased, months | Push agents to in-service machines; full coverage + reporting |

### How devices are enrolled — two paths
- **New machines:** they arrive **ready to manage** — the software is built into our standard
  computer image, so a new machine registers itself the first time it's turned on (no manual
  setup, no desk visit). This is the ~1,000-machine milestone and the model for all future
  purchases.
- **Existing machines:** onboarded gradually, in **controlled waves**. The method depends on
  the tools we already have; **if we have none today, setting up a simple way to distribute
  the software is an early step** — not something we assume is already in place.

*Execution detail (imaging, distribution methods, and the assessment behind them) lives in the
[Implementation & Rollout Plan](implementation-plan.md), so this brief stays high-level.*

**What the program needs from the organization:**
- A decision on **where to host** — existing on-prem servers, new hardware, or a cloud account
  if we operate one (no cloud is required; server sizing comes from Phase 2).
- **DNS names** for the servers and the ability to issue certificates.
- For new machines: inclusion of the agents in the **standard build/imaging process**.
- For existing machines: **a way to distribute the agents** — existing tooling (Group Policy /
  Intune / SCCM) if we have it, or agreement on a **bootstrap method** if we don't.
- A **pilot group** and an **approved maintenance-window** policy.
- A named **IT owner** for day-to-day operation.

---

## 8. Risks, assumptions, and dependencies (the honest view)

| Item | Notes / mitigation |
|---|---|
| **Open-source support model** | Large communities + optional paid support; we also fully own and control the system. |
| **Licensing review** | One tool (Tactical RMM) is "source-available" with usage terms — a quick legal review is recommended before full rollout. |
| **Central system is high-value** | It can act on every endpoint; mitigated by locking down admin access, MFA, and auditing (treated as critical infrastructure). |
| **Internet required (standard install)** | Servers pull software from the internet during setup. An isolated/air-gapped deployment is possible but is additional work. |
| **Endpoint agent privilege** | System-level by necessity (to patch); governed and audited. |
| **Scale & high availability (~10k)** | Servers must be sized and made redundant for the full fleet — a planning task before scale-up. One component scales easily; the other must be validated at that scale and may run in several parts. Cost grows with scale + HA (see §6). *Detail: Implementation Plan / design.* |
| **Reaching existing machines** | We do **not assume** central software-distribution tooling already exists — its absence is often *why* this program is needed. Onboarding existing devices may require first setting up a simple way to distribute the software; this is assessed early. New machines (built ready-to-manage) are unaffected. |
| **Production hardening** | Backups, high availability, monitoring, and automated patch policies are planned items beyond the pilot. |

---

## 9. Glossary & further reading

**Glossary**
- **Endpoint** — a staff computer (desktop or laptop).
- **Agent** — a small program on each computer that reports in and carries out tasks.
- **Control plane** — the central servers/dashboards IT uses.
- **Compliance policy** — a rule a device must meet (e.g., "disk is encrypted").
- **Patch** — a security/bug fix from the software vendor (e.g., Microsoft).

**Further reading (in this project)**
- Executive slide deck — `presentation/` (for a live briefing).
- **How we execute it — `docs/implementation-plan.md`** (phases, enrollment, sizing, assessment).
- Technical design & detailed architecture — `docs/design.md`, `docs/architecture.md`.
- What's built vs. still planned — `docs/roadmap.md`.

---
*To produce the PDF after refinement: open in VS Code and “Export/Print to PDF,” or run
`pandoc docs/business-brief.md -o business-brief.pdf`.*
