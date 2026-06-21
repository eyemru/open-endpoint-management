# Requirements & Use Cases

**Status:** Draft · **Last updated:** 2026-06-20
**Companion to:** [design.md](design.md) — every requirement here traces to a design section (see the traceability matrix in the appendix).

This document grounds the design in concrete needs: who uses the system, what they are
trying to accomplish, and the functional / non-functional / compliance requirements that
follow. It is a *semi-requirements* document — enough rigor to validate the design and scope
the POC, without the ceremony of a formal SRS.

---

## 1. Grounding scenario

> **Northbridge Community Bank** is a ~400-person regional bank. IT is a small team: one IT
> manager, two endpoint/desktop engineers, and a part-time security/compliance officer.
> They run **~500 Windows assets** — ~350 in-office desktops (Windows 10/11) and ~150
> laptops that staff take home and to branch offices. There is no budget for Intune,
> Tanium, or PDQ. Today, patching is manual and inconsistent, nobody can answer "is every
> laptop encrypted and up to date?" quickly, and audits are a fire drill of spreadsheets.

The bank needs to (a) **know** the state of every device, (b) **prove** compliance for
audits, and (c) **fix** drift — patch and configure devices — including laptops that are
rarely on the office network.

## 2. Actors

| Actor | Description | Primary interest |
|---|---|---|
| **Endpoint Engineer** (primary) | Day-to-day operator. Enrolls devices, runs patches, deploys software, fixes drift. | Inventory + remediation. |
| **Security / Compliance Officer** | Owns audit posture. Reads compliance reports, defines policy. | Compliance visibility + evidence. |
| **IT Manager** | Oversight. Wants fleet-level health and trends. | Dashboards + reporting. |
| **Employee (Device Owner)** | Uses the device. Mostly passive; should not be disrupted. | Minimal interruption; patches in maintenance windows. |
| **System / Automation** | Scheduled scans, policy evaluation, patch windows, alerts. | Reliable unattended operation. |

## 3. Use cases

Each use case lists the trigger, the actor, the happy path, and the design components that
realize it.

| ID | Use case | Actor | Realized by (design) |
|---|---|---|---|
| **UC-01** | **Enroll a device** — install agent(s), device appears in inventory. | Engineer | fleetd + TRMM agent, enrollment secrets (§5, §6) |
| **UC-02** | **View asset inventory & details** — owner, hardware, OS/build, installed software. | Engineer, Manager | Fleet inventory + TRMM inventory (§5, §6) |
| **UC-03** | **Identify owner / assignment** — map a device to the employee who has it. | Engineer | Asset metadata / tags (§6, NFR auditability) |
| **UC-04** | **Evaluate compliance posture** — pass/fail per device against policy. | Compliance Officer | Fleet policies (§7) |
| **UC-05** | **Detect missing patches** — surface devices with pending critical/security updates. | Engineer | Fleet policy + TRMM patch status (§7, §8) |
| **UC-06** | **Push an OS security patch** — apply a Windows update in a maintenance window. | Engineer | TRMM patch management (§8) |
| **UC-07** | **Deploy / update software** — install or update an app (e.g., 7-Zip, Chrome). | Engineer | TRMM + Chocolatey (§8) |
| **UC-08** | **Run a remediation script** — fix a misconfiguration (e.g., enable BitLocker). | Engineer | TRMM scripting (§8) |
| **UC-09** | **Alert on drift / offline** — notify when a device goes non-compliant or stops checking in. | System → Engineer | TRMM checks/alerts (§5, §8) |
| **UC-10** | **Track remediation outcome** — confirm a patch/script succeeded; retry on failure. | Engineer, System | TRMM job results (§6, §8) |
| **UC-11** | **Remediate a roaming/offline laptop** — queue work; it applies next time the device phones home. | System | Phone-home pull model (§3, §6) |
| **UC-12** | **Decommission a device** — retire an asset, stop counting it, revoke access. | Engineer | Lifecycle (FR-E group, §6) |
| **UC-13** | **Produce an audit report** — export fleet compliance evidence for a point in time. | Compliance Officer | Fleet reporting/API (§7, NFR auditability) |

## 4. Functional requirements

> Priority: **P0** = required for the thin-slice POC · **P1** = POC-desirable · **P2** = post-POC.

### Inventory & visibility (FR-I)
- **FR-I1** (P0) Collect per-device telemetry: hostname, OS name/edition/build, hardware
  (CPU/RAM/disk), serial, last-seen, IP. → UC-02
- **FR-I2** (P0) Collect installed software inventory per device. → UC-02
- **FR-I3** (P0) Collect patch status (installed updates, pending updates). → UC-05
- **FR-I4** (P1) Record device **owner / assignment** metadata. → UC-03
- **FR-I5** (P1) Show last check-in time and online/offline state. → UC-09
- **FR-I6** (P2) Surface known-vulnerability data for installed software. → UC-04

### Compliance (FR-C)
- **FR-C1** (P0) Define a policy as a pass/fail check evaluated per device. → UC-04
- **FR-C2** (P0) Report compliance status per device and aggregate across the fleet. → UC-04
- **FR-C3** (P1) Cover the baseline policy set in §6 (BitLocker, Defender, firewall, patch
  currency, screen lock, required software). → UC-04
