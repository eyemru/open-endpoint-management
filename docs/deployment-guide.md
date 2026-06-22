# Deployment Guide — Endpoint Management on AWS (Tactical RMM + Fleet)

**Status:** Validated end-to-end on 2026-06-22 · **Companion:** [agent-install-guide.md](agent-install-guide.md)

A repeatable, step-by-step guide to stand up the open-source, assemble-first endpoint-
management stack on AWS — **Tactical RMM** (remediation) and **FleetDM** (compliance) — secure
both with TLS, verify, then operate and tear down. Everything is scripted in
[`infra/scripts/`](../infra/scripts/); this guide explains the *why* and gives both the
**automated** and **manual** paths. (The core flow below stands up TRMM; §7b adds Fleet.)

---

## 1. What you get

**Two** EC2 instances forming an assemble-first stack, both with valid Let's Encrypt TLS:
- **Tactical RMM** (remediation) — inventory, remote command, software deploy via Chocolatey,
  Windows patching, MeshCentral remote access — at `https://rmm.<your-domain>`.
- **FleetDM** (compliance) — osquery-based visibility and pass/fail policy posture
  (CP-01…CP-08) — at `https://<fleet-host>`.

Endpoints phone home over HTTPS/443, so roaming laptops work without VPN or inbound firewall
rules. You can deploy just TRMM (§4–§6) and add Fleet later (§7b), or both.

```
                          ┌─► EC2 #1: Tactical RMM (remediation)
  Windows endpoints       │     Postgres·Redis·NATS·MeshCentral·nginx + LE TLS   rmm.<domain>
   • TRMM agent ──HTTPS───┤
   • fleetd (osquery) ────┘─► EC2 #2: FleetDM (compliance)
                                MySQL·Redis·Fleet (Docker) + LE TLS               <fleet-host>
   You ──browser──► rmm.<domain> = "fix"   ·   <fleet-host> = "prove"
   Both managed from your Mac via AWS SSM over 443 — no SSH.
```

## 2. Prerequisites

| Need | Notes |
|---|---|
| **AWS account + CLI** | `aws configure` (or SSO). Verify: `aws sts get-caller-identity`. The IAM identity needs EC2 + IAM + SSM permissions. |
| **Terraform** | v1.3+ (`terraform version`). |
| **A domain** | This guide uses free **DuckDNS**. Create a subdomain (e.g. `nbcepm`) and grab your **account token**. DuckDNS's wildcard covers `rmm./api./mesh.` automatically. |
| **python3 + curl + dig** | Used by the scripts (standard on macOS/Linux). |
| **A Windows 10/11 endpoint** | To enroll later — see the agent guide. |

