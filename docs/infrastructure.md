# Infrastructure & Setup Plan (POC: M0–M1)

**Status:** Draft · **Last updated:** 2026-06-20
**Companion to:** [design.md](design.md) (§10 AWS topology) and [requirements.md](requirements.md).
**Scope:** Stand up the AWS control plane and install the two tools, ready to enroll the
2 test endpoints. Covers milestones **M0** (foundations) and **M1/M4** (tools up).

> **Two inputs you must supply** (placeholders used until then):
> 1. **Domain** — a real domain/subdomain you control, for DNS + TLS. Placeholder:
>    `*.epm.example-bank.com`. Tactical RMM **will not install** without this.
> 2. **Test endpoints** — assumed **2 local Win10/11 VMs** (Hyper-V/VirtualBox). If you'd
>    rather use AWS WorkSpaces or EC2 Windows Server, say so and I'll adjust.

---

## 1. Target topology (POC)

```
                          AWS account / region (e.g. us-east-1)
                          ┌──────────────────────────────────────────────┐
   Route53 zone           │  VPC 10.20.0.0/16                              │
   epm.example-bank.com   │   public subnet 10.20.1.0/24                   │
     ├ rmm.  ─┐           │   ┌───────────────────┐  ┌──────────────────┐ │
     ├ api.  ─┼──────────►│   │ EC2: tactical-rmm │  │ EC2: fleet        │ │
     ├ mesh. ─┘           │   │ Ubuntu 22.04 LTS  │  │ Ubuntu 22.04 LTS  │ │
     └ fleet. ───────────►│   │ t3.large          │  │ t3.medium         │ │
                          │   │ Postgres+Redis+NATS│  │ MySQL+Redis       │ │
                          │   │ +MeshCentral      │  │ +Fleet server     │ │
                          │   └───────────────────┘  └──────────────────┘ │
                          │   SG: 443 in (agents) + admin-ip; SSH via SSM  │
                          └──────────────────────────────────────────────┘
        ▲ outbound 443                                   ▲ outbound 443
   ┌────────────┐                                   ┌────────────┐
   │ Win10 VM   │  (fleetd + TRMM agent)            │ Win11 VM   │
   └────────────┘                                   └────────────┘
```

**Why two instances:** Tactical RMM expects a clean host with its own three subdomains and
manages its own Postgres/Redis/NATS/MeshCentral; co-tenanting Fleet's MySQL/Redis on the
same box invites port/dependency conflicts. Two small instances are cleaner than one fiddly
one. A single-instance Docker-Compose variant is noted in §7 if cost must be minimized.

## 2. Prerequisites (M0)

- [ ] AWS account with admin access; pick a region (default **us-east-1**).
- [ ] A registered domain or a delegable subdomain → **Route53 hosted zone**.
- [ ] Local hypervisor with **Win10** + **Win11** VMs (2 GB+ RAM each), internet egress.
- [ ] Local toolchain: `awscli`, `terraform` (or OpenTofu), an SSH key (or rely on SSM).
- [ ] Decide admin access method (see §5): SSM Session Manager (recommended) for shell;
      IP allowlist for the web UIs.

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
| `sg-rmm` | 443 from `0.0.0.0/0` (agents); 443 + 4222 (NATS) as TRMM requires; admin from `<your-ip>/32` | all |
| `sg-fleet` | 443 from `0.0.0.0/0` (agents); admin from `<your-ip>/32` | all |

No inbound 22 — shell access via **SSM Session Manager** (instance role + agent), avoiding a
public SSH surface (NFR-3). Tighten agent-facing 443 to known egress IPs only if the fleet
is office-bound (it isn't — laptops roam, so `0.0.0.0/0` on 443 is expected).

## 4. DNS & TLS

Tactical RMM needs **three A records** and a valid cert:

| Record | Points to | Used by |
|---|---|---|
| `rmm.epm.example-bank.com` | tactical-rmm EIP | TRMM web UI |
| `api.epm.example-bank.com` | tactical-rmm EIP | TRMM agent API |
| `mesh.epm.example-bank.com` | tactical-rmm EIP | MeshCentral |
| `fleet.epm.example-bank.com` | fleet EIP | Fleet web UI + agent |

- TLS via **Let's Encrypt** (TRMM's installer automates certbot; Fleet can use certbot or an
  ALB+ACM cert). Use **Elastic IPs** so certs/DNS survive instance restarts.