- **FR-C4** (P2) Export/point-in-time compliance evidence for audits. → UC-13

### Remediation & patching (FR-R)
- **FR-R1** (P0) Push a specific Windows OS security patch to a target device. → UC-06
- **FR-R2** (P0) Install/update a software package (via Chocolatey). → UC-07
- **FR-R3** (P1) Run an arbitrary remediation script on a target device. → UC-08
- **FR-R4** (P1) Approve/auto-approve patches by classification (Critical/Security). → UC-06
- **FR-R5** (P1) Apply patches within a **maintenance window** and honor a reboot policy. → UC-06
- **FR-R6** (P1) Report job success/failure and retry failed jobs. → UC-10

### Enrollment & lifecycle (FR-E)
- **FR-E1** (P0) Enroll a device using a secret/token; it appears in inventory. → UC-01
- **FR-E2** (P2) Decommission/retire a device and revoke its access. → UC-12

### Alerting & reporting (FR-A)
- **FR-A1** (P1) Alert when a device is offline beyond a threshold. → UC-09
- **FR-A2** (P1) Alert when a device fails a compliance policy. → UC-09
- **FR-A3** (P1) Fleet-level dashboard of health/compliance for the IT Manager. → UC-02

### Access & administration (FR-AD)
- **FR-AD1** (P0) Admin access to both control planes over TLS only. → §9, §10
- **FR-AD2** (P1) Restrict admin UI access (SSO / VPN / IP allowlist). → §9, open Q §12
- **FR-AD3** (P2) Role separation (engineer vs. compliance read-only). → §9

## 5. Non-functional requirements (NFR)

| ID | Requirement | Rationale / target |
|---|---|---|
| **NFR-1 Scale** | Support ~500 endpoints. | POC proves on 2; design must not preclude 500. → §3 |
| **NFR-2 Roaming** | Work for laptops off the corporate network — **outbound 443 only**, no inbound/VPN to the device. | Core constraint. → §3, §6, UC-11 |
| **NFR-3 Security** | TLS everywhere; protect enrollment secrets; lock down SYSTEM-privileged agents and admin UIs; encrypt data at rest/in transit. | Bank context. → §9 |
| **NFR-4 Self-hostable / portable** | Run on AWS for POC; portable to on-prem. | Stated constraint. → §10 |
| **NFR-5 Cost** | Open-source-first; no per-seat licensing. | No tooling budget. → §4, §9 (license review) |
| **NFR-6 Auditability** | Actions (patch, script, enrollment) are logged and attributable. | Audit readiness. → §9, UC-13 |
| **NFR-7 Low user disruption** | Remediation respects maintenance windows / reboot policy. | Don't interrupt staff. → FR-R5 |
| **NFR-8 Availability (POC)** | Best-effort single-instance; HA is out of scope. | POC targets correctness, not uptime. → §2 non-goals |

## 6. Baseline compliance policy set (the "definition of compliant")

This is the concrete policy set FR-C3 refers to (mirrors design §7). Full specs — osquery
queries, severity, and remediation per policy — are in
[compliance-policies.md](compliance-policies.md).

| Policy | Compliant when | Maps to |
|---|---|---|
| Disk encryption | BitLocker enabled on OS volume | UC-04 |
| Antivirus | Defender real-time on; signatures < 3 days old | UC-04 |
| Firewall | Windows Firewall on for all profiles | UC-04 |
| Patch currency | No pending Critical/Security updates; build is current or N-1 | UC-04/05 |
| Screen lock | Lock timeout ≤ 15 min | UC-04 |
| Required software | Approved EDR/VPN present | UC-04 |
| Local admins | Limited to approved accounts | UC-04 |
| Disk space | Free space ≥ threshold (so patches can install) | UC-04 |

## 7. Acceptance criteria — thin-slice POC

The POC (design §11) is **done** when, against **2 test endpoints**:

1. Both devices are enrolled and visible with inventory (FR-I1/2/3, FR-E1). → M2/M5
2. At least **one compliance policy** reports pass/fail per device (FR-C1/2). → M6
3. At least **one OS security patch** is pushed and confirmed applied (FR-R1, FR-R6). → M3
4. At least **one software package** is deployed via Chocolatey (FR-R2). → M3
5. A failing policy can be **handed off to a remediation action** (FR-R3). → M7
6. All control-plane access is over TLS (FR-AD1). → M1/M4

## 8. Out of scope (POC)

macOS/Linux endpoints · zero-touch/Autopilot enrollment · device wipe · production HA &
scale tuning · automated policy→remediation orchestration (manual hand-off is fine for POC).
See design §2 non-goals.

---

## Appendix: Traceability matrix (requirements → design)

| Requirement group | Design section(s) |
|---|---|
| Inventory (FR-I) | §5 components, §6 architecture/data flow |
| Compliance (FR-C) | §7 compliance policy examples |
| Remediation/patching (FR-R) | §8 patch & software examples |
| Enrollment/lifecycle (FR-E) | §5, §6 data flow |
| Alerting/reporting (FR-A) | §5 (TRMM checks/alerts), §7 (Fleet) |
| Access/admin (FR-AD) | §9 security, §10 AWS topology |
| NFRs | §3 constraints, §9 security, §10 topology, §2 non-goals |
| Acceptance criteria | §11 POC plan (milestones M1–M7) |
