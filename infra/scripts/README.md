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
./fleet-deploy.sh  # then add the Fleet compliance plane              (~10-15 min)
```
`deploy.sh` and `fleet-deploy.sh` run a **preflight** first (checks aws/terraform/python3/
curl/dig, valid AWS creds, and that required `config.env` values are set) and stop with a
clear message if anything's missing.

## First solo run — what to expect
- **Long steps are quiet.** The cert/install steps run on the box via SSM and only print at
  the end. To watch progress live, in another terminal tail the remote log:
  ```bash
  aws ssm send-command --region "$AWS_REGION" --instance-ids <id> \
    --document-name AWS-RunShellScript \
    --parameters 'commands=["tail -n 40 /opt/fleet/install.log 2>/dev/null || tail -n 40 /home/ubuntu/trmm_install.log"]' \
    --query Command.CommandId --output text
  # then: aws ssm get-command-invocation --command-id <cid> --instance-id <id> --query StandardOutputContent --output text
  ```
- **Validated vs. not:** the TRMM remote install was run end-to-end live; the local
  orchestration and the Fleet install are hardened + statically validated (`terraform plan`,
  preflight) but not yet executed verbatim end-to-end — **watch the Fleet step the first time**.
- **If SSM never comes online** after provisioning (rare now that the IAM role is attached at
  launch): `aws ec2 reboot-instances --region <r> --instance-ids <id>`, wait ~2 min, re-run.
- **Re-runnable?** All steps are, **except** `40-install.sh` / `fleet-deploy.sh` (they assume a
  fresh box). To rebuild, `teardown.sh` then deploy again.

## Step by step (same thing, one phase at a time)

| Script | Where | Does |
|---|---|---|
| `10-provision.sh` | local | Terraform apply: EC2, security group, Elastic IP, SSM role |
| `20-dns.sh`       | local | Point DuckDNS (+ wildcard) at the EIP; verify resolution |
| `30-cert.sh`      | local→SSM | Let's Encrypt SAN cert via HTTP-01 (`remote/get-cert.sh`) |
| `40-install.sh`   | local→SSM | Unattended Tactical RMM install (`remote/install-trmm.sh`) |
| `50-verify.sh`    | local | Service health, HTTPS check, print login + 2FA secret |

## Fleet (compliance plane — separate instance)

`./10-provision.sh` (or `deploy.sh`) Terraform-creates **both** the TRMM and Fleet instances.
Then deploy Fleet:

```bash
./fleet-deploy.sh     # Docker stack + TLS + fleetctl + policies + fleetd MSI  (~10-15 min)
```

| File | Where | Does |
|---|---|---|
| `fleet-deploy.sh` | local→SSM | Stand up FleetDM + apply policies + build/serve the fleetd MSI |
| `remote/fleet-install.sh` | on box | The Fleet payload (Docker Compose: MySQL+Redis+Fleet) |
| `fleet-policies.yml` | applied | CP-01…CP-08 compliance policies as code (`fleetctl apply`) |

Fleet uses `<fleet-eip>.sslip.io` for DNS/TLS by default (DuckDNS is usually maxed at 5
domains). Enroll the endpoint with the served fleetd MSI — see the agent guide's Fleet section.

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
