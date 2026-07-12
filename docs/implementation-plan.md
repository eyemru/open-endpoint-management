# Implementation & Rollout Plan

**Audience:** Program / project managers, TPMs, and the technical leads executing the rollout.
**Purpose:** *How* we get from proof-of-concept to ~10,000 managed endpoints — the phases,
the enrollment approach, sizing/HA, and the assessments and decisions required along the way.

**Where this sits:** business context is in [business-brief.md](business-brief.md); the deep
technical detail is in [design.md](design.md) / [architecture.md](architecture.md) and the
exact install steps in [agent-install-guide.md](agent-install-guide.md). This document ties
those together at the program level.

---

## 1. Phased rollout (with exit criteria)

| Phase | Scope | Key activities | Exit criteria |
|---|---|---|---|
| **0. Proof of concept** ✅ | 1–2 devices | Stand up both planes; prove see/prove/fix | Done — all criteria met |
| **1. Assessment & sizing** | — | Run the §2 assessment; size servers + design HA for 10k | Sizing + HA design signed off; hosting chosen |
| **2. Build** | — | Provision hardened control planes (HA); backups + monitoring | Both planes live, resilient, monitored |
| **3. Pilot** | 50 devices | Enroll, tune compliance policies, validate patch/remediation | Policies stable; playbook documented |
| **4. First milestone** | **~1,000 new computers** | Zero-touch enrollment via the build image (Track A) | ~1,000 auto-enrolled and reporting |
| **5. Scale-up** | Existing fleet → **~10,000** | Onboard in waves (Track B); ongoing operations | Full coverage + compliance reporting |

## 2. Environment assessment — confirm, don't assume

This program is often needed *because* structured tooling is missing, so validate these
early; each answer drives sizing, enrollment method, and effort:

- **Identity:** Active Directory present? (enables logon-script distribution / policy)
- **Existing management/distribution:** any Intune / SCCM / GPO / RMM / PDQ in place today?
- **Imaging:** is there a standard build / gold image we can add agents to?
- **Patching today:** how are updates applied now (manual? WSUS? none)?
- **Hosting capacity:** spare on-prem virtualization, new hardware, or a cloud we operate?
- **Network:** can endpoints make outbound HTTPS (443) to the servers? any air-gapped segments?
- **DNS + certificates:** can we create DNS names and issue TLS certs (public or internal CA)?
- **OS mix & admin model:** Windows 10/11 versions; local-admin vs. standard-user policy.

> The result of this assessment is a short sizing/HA design and a chosen enrollment path per
> device population — it is the gate for Phase 2.

## 3. Enrollment approach — two tracks

**Track A — new machines (zero-touch).** Agents are **pre-installed and pre-configured in the
standard build / gold image**; each computer enrolls itself on **first boot**. This is the
~1,000-machine milestone and the target for all future purchases. Key rule: don't capture an
*already-enrolled* agent into the image (clones would collide) — enroll on first boot so each
device gets a unique identity. Exact steps: [agent-install-guide.md](agent-install-guide.md) §10.

**Track B — existing machines.** Method depends on the §2 assessment:
- **If distribution tooling exists** (GPO / Intune / SCCM / PDQ) → push in controlled waves.
- **If not** → bootstrap: an AD logon script, a one-time / self-service installer link, or
  IT-assisted waves for smaller batches. Standing up a basic distribution path is itself a task.

## 4. Scale & high availability (the ~10k design)

Summarized from [design.md](design.md) §14:
- **Compliance plane (Fleet)** scales out horizontally (multiple app nodes + managed database +
  cache + load balancer) — comfortable into the tens of thousands.
- **Management plane (Tactical RMM)** was chosen for a ~500-device org; at 10k it must be
  **load-tested and likely split into multiple instances** (by region/business unit), or
  re-evaluated. **This is the top technical risk to retire early.**
- **HA:** run components in duplicate with a resilient database/cache; sizing + cost come out of
  Phase 1 (see [business-brief.md](business-brief.md) §6 for the cost ranges).

## 5. Prerequisites & dependencies

- Hosting decided and provisioned (on-prem or a cloud we operate).
- DNS names + certificate issuance path (public Let's Encrypt or internal CA).
- Endpoint outbound 443 to the servers.
- For Track A: agents added to the imaging/build process.
- For Track B: a distribution path (existing tooling or a bootstrap).
- Maintenance-window policy; a named IT owner; a licensing review (Tactical RMM terms).

## 6. Roles (light RACI)

| Area | Owner |
|---|---|
| Program coordination, milestones | Program / TPM |
| Control-plane build & operation | IT / endpoint engineering |
| Compliance policy definition | Security / compliance |
| Image integration (Track A) | Desktop / imaging team |
| DNS, certificates, network | Infrastructure / network |

## 7. Key decisions & open questions

- **Where to host** (on-prem existing / new hardware / a cloud we operate).
- **Management plane at 10k:** one large instance, multiple instances, or re-evaluate the tool.
- **Certificate strategy:** public (Let's Encrypt) vs. internal CA (for non-internet-facing servers).
- **Air-gapped segments?** If yes, plan internal mirrors for software/images (added effort).
- **Existing-tooling bootstrap** approach, if no distribution tooling exists today.

## 8. Tracked engineering work

The concrete build items (HA sizing, backups, admin-UI hardening, zero-touch imaging, the
policy→remediation loop, TLS renewal, etc.) are tracked in [roadmap.md](roadmap.md).
