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

- Each is a modest Linux server (≈ 2 CPU / 4 GB RAM). They run **wherever we prefer** —
  existing on-premises hardware, new hardware, or a cloud account (AWS/Azure/GCP) if we
  operate one. **No specific cloud is required or assumed.**
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

**Software licensing:** the tools are open-source — **$0 in per-device license fees** (a
commercial equivalent typically runs **$3–7 per device per month** — roughly **$18k–42k/year
for 500 devices**; figures illustrative).

**Where it runs is our choice** — the system needs only **two standard Linux servers**
(≈ 2 CPU / 4 GB RAM each) and does **not** depend on any particular cloud. We do **not** need
an existing cloud account:

| Hosting option | Approx. infrastructure cost | Notes |
|---|---|---|
| **Repurpose existing on-prem servers/VMs** | ~**$0 additional** | If we have spare capacity; everything stays in our datacenter. |
| **New on-prem hardware** | one-time hardware cost | If dedicated servers are preferred. |
| **A cloud account — *only if we already operate one*** (AWS/Azure/GCP) | ~**$60–100/month** | Fastest to stand up, no hardware to buy; optional, not assumed. |

**Key point:** cost is essentially **flat** whether we manage 50 or 500 devices — it doesn't
scale per-device like commercial licensing. The main ongoing investment is a modest amount of
**existing IT staff time**.

---

## 7. Rollout plan, timeline, and what we need from you

| Phase | Scope | Rough duration | Goal |
|---|---|---|---|
| **1. Proof of concept** ✅ done | 1–2 test devices | (complete) | Prove the full loop works |
| **2. Pilot** | ~50 devices across teams | 2–4 weeks | Validate at scale; tune policies |
| **3. Fleet rollout** | All ~500 devices | Phased, weeks | Full coverage + reporting |

**What the program needs from the organization:**
- A decision on **where to host** — existing on-prem servers, new hardware, or a cloud account
  if we operate one (the system needs two small Linux servers; no cloud is required).
- **DNS names** for the servers and the ability to issue certificates.
- A **pilot group** of devices/users and an **approved maintenance window** policy.
- Sign-off to **deploy the agents** to managed devices (typically via existing software-
  distribution or group policy).
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
| **Production hardening** | Backups, high availability, and automated patch policies are planned items beyond the pilot. |

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
- Technical design & detailed architecture — `docs/design.md`, `docs/architecture.md`.
- What's built vs. still planned — `docs/roadmap.md`.

---
*To produce the PDF after refinement: open in VS Code and “Export/Print to PDF,” or run
`pandoc docs/business-brief.md -o business-brief.pdf`.*