- All UIs and agent endpoints are **HTTPS-only** (FR-AD1, NFR-3).

## 5. Access & security baseline

- **Shell:** SSM Session Manager only; no public SSH (NFR-3).
- **Web UIs:** restrict to your admin IP/VPN via SG; strong admin creds; enable MFA in each
  tool where supported.
- **Secrets:** Fleet enrollment secret and TRMM agent install token are credentials — keep
  out of git (already in `.gitignore`); store in AWS SSM Parameter Store / Secrets Manager.
- **At rest:** EBS encryption on; if/when we move DBs to RDS, enable RDS encryption.
- **Audit:** enable CloudTrail; both tools keep their own action logs (NFR-6).

## 6. Install runbooks (high-level)

### 6a. Tactical RMM (M1) — `tactical-rmm` instance
1. Launch Ubuntu 22.04 LTS `t3.large`, attach EIP, `sg-rmm`, SSM role, 30 GB gp3 (encrypted).
2. Point `rmm.`/`api.`/`mesh.` A records at the EIP; wait for propagation.
3. Create a non-root sudo user (TRMM installer refuses root).
4. Run the official installer (`install.sh`); it provisions Postgres, Redis, NATS,
   MeshCentral, Nginx, and Let's Encrypt certs, and prints the admin URL + credentials.
5. Log in to `rmm.…`, complete first-run, create the first **deployment/agent install** token.
   → enables **UC-01 / FR-E1**.

### 6b. FleetDM (M4) — `fleet` instance
1. Launch Ubuntu 22.04 LTS `t3.medium`, attach EIP, `sg-fleet`, SSM role, 20 GB gp3 (encrypted).
2. Point `fleet.` A record at the EIP.
3. Install via Docker Compose (Fleet + MySQL + Redis) or the Fleet `.deb`; obtain a cert
   (certbot) for `fleet.…`.
4. Run `fleetctl setup`, create the admin user, generate an **enroll secret** and a
   `fleetd` package for Windows. → enables **UC-01 / FR-E1** on the Fleet side.

(Endpoint enrollment itself is **M2/M5**, covered next — agents installed on the 2 VMs.)

## 7. Cost-minimized variant (optional)

If keeping two instances running is too costly for a part-time POC:
- Run **both tools on one `t3.large`** via Docker Compose with distinct ports/subdomains
  (more brittle; document the port map carefully), **or**
- Stop instances when not testing (EIP + DNS persist; Let's Encrypt renews on next start).

Rough run cost (us-east-1, on-demand, 24×7): `t3.large` ≈ \$60/mo, `t3.medium` ≈ \$30/mo,
plus EBS/EIP — order of **\$90–100/mo** if left running; far less if stopped between sessions.

## 8. Terraform layout (proposed — to build next)

```
infra/
├── main.tf            # provider, backend (S3 state later)
├── network.tf         # VPC, subnet, IGW, routes
├── security.tf        # security groups, SSM instance role
├── instances.tf       # tactical-rmm + fleet EC2, EIPs
├── dns.tf             # Route53 records
├── variables.tf       # region, domain, admin_ip, instance sizes
└── terraform.tfvars   # values (gitignored — holds your domain/IP)
```

`terraform.tfvars` is gitignored (it holds your real domain + admin IP). The installs in §6
remain manual runbook steps for the POC (the tools' installers are interactive); a later
pass can wrap them in `user_data` / Ansible for full reproducibility.

## 9. Definition of done (M0–M1/M4)

- [ ] Route53 zone live with the four records resolving to EIPs.
- [ ] `tactical-rmm` reachable at `https://rmm.…` with valid TLS; admin login works.
- [ ] `fleet` reachable at `https://fleet.…` with valid TLS; admin login works.
- [ ] An agent install token (TRMM) and an enroll secret + `fleetd` package (Fleet) exist.
- [ ] Shell access only via SSM; web UIs IP-restricted. → ready for **M2/M5** enrollment.
