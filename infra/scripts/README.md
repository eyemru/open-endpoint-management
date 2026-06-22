# Deployment scripts

Automation for standing up / tearing down the Tactical RMM control plane. Pairs with
the [Deployment Guide](../../docs/deployment-guide.md).

## Two kinds of scripts

- **Local** (run on your machine): drive AWS via the CLI and the box via **SSM over 443**
  (no SSH — the admin network blocks port 22).
- **Remote** (`remote/`): payloads that run **on the EC2 box**, shipped + executed via SSM
  by the local scripts. You don't run these directly.

## Setup (once)

```bash
cp config.env.example config.env     # config.env is gitignored (holds secrets)
$EDITOR config.env                   # set DuckDNS token, TRMM admin pass, email, etc.
chmod +x *.sh remote/*.sh
aws sts get-caller-identity          # confirm AWS creds are active
```

## One-shot

```bash
./deploy.sh        # provision -> DNS -> cert -> install -> verify  (~20-35 min)
```

## Step by step (same thing, one phase at a time)

| Script | Where | Does |
|---|---|---|
| `10-provision.sh` | local | Terraform apply: EC2, security group, Elastic IP, SSM role |
| `20-dns.sh`       | local | Point DuckDNS (+ wildcard) at the EIP; verify resolution |
| `30-cert.sh`      | local→SSM | Let's Encrypt SAN cert via HTTP-01 (`remote/get-cert.sh`) |
| `40-install.sh`   | local→SSM | Unattended Tactical RMM install (`remote/install-trmm.sh`) |
| `50-verify.sh`    | local | Service health, HTTPS check, print login + 2FA secret |

## Lifecycle / cost control

| Script | Does |
|---|---|
| `start.sh` | Start the stopped instance (EIP + DNS persist; agents reconnect) |
| `stop.sh`  | Stop it — halts compute charges; keeps data/EIP (~a few \$/mo) |
| `teardown.sh` | **Destroy everything** (terminate, release EIP, remove all AWS objects) + sweep |

## Notes
- `config.env` and `terraform.tfvars` and `*.pem` are gitignored — never commit secrets.
- The install step assumes a **fresh** box; re-running it on an installed box isn't supported
  (use `teardown.sh` then `deploy.sh` to rebuild).
- Avoid a single quote (`'`) in `TRMM_ADMIN_PASS` (it's passed through a quoted SSM env).
