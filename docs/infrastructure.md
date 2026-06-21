# Infrastructure & Setup Plan (POC: M0–M1)

**Status:** Draft · **Last updated:** 2026-06-20
**Companion to:** [design.md](design.md) (§10 AWS topology) and [requirements.md](requirements.md).
**Scope:** Stand up the AWS control plane and install the two tools, ready to enroll the
2 test endpoints. Covers milestones **M0** (foundations) and **M1/M4** (tools up).

> **Confirmed POC choices** (2026-06-20):
> - **DNS/TLS:** free **dynamic DNS (DuckDNS)** — *not* Route53. See §4 for the caveats this
>   creates with Tactical RMM's three-subdomain requirement.
> - **Test endpoints:** **2 local Win10/11 VMs** (Hyper-V / VirtualBox) phoning home to AWS.
> - **Sequencing:** refine docs before provisioning — no Terraform applied yet.

---

## 1. Target topology (POC)

```
   DuckDNS (free DDNS)            AWS account / region (e.g. us-east-1)
   *.nbcepm.duckdns.org           ┌──────────────────────────────────────────────┐
     ├ rmm.   ─┐                  │  VPC 10.20.0.0/16                              │
     ├ api.   ─┼─────────────────►│   public subnet 10.20.1.0/24                   │
     ├ mesh.  ─┘                  │   ┌───────────────────┐  ┌──────────────────┐ │
     └ fleet. ───────────────────►│   │ EC2: tactical-rmm │  │ EC2: fleet        │ │
   (each → same/two Elastic IPs)  │   │ Ubuntu 22.04 LTS  │  │ Ubuntu 22.04 LTS  │ │
                                  │   │ t3.large          │  │ t3.medium         │ │
                                  │   │ PG+Redis+NATS+Mesh│  │ MySQL+Redis+Fleet │ │
                                  │   └───────────────────┘  └──────────────────┘ │
                                  │   SG: 443 in (agents) + admin-ip; SSH via SSM  │
                                  └──────────────────────────────────────────────┘
        ▲ outbound 443                                   ▲ outbound 443
   ┌────────────┐                                   ┌────────────┐
   │ Win10 VM   │  (fleetd + TRMM agent)            │ Win11 VM   │
   └────────────┘                                   └────────────┘
```

DuckDNS replaces Route53: a single DuckDNS domain `nbcepm.duckdns.org` plus its wildcard
covers the `rmm./api./mesh./fleet.` hostnames the tools need. Elastic IPs keep those records
(and the TLS certs) stable across instance restarts.

**Why two instances:** Tactical RMM expects a clean host with its own three subdomains and
manages its own Postgres/Redis/NATS/MeshCentral; co-tenanting Fleet's MySQL/Redis on the
same box invites port/dependency conflicts. A single-instance variant is in §7 if cost must
be minimized.

## 2. Prerequisites (M0)

- [ ] AWS account with admin access; pick a region (default **us-east-1**).
- [ ] **DuckDNS account** + a domain (e.g. `nbcepm`) and its update **token** (free, GitHub/
      Google sign-in). Confirm the wildcard pattern works (see §4 verification step).
- [ ] Local hypervisor with **Win10** + **Win11** VMs (2 GB+ RAM each), internet egress.
- [ ] Local toolchain: `awscli`, `terraform` (or OpenTofu), an SSH key (or rely on SSM).
- [ ] Decide admin access method (§5): SSM Session Manager for shell; IP allowlist for the UIs.

## 3. Network design

| Item | Value | Rationale |
|---|---|---|
| VPC CIDR | `10.20.0.0/16` | Roomy, non-overlapping. |
| Public subnet | `10.20.1.0/24` | POC servers are internet-reachable for agent phone-home. |
| IGW + route | default route to IGW | Agents reach servers over the internet. |
| Private subnet (later) | `10.20.10.0/24` | For RDS if we externalize DBs post-POC. |

**Security groups**

| SG | Inbound | Outbound |
|---|---|---|
| `sg-rmm` | 443 from `0.0.0.0/0` (agents); 4222 (NATS) as TRMM requires; **80 from `0.0.0.0/0`** for Let's Encrypt HTTP-01; admin from `<your-ip>/32` | all |
| `sg-fleet` | 443 from `0.0.0.0/0` (agents); **80** for HTTP-01; admin from `<your-ip>/32` | all |

No inbound 22 — shell via **SSM Session Manager** (instance role + agent), avoiding a public
SSH surface (NFR-3). Port 80 is only needed transiently for certbot HTTP-01 challenges; it
can be closed after issuance if using DNS-01 renewals instead.

## 4. DNS & TLS — DuckDNS specifics (important)

Tactical RMM needs **three hostnames** (`rmm.`, `api.`, `mesh.`) plus Fleet's `fleet.`,
each resolving to the server and each holding a valid TLS cert. DuckDNS makes this work, but
with caveats worth understanding up front:

**How DuckDNS satisfies the requirement**
- DuckDNS gives you one label, `nbcepm.duckdns.org`, pointed at an IP via its API/token.
- DuckDNS **also resolves the wildcard** `*.nbcepm.duckdns.org` to that same IP, so
  `rmm.nbcepm.duckdns.org`, `api.…`, `mesh.…`, `fleet.…` all resolve without extra records.
- Point `nbcepm` at the **tactical-rmm Elastic IP**; for the separate fleet instance, either
  (a) give Fleet its own DuckDNS domain `nbcfleet.duckdns.org`, or (b) co-host (§7) so one IP
  serves all four. **Recommendation:** two DuckDNS domains, one EIP each — clean and free.

