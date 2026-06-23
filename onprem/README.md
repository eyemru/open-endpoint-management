# On-Prem Deployment Kit (no AWS)

Stand up the **same** two-plane stack — **Tactical RMM** (remediation) + **FleetDM**
(compliance) — on your **own servers** (bare metal or VMs), with **no AWS, Terraform, or
SSM**. You run the installers **directly on each server** as root.

This is the portable sibling of the AWS kit in [`../infra/`](../infra/). Same proven install
logic (TRMM expect-installer; Fleet Docker stack; the CP-01…08 policies), minus the cloud
plumbing. What AWS used to provide is now configurable: **TLS cert acquisition** and
**networking/DNS** are yours to supply.

> Honesty: these scripts are adapted from the AWS payloads that were validated end-to-end.
> The on-prem wrappers (user creation, cert modes, port config) are new and syntax-checked
> but not yet run on a real on-prem box — expect to babysit the first run.

## 1. What you need per server

- **OS:** Ubuntu 22.04/24.04 LTS or Debian 12, root/sudo, internet access (to pull packages,
  the TRMM installer, and the Fleet Docker images — *not* air-gapped).
- **Size:** ≥ 2 vCPU / 4 GB RAM / 30 GB disk each (TRMM compiles Python; Fleet runs MySQL).
- **DNS:** hostnames that resolve to the server:
  - TRMM needs **three**: `api.<root>`, `rmm.<root>`, `mesh.<root>`
  - Fleet needs **one**: `fleet.<root>` (your choice)
  - Point these at the server in your DNS (or DuckDNS, or — lab only — `/etc/hosts`).
- **Open inbound ports:** `443` (agents + UI) and, for Let's Encrypt, `80` during issuance.
- **Endpoints** can reach the server hostnames on 443.

## 2. The cert decision (`CERT_MODE`) — read this first

On-prem servers often aren't internet-reachable, so pick the cert mode in `config.env`:

| Mode | Use when | Notes |
|---|---|---|
| `letsencrypt` | Server is public on 80/443 | Automatic (HTTP-01). Easiest if reachable. |
| `byo` | You have a corporate/internal CA cert | Set `CERT_FULLCHAIN` / `CERT_PRIVKEY` paths. **Best for internal networks.** |
| `selfsigned` | Lab/POC only | Agents validate TLS, so you must **trust the generated cert on every endpoint**, or they won't connect. |

## 3. One server or two?

- **Two servers (recommended):** TRMM on one, Fleet on the other — mirrors the AWS design,
  no port contention.
- **One server (co-host):** both want `:443`. Set **`FLEET_HTTPS_PORT=8443`** in `config.env`
  so Fleet uses a different port (its URL/agents become `https://fleet.<root>:8443`). Run
  `install-trmm.sh` first, then `install-fleet.sh`.

## 4. Steps

On each server:
```bash
# 1. copy this folder to the server (scp/git), then:
cd onprem
cp config.env.example config.env && $EDITOR config.env   # set CERT_MODE, hostnames, passwords
chmod +x *.sh

# 2. sanity check (OS, RAM, ports free, DNS resolves here, internet)
sudo ./preflight.sh

# 3a. on the TRMM server  (~15-30 min)
sudo ./install-trmm.sh
#     -> prints the TRMM URL + how to fetch the 2FA secret

# 3b. on the Fleet server  (~10-15 min)
sudo ./install-fleet.sh
#     -> prints the Fleet URL, enroll secret, and the fleetd MSI path
```
Logs stream to `/opt/epm/trmm-install.log` and `/opt/fleet/install.log`.

## 5. Enroll a Windows endpoint (same as cloud)

- **Tactical RMM:** in the UI create a Client + Site → **Agents → Install Agent** (Workstation)
  → run the generated command in an **Administrator Command Prompt** (not PowerShell — it uses
  `&&`). Full detail + gotchas: [`../docs/agent-install-guide.md`](../docs/agent-install-guide.md).
- **Fleet:** get `fleet-osquery.msi` off the server (scp, or `python3 -m http.server 8080
  --directory /opt/fleet/dl`) → install on the endpoint (double-click / `msiexec`). The Fleet
  URL + enroll secret are baked in.

## 6. Firewall / ports reference

| Port | Where | Why |
|---|---|---|
| 443 (or `FLEET_HTTPS_PORT`) | inbound to servers | agents + web UIs |
| 80 | inbound, transient | Let's Encrypt HTTP-01 only (skip for `byo`/`selfsigned`) |
| 5432 / 6379 / 4222 (TRMM), 3306 / 6379 (Fleet) | in-box only | databases / queue — never expose |

## 7. Teardown / cleanup

- **Fleet:** `cd /opt/fleet && docker compose down -v && cd / && rm -rf /opt/fleet && rm -f /usr/local/bin/fleetctl`
- **TRMM:** a clean uninstall is involved (Postgres, MeshCentral, many services). Easiest is to
  **revert a VM snapshot** taken before install. Otherwise stop/disable the services
  (`systemctl disable --now rmm daphne celery celerybeat nats nats-api meshcentral nginx`).
- Remove the temporary sudoers file: `rm -f /etc/sudoers.d/90-epm-<install_user>`.

## 8. Differences vs. the AWS kit
- No Terraform/EC2/EIP/SSM/security-groups — **you** own the host, DNS, firewall, and backups.
- Cert is `CERT_MODE`-driven (cloud kit assumed Let's Encrypt + DuckDNS).
- You run scripts **on the box** (cloud kit shipped them via SSM).
- Everything else — the TRMM install, the Fleet stack, the policies, enrollment — is identical.
