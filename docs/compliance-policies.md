# Compliance Policy Catalog

**Status:** Draft · **Last updated:** 2026-06-20
**Companion to:** [requirements.md](requirements.md) (FR-C3, §6 baseline) and
[design.md](design.md) (§7). This is the concrete, testable specification of the baseline
"definition of compliant."

Each policy is evaluated in **FleetDM** as an osquery query, and where drift can be fixed,
maps to a **Tactical RMM** remediation. This closes the visibility → remediation loop (UC-04
→ UC-08).

> **Fleet policy convention:** a policy query returns **one or more rows when the host is
> COMPLIANT**, and **zero rows when it fails**. All queries below follow that convention.
>
> **Verify before trusting:** the osquery table/column names below are drafted from the
> Windows schema and must be confirmed against the actual osquery version during M5/M6
> (table availability varies by version). Items marked **[TRMM]** are better evaluated by a
> Tactical RMM PowerShell check than by osquery and are noted as such.

---

## Summary

| ID | Policy | Severity | Source | Auto-remediable? |
|----|--------|----------|--------|------------------|
| CP-01 | BitLocker enabled (OS volume) | Critical | Fleet | Yes (script) |
| CP-02 | Defender real-time on + signatures fresh | Critical | Fleet + **[TRMM]** | Yes (update sigs) |
| CP-03 | Windows Firewall on (all profiles) | High | Fleet | Yes (script) |
| CP-04 | Patch currency (no pending Critical/Security; build current/N-1) | Critical | **[TRMM]** + Fleet | Yes (patch run) |
| CP-05 | Screen-lock timeout ≤ 15 min | Medium | Fleet | Yes (set policy) |
| CP-06 | Required software present (EDR/VPN) | High | Fleet | Partial (install) |
| CP-07 | Local administrators limited to approved set | High | Fleet (report) + **[TRMM]** | Manual/script |
| CP-08 | Disk free space ≥ 20 GB | Medium | Fleet | Partial (cleanup) |

---

## CP-01 — BitLocker enabled on the OS volume
- **Requirement:** FR-C3 (disk encryption) · **Use case:** UC-04 · **Severity:** Critical
- **Rationale:** Lost/stolen laptops must not expose data at rest. Top audit item for a bank.
- **Fleet query (compliant = row returned):**
  ```sql
  SELECT 1 FROM bitlocker_info WHERE drive_letter = 'C:' AND protection_status = 1;
  ```
- **Remediation [TRMM script]:** enable BitLocker with TPM + recovery-key escrow, e.g.
  `Enable-BitLocker -MountPoint C: -EncryptionMethod XtsAes256 -TpmProtector` and back up the
  recovery key. *Caution:* never auto-enable without a key-escrow destination.

## CP-02 — Defender real-time protection on, signatures fresh
- **Requirement:** FR-C3 (antivirus) · **Use case:** UC-04 · **Severity:** Critical
- **Fleet query (real-time on):**
  ```sql
  SELECT 1 FROM windows_security_center WHERE antivirus = 'Good';
  ```
- **Signature freshness [TRMM]:** osquery has no clean signature-age table; evaluate with a
  TRMM PowerShell check: `(Get-MpComputerStatus).AntivirusSignatureAge -le 3`.
- **Remediation [TRMM]:** `Update-MpSignature`; if disabled, re-enable real-time protection.

## CP-03 — Windows Firewall enabled (all profiles)
- **Requirement:** FR-C3 (firewall) · **Use case:** UC-04 · **Severity:** High
- **Fleet query:**
  ```sql
  SELECT 1 FROM windows_security_center WHERE firewall = 'Good';
  ```
- **Remediation [TRMM script]:** `Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True`.

## CP-04 — Patch currency
- **Requirement:** FR-C3 (patch currency), FR-I3 · **Use cases:** UC-05, UC-06 · **Severity:** Critical
- **Two parts:**
  - **No pending Critical/Security updates [TRMM]:** Tactical RMM's Windows Update inventory
    is the authoritative source for *missing* updates (osquery only sees *installed* hotfixes).
  - **OS build is current or N-1 (Fleet):**
    ```sql
    -- Maintain this allowlist each Patch Tuesday (Win10 & Win11 current/previous builds)
    SELECT 1 FROM os_version WHERE build IN ('22631', '22621', '19045');
    ```
- **Remediation [TRMM]:** approve Critical/Security patches and run a patch job in the
  maintenance window with the agreed reboot policy (FR-R4/R5).

## CP-05 — Screen-lock timeout ≤ 15 minutes
- **Requirement:** FR-C3 (screen lock) · **Use case:** UC-04 · **Severity:** Medium
- **Fleet query (machine inactivity policy, ≤ 900s):**
  ```sql
  SELECT 1 FROM registry
  WHERE path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs'
    AND CAST(data AS INTEGER) BETWEEN 1 AND 900;
  ```
- **Remediation [TRMM script]:** set `InactivityTimeoutSecs` (or deploy the equivalent GPO/MDM
  policy) to ≤ 900.

## CP-06 — Required software present
- **Requirement:** FR-C3 (required software) · **Use case:** UC-04 · **Severity:** High
- **Fleet query (example: EDR present — adjust the LIKE per your approved product):**
  ```sql
  SELECT 1 FROM programs WHERE name LIKE '%CrowdStrike%'
  UNION ALL
  SELECT 1 FROM services WHERE name LIKE '%CSFalcon%';
  ```
- **Remediation [TRMM + Chocolatey]:** push the EDR/VPN installer (some EDRs require a vendor
  installer + token rather than Chocolatey).

## CP-07 — Local administrators limited to an approved set
- **Requirement:** FR-C3 (local admins) · **Use case:** UC-04 · **Severity:** High
- **Fleet query (enumerate current local admins — compare to allowlist):**
  ```sql
  SELECT u.username
  FROM users u
  JOIN user_groups ug ON u.uid = ug.uid
  JOIN groups g ON ug.gid = g.gid
  WHERE g.groupname = 'Administrators';
  ```
- **Note:** a single osquery can't easily express "only these accounts." Options: (a) report
  the list in Fleet and review, or (b) a TRMM script that removes any admin not on the
  allowlist. Treat removal as **manual-approval**, not blind automation.

## CP-08 — Disk free space ≥ 20 GB
- **Requirement:** FR-C3 (disk space — so patches can install) · **Use case:** UC-04 · **Severity:** Medium
- **Fleet query (≥ 20 GiB free on C:):**
  ```sql
  SELECT 1 FROM logical_drives WHERE device_id = 'C:' AND free_space > 21474836480;
  ```
- **Remediation [TRMM script]:** run Disk Cleanup / clear `%TEMP%` / `cleanmgr` or
  Storage Sense; alert if still low.

---

## POC scope for policies

For the thin-slice POC (acceptance criteria, requirements §7) we only need **one** policy
reporting pass/fail end to end. Recommended first policy: **CP-01 (BitLocker)** — high audit
value, a single clean osquery, and a clear, safe-with-escrow remediation to demonstrate the
visibility → remediation loop (M6 → M7). The remaining policies are layered in post-POC.

## Maintenance notes

- **CP-04 build allowlist** must be refreshed each Patch Tuesday — candidate for automation later.
- Keep this catalog as the single source of truth; when we build the Stage 2 Hybrid
  compliance engine, these definitions port directly into it (design §13).