**TLS options**
- **HTTP-01 (simplest):** certbot proves control of each concrete hostname over port 80.
  Works fine since each subdomain resolves to the server. TRMM's installer does this for you.
- **DNS-01 wildcard (robust):** issue `*.nbcepm.duckdns.org` via a DuckDNS certbot DNS plugin
  (TXT-record challenge). Avoids needing port 80 and covers all subdomains with one cert.

**Caveats (POC-acceptable, document them)**
- DuckDNS is best-effort/free — occasional propagation lag and **Let's Encrypt rate limits**
  (5 duplicate certs/week) can bite during repeated installs; if you re-run installs, use
  `--staging` first.
- Tactical RMM **officially recommends a real, owned domain**; DuckDNS is a known-working POC
  workaround, not their supported path. We accept this for the POC (NFR-5 cost) and revisit a
  cheap real domain before any non-POC use.
- DuckDNS records are updated via its **API/token**, not Terraform — so DNS is a small
  scripted step, not part of the `terraform apply` (see §8).

**Verification step (do this first, before installing):** create the DuckDNS domain, point it
at a throwaway IP, and confirm `dig rmm.nbcepm.duckdns.org` and `dig anything.nbcepm.duckdns.org`
both resolve. If the wildcard doesn't resolve, fall back to registering separate DuckDNS
domains per subdomain or a cheap real domain.

## 5. Access & security baseline

- **Shell:** SSM Session Manager only; no public SSH (NFR-3).
- **Web UIs:** restrict to your admin IP/VPN via SG; strong admin creds; enable MFA where
  supported.
- **Secrets:** Fleet enroll secret, TRMM agent token, and the **DuckDNS token** are
  credentials — keep out of git (already in `.gitignore`); store in AWS SSM Parameter Store /
  Secrets Manager.
- **At rest:** EBS encryption on; enable RDS encryption if/when DBs move to RDS.
- **Audit:** enable CloudTrail; both tools keep their own action logs (NFR-6).

## 6. Install runbooks (high-level)

### 6a. Tactical RMM (M1) — `tactical-rmm` instance
1. Launch Ubuntu 22.04 LTS `t3.large`, attach EIP, `sg-rmm`, SSM role, 30 GB gp3 (encrypted).
2. DuckDNS: set `nbcepm` → the EIP; confirm `rmm./api./mesh.nbcepm.duckdns.org` resolve.
3. Create a non-root sudo user (TRMM installer refuses root).
4. Run the official installer (`install.sh`); supply domain `nbcepm.duckdns.org` and the
   rmm/api/mesh prefixes. It provisions Postgres, Redis, NATS, MeshCentral, Nginx, and
   Let's Encrypt certs, then prints the admin URL + credentials.
5. Log in to `rmm.…`, complete first-run, create the first **agent install** token.
   → enables **UC-01 / FR-E1**.

### 6b. FleetDM (M4) — `fleet` instance
1. Launch Ubuntu 22.04 LTS `t3.medium`, attach EIP, `sg-fleet`, SSM role, 20 GB gp3 (encrypted).
2. DuckDNS: set `nbcfleet` → the EIP (or reuse a `fleet.` subdomain if co-hosting).
3. Install via Docker Compose (Fleet + MySQL + Redis) or the `.deb`; get a cert (certbot).
4. Run `fleetctl setup`, create the admin user, generate an **enroll secret** and a `fleetd`
   package for Windows. → enables **UC-01 / FR-E1** on the Fleet side.

(Endpoint enrollment itself is **M2/M5** — agents on the 2 VMs — covered in the rollout plan.)

## 7. Cost-minimized variant (optional)

If two running instances is too costly for a part-time POC:
- Run **both tools on one `t3.large`** via Docker Compose with distinct ports/subdomains
  (`rmm./api./mesh./fleet.` all under one DuckDNS domain → one EIP); more brittle, document
  the port map, **or**
- Stop instances between test sessions (EIP + DuckDNS record persist; certs renew on start).

Rough run cost (us-east-1, on-demand, 24×7): `t3.large` ≈ \$60/mo, `t3.medium` ≈ \$30/mo +
EBS/EIP — order of **\$90–100/mo** if left running; far less if stopped between sessions.
DuckDNS is free, so domain cost is \$0 for the POC.

## 8. Terraform layout (proposed — to build when we start M0)

```
infra/
├── main.tf            # provider, backend (S3 state later)
├── network.tf         # VPC, subnet, IGW, routes
├── security.tf        # security groups, SSM instance role
├── instances.tf       # tactical-rmm + fleet EC2, EIPs
├── variables.tf       # region, admin_ip, instance sizes
├── outputs.tf         # EIPs (to plug into DuckDNS)
└── terraform.tfvars   # values (gitignored — holds your admin IP)
```

DNS is **not** Terraform-managed (DuckDNS is updated via its API/token); after `apply`, take
the EIP outputs and set the DuckDNS records with a one-line `curl` to the DuckDNS update URL.
The tool installs in §6 stay as manual runbook steps for the POC (interactive installers); a
later pass can wrap them in `user_data` / Ansible for full reproducibility.

## 9. Definition of done (M0–M1/M4)

- [ ] DuckDNS domain(s) live; `rmm./api./mesh.` (+ `fleet.`) resolve to the EIP(s).
- [ ] `tactical-rmm` reachable at `https://rmm.…` with valid TLS; admin login works.
- [ ] `fleet` reachable at `https://fleet.…` with valid TLS; admin login works.
- [ ] An agent install token (TRMM) and an enroll secret + `fleetd` package (Fleet) exist.
- [ ] Shell access only via SSM; web UIs IP-restricted. → ready for **M2/M5** enrollment.
