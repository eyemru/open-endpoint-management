# Roadmap / Backlog

Tracked gaps from the Stage-1 (assemble-first) POC review on 2026-06-22. Each item is written
issue-ready — convert to GitHub issues when the repo is pushed (titles map 1:1).

**Status today:** the POC proved the full loop end-to-end on a real Windows 11 endpoint —
enroll + inventory, remote command, software deploy (Chocolatey), security patch push (TRMM),
and compliance pass/fail across CP-01…CP-08 (Fleet). All six acceptance criteria in
[requirements.md](requirements.md) §7 met. Infra is reproducible from `infra/` and was torn
down after the review to stop AWS cost. The items below take it from "working POC" toward
"runnable for ~500 endpoints."

Priority: **P0** = bites soon / foundational · **P1** = needed for real use · **P2** = polish.

---

## P0 — do first

### [P0] Update the architecture diagram to include Fleet
- `docs/diagrams/architecture.{drawio,svg}` still shows **TRMM only** (built before Fleet).
- Add the second plane: endpoints run **both** the TRMM agent and `fleetd`; FleetDM (Docker:
  MySQL+Redis+Fleet) on its own EC2/EIP/DNS; "fix" (TRMM) vs "prove" (Fleet).
- Regenerate via `docs/diagrams/build_diagram.py`; embed updated SVG in `design.md` §6.

### [P0] Wire up TLS certificate auto-renewal (90-day time bomb)
- Both control planes use Let's Encrypt certs obtained with certbot `--standalone` (port 80),
  but TRMM/Fleet now hold 80/443 — the default renewal timer will **fail in ~90 days** and
  break agent comms.
- Fix: certbot `--deploy-hook` that (a) for Fleet copies the renewed cert to
  `/opt/fleet/certs` + `docker compose restart fleet`; (b) for TRMM reloads nginx. Or switch
  to DNS-01 via the DuckDNS token (no port-80 contention). Add a renewal runbook either way.

---

## P1 — needed for real use

### [P1] Database backup + restore (TRMM Postgres, Fleet MySQL)
- No data backups today; our scripts rebuild *infra* but not *data*. Losing an EBS volume =
  losing inventory/compliance history.
- Add scheduled `pg_dump` (TRMM) and `mysqldump` (Fleet) → encrypted S3, plus a restore doc.

### [P1] Harden the admin UIs (IP allowlist / VPN)
- Both TRMM and Fleet login pages are reachable from `0.0.0.0/0` on 443. For a bank, restrict
  admin access to an IP allowlist or VPN; add fail2ban; confirm MFA (TRMM has TOTP; add Fleet
  SSO/MFA). Agent-facing 443 stays open (roaming laptops). See `design.md` §9.

### [P1] Mass agent deployment for ~500 endpoints
- We enrolled one laptop by hand. Add a repeatable rollout: GPO startup script / Intune /
  PDQ-style push for both the TRMM agent (silent `cmd` install) and the fleetd MSI.

### [P1] Automated policy → remediation loop (close the loop)
- The design's headline (UC-07 / milestone M7): a **failing Fleet policy auto-triggers a TRMM
  remediation**. Proven manually; automate via Fleet policy automation (webhook) → a TRMM
  action (e.g., CP-05 screen-lock fix, enable BitLocker).

### [P1] Patch policy + maintenance window as code
- We pushed one patch manually. Define an auto-approve policy (Critical/Security), maintenance
  window, and reboot policy in TRMM, captured as code/config (see `compliance-policies.md` §8).

---

## P2 — polish / hygiene

### [P2] Operations runbook (day-2)
- Consolidate: add/edit a compliance policy, push a patch, onboard a device, **decommission**
  a device (UC-12), rotate secrets, renew certs. Currently scattered across the guides.

### [P2] Threat model / security write-up
- The control plane can execute code on every endpoint (SYSTEM). Document the threat model,
  blast radius, and controls for a bank context — beyond the `design.md` §9 bullets.

### [P2] Cost breakdown doc
- POC (~$60/mo, 2× t3.medium) vs. a ~500-endpoint sizing estimate (instances, storage, backup).

### [P2] Additional ADRs
- Record decisions made during the build: SSM-not-SSH (corp blocks 22), DuckDNS + sslip.io,
  Fleet-as-separate-instance, HTTP-01-vs-DNS-01, expect-driven TRMM install.

### [P2] Audit-ready compliance export (FR-C4)
- Point-in-time compliance evidence export from Fleet for audits.

### [P2] CI + repo hygiene
- shellcheck + `terraform fmt -check` + `terraform validate` in CI; pre-commit hooks; add a
  **LICENSE** (repo is public with none) and a CONTRIBUTING note.

---

## Stage 2 — Hybrid (future, not a Stage-1 gap)
Replace the assembled tools with a custom control plane (FastAPI + Postgres + React) and a
lightweight agent embedding osquery — reusing the policy catalog, patch logic, and IaC built
here. See `design.md` §13 and ADR [0001](decisions/0001-assemble-first.md).