> **Why SSM, not SSH?** On managed/corporate networks, outbound **port 22 is often blocked**
> by a security proxy (you'll see `kex_exchange_identification: Connection closed`). This
> deployment manages the box entirely through **AWS Systems Manager (SSM) over 443**, which
> such networks allow. No public SSH is required.

## 3. Architecture decisions baked in

- **Default VPC**, one `t3.medium` (≈4 GB RAM), 30 GB encrypted gp3 — minimal, cheap, easy
  to destroy. Security group opens 443 + 80 (Let's Encrypt) + 4222 (NATS) to the world and
  22 only to your IP (SSH is a break-glass extra; SSM is the real path).
- **TLS via HTTP-01**, not the installer's interactive wildcard DNS-01 challenge — fully
  non-interactive and needs no DNS token. We hand the cert to the installer with
  `--use-own-cert`.
- **Unattended install** driven by `expect` (the official TRMM installer is interactive and
  refuses to run as root). See [`infra/scripts/remote/install-trmm.sh`](../infra/scripts/remote/install-trmm.sh).
- **Fleet is a separate instance** with its own EIP/DNS, deployed via **Docker Compose**
  (MySQL + Redis + Fleet) with Let's Encrypt TLS — see
  [`infra/scripts/remote/fleet-install.sh`](../infra/scripts/remote/fleet-install.sh). Kept
  apart from TRMM to avoid resource contention and mirror the real two-system design.

## 4. Automated path (recommended)

```bash
cd infra/scripts
cp config.env.example config.env        # then edit: DuckDNS token, admin pass, email...
chmod +x *.sh remote/*.sh
./deploy.sh                              # ~20-35 min
```

`deploy.sh` runs all five phases and finishes by printing the **web UI URL, admin username,
and the 2FA (TOTP) secret**. Add the secret to your authenticator app and log in.

## 5. Manual path (same phases, one at a time)

Run from `infra/scripts/` after editing `config.env`:

```bash
./10-provision.sh   # Terraform: EC2 + SG + Elastic IP + SSM role.  Prints the EIP.
./20-dns.sh         # Point DuckDNS (+wildcard) at the EIP; verify rmm/api/mesh resolve.
./30-cert.sh        # On the box (via SSM): Let's Encrypt SAN cert (HTTP-01).
./40-install.sh     # On the box (via SSM): unattended Tactical RMM install (~15-30 min).
./50-verify.sh      # Health check + HTTPS check + print login & TOTP secret.
```

Each step is safe to re-run **except `40-install.sh`**, which assumes a fresh box.

### What each phase does under the hood
1. **Provision** — writes `terraform.tfvars` (auto-detects your public IP for the SSH rule),
   `terraform apply`. Outputs `public_ip` (EIP) and `instance_id`.
2. **DNS** — `curl` to the DuckDNS update API sets the A record to the EIP; `dig` confirms
   the root and `rmm./api./mesh.` wildcard all resolve before we request a cert.
3. **Cert** — installs certbot on the box, runs `certonly --standalone` for the four names,
   producing `/etc/letsencrypt/live/trmm/`.
4. **Install** — copies the cert where the `ubuntu` user can read it, downloads the official
   installer, and runs it via `expect` with `--use-own-cert`, feeding domains/email/cert
   paths and creating the admin login (password from `config.env`).
5. **Verify** — checks all services are `active`, curls `rmm`/`api` for HTTP 200, and reads
   the admin **TOTP secret** from the DB so you can set up 2FA.

## 6. First login

1. Browse to `https://rmm.<your-domain>`.
2. **Set up 2FA first:** authenticator app → add account → *enter setup key manually* →
   paste the TOTP secret from step 5 (issuer: TacticalRMM).
3. Log in with the admin username/password and the 6-digit code.
4. Change the password in the UI (Settings) after first login.

## 7. Enroll an endpoint

See **[agent-install-guide.md](agent-install-guide.md)** — create a Client + Site, generate
the installer, and install the agent on Windows (including the `cmd`-vs-PowerShell gotcha).

## 7b. Deploy Fleet (compliance plane) — second instance

`10-provision.sh` (and `deploy.sh`) Terraform-creates **both** the TRMM and Fleet EC2
instances. To stand up FleetDM and apply the compliance policies:

```bash
./fleet-deploy.sh        # Docker stack + TLS + fleetctl + CP-01..08 policies + fleetd MSI
```

- Fleet's hostname defaults to **`<fleet-eip>.sslip.io`** (no DuckDNS slot needed). To use a
  DuckDNS name instead, set `FLEET_HOSTNAME=<name>.duckdns.org` in `config.env`; if
  `DUCKDNS_TOKEN` is set the script repoints it at the (new) Fleet EIP automatically.
- Enroll the endpoint with the served fleetd MSI (`http://<FLEET_HOSTNAME>/fleet-osquery.msi`)
  — see the agent guide's Fleet section. Install it via the **Windows GUI / `msiexec /qb`**,
  not fully silent.
- View pass/fail in **Fleet → Hosts → host → Policies**. (Per-host results are immediate;
  Fleet's *fleet-wide aggregate* counts lag on a background cron.)

## 8. Operate (cost control)

**Two instances** run (TRMM + Fleet) ≈ **\$60/mo**. The lifecycle scripts act on **both** (by
project tag):

```bash
./stop.sh     # halt compute on both (keeps data, EIPs, DNS) — a few $/mo remain
./start.sh    # resume both — same EIPs/DNS, SSM back in ~1-2 min, agents reconnect
```

### Resume the next day (the common case)
If you `stop.sh`'d (not torn down), bringing everything back is just:
```bash
cd infra/scripts && ./start.sh
```
TRMM (systemd) and Fleet (Docker `restart: unless-stopped`) auto-start on boot, so both UIs
and both agents come back on their own — no re-install, no re-enroll. The one-time fleetd-MSI
web server on Fleet's port 80 does **not** survive a stop (it's only needed for first
download; not required afterward).

## 9. Teardown (remove all cost)

```bash
./teardown.sh        # confirm with 'destroy'   (or: ./teardown.sh -y)
```
Runs `terraform destroy` (terminates **both instances**, deletes their EBS volumes, releases
both Elastic IPs, removes the security groups, IAM role/profile, and keypair), then sweeps for
any leftover tagged resources. It does **not** touch DuckDNS or the endpoint agents — repoint/
remove DuckDNS records manually, and uninstall the agents per the agent guide.

### Full rebuild from scratch (after teardown)
```bash
cd infra/scripts
./deploy.sh          # provisions both instances + installs TRMM
./fleet-deploy.sh    # installs Fleet on the (new) Fleet instance
```
Then re-enroll the endpoint(s) in both TRMM and Fleet (new agent installers). Note: a rebuild
yields **new Elastic IPs**, so DuckDNS/sslip.io names update to the new IPs (automatic for
sslip.io and for DuckDNS when `DUCKDNS_TOKEN` is set).

## 10. Troubleshooting (things we actually hit)

| Symptom | Cause | Fix |
|---|---|---|
| `kex_exchange_identification: Connection closed` on SSH | Corporate network blocks outbound 22 | Use SSM (this guide does); don't rely on SSH |
| SSM `PingStatus=None` after provision | SSM agent started before the IAM role attached | `aws ec2 reboot-instances --instance-ids <id>`; it registers after reboot |
| `set: Illegal option -o pipefail` in SSM | SSM runs scripts with `dash`, not bash | Scripts base64-ship and run with `bash` (handled in `lib.sh`) |
| Certbot fails | DNS not resolving yet / port 80 blocked | Re-run `20-dns.sh`; ensure SG allows 80; wait for propagation |
| `nats: no servers available` right after install | Transient — logged before NATS finished starting | Ignore; confirm `systemctl is-active nats` later |
| Agent won't enroll | Almost always a Windows-side install issue | See agent-install-guide.md (cmd-vs-PowerShell, Defender) |

## 11. Security notes

- Secrets (`config.env`, `terraform.tfvars`, `*.pem`) are gitignored — never commit them.
- Rotate the DuckDNS token and TRMM admin password if they've been shared anywhere.
- The agent runs as SYSTEM; the control plane can execute code on every endpoint — restrict
  the admin UI (IP allowlist / strong creds / 2FA) and treat the box as critical infra.
- For non-POC use, review the Tactical RMM source-available license.
