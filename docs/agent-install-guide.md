# Agent Install Guide — Windows Endpoint Enrollment

**Status:** Validated on Windows 11 24H2, 2026-06-21 · **Companion:** [deployment-guide.md](deployment-guide.md)

How to enroll a Windows 10/11 endpoint into Tactical RMM, written from a real install
including the pitfalls that cost us time. Do these steps **on the target laptop** (simplest),
or download elsewhere and copy the installer over.

Prereq: the control plane is up (`https://rmm.<your-domain>` loads) and you can log in.

---

## 1. Create a Client and Site (one-time)

In the TRMM web UI:
1. **Add Client** (e.g. `Northbridge`).
2. **Add Site** under it (e.g. `HQ`).
Agents are organized under Client → Site.

## 2. Generate the installer

1. **Agents → Install Agent** (or right-click the Site → Install Agent).
2. Choose:
   - **Client / Site**: the ones above.
   - **Agent type**: **Workstation** (use Server only for always-on servers).
   - **Arch**: **amd64** for most PCs (use **arm64** for Snapdragon/ARM devices).
   - Checkboxes — for a **laptop**, leave all **unchecked**:
     - *Enable RDP* ❌ (security exposure on roaming laptops; MeshCentral already gives remote access)
     - *Enable Ping* ⚪ (harmless, unnecessary)
     - *Disable sleep/hibernate* ❌ (drains a laptop battery; meant for servers)
   - **Expiry**: default is fine.
3. **Download** the `.exe` (e.g. `tacticalagent-vX.Y.Z-windows-amd64.exe`). The dialog also
   shows a **command** with an embedded `--auth` token — keep that window handy (you'll use it).

## 3. Install the agent — the reliable way

> ⚠️ **The #1 gotcha:** the install command TRMM gives you uses `&&` to chain steps, which is
> **`cmd.exe` syntax**. Pasting it into **PowerShell** fails with
> *"The token '&&' is not a valid statement separator in this version."* And **double-clicking**
> the `.exe` runs it in *interactive* mode (a popup that often ends at
> *"Agent: not installed, Mesh agent: not installed"*) — the registration step never runs.

**Do this instead** — open **Command Prompt as Administrator** (Start → type `cmd` →
right-click → *Run as administrator*) and paste the command from the dialog. It looks like:

```cmd
cd /d "%USERPROFILE%\Downloads" && tacticalagent-vX.Y.Z-windows-amd64.exe /VERYSILENT /SUPPRESSMSGBOXES && ping 127.0.0.1 -n 8 >nul && "C:\Program Files\TacticalAgent\tacticalrmm.exe" -m install --api https://api.<your-domain> --client-id <N> --site-id <N> --agent-type workstation --auth <TOKEN> -log debug
```

- `/VERYSILENT /SUPPRESSMSGBOXES` → no popup; `ping` is just a wait; the final
  `tacticalrmm.exe -m install` registers with the server, creates the service, and installs
  the Mesh agent. `-log debug` gives verbose output.
- Success looks like: `Installing service...`, `Starting service...`, a server response of
  `"ok"`, and a **"Installation was successful!"** dialog.

**If you must use PowerShell**, run the registration step alone (one line, no `&&`):
```powershell
& "C:\Program Files\TacticalAgent\tacticalrmm.exe" -m install --api https://api.<your-domain> --client-id <N> --site-id <N> --agent-type workstation --auth <TOKEN> -log debug
```
(The leading `& ` is PowerShell's call operator for a quoted path — not a chain.)

## 4. If it still fails — antivirus

RMM/Mesh agents are remote-control tools and Defender/EDR may quarantine them. On a machine
you control, add exclusions (**admin PowerShell**) then re-run step 3:
```powershell
Add-MpPreference -ExclusionPath "C:\Program Files\TacticalAgent"
Add-MpPreference -ExclusionPath "C:\Program Files\Mesh Agent"
Add-MpPreference -ExclusionProcess "tacticalrmm.exe"
Add-MpPreference -ExclusionProcess "meshagent.exe"
```
On a **corporate-managed** laptop, EDR/policy may block it outright (and it may be against
policy) — use a personal machine or a VM instead.

## 5. Verify on the endpoint

```powershell
Get-Service *tactical*, "Mesh Agent" | Format-Table Name, Status     # should be Running
Get-Content "C:\Program Files\TacticalAgent\agent.log" -Tail 20      # activity (0 KB = never ran)
```
A **0 KB `agent.log`** means the binary never executed (interactive/`cmd` issue or AV) — go
back to step 3/4.

## 6. Verify on the server

Within ~60 seconds the agent appears in the dashboard (green/online) under your Site. To
confirm independently (from the deploy machine):
```bash
cd infra/scripts && ./50-verify.sh        # prints "agents registered: N"
```
TRMM's **software** and **patch** inventories refresh on a schedule, so a freshly installed
package/patch can lag a few minutes (or click refresh in the Software/Patches tab).

## 7. Quick capability check (optional)

- **Remote command:** agent → *Run Command* → `hostname` → see output return.
- **Software:** agent → *Software* tab → Chocolatey → install `7zip`.
- **Patch:** agent → *Patches* → *Check for Updates* → **approve** a security KB →
  *Install approved updates* (choose **do not reboot** on a daily-driver). Note: a Windows
  **Home** edition can't do managed BitLocker — expect that compliance check to fail.

## 8. Remove the agent (cleanup)

1. In TRMM: delete the agent (or it'll show offline).
2. On the endpoint (admin): Settings → Apps → uninstall **Tactical RMM Agent** and **Mesh Agent**
   (or run `"C:\Program Files\TacticalAgent\tacticalrmm.exe" -m uninstall`).
3. **Re-enable Windows Update** — the agent **disables Windows automatic updates** so TRMM
   can manage patching; undo that if you're returning the machine to normal use:
   ```powershell
   Set-Service wuauserv -StartupType Automatic; Start-Service wuauserv
   ```
4. Optionally remove the Defender exclusions from step 4.

---

## 9. Enroll in Fleet (compliance) — the `fleetd` agent

Fleet is the **second** agent (compliance/visibility), separate from the Tactical RMM agent.
Its `fleetd` MSI is signed, so it installs cleanly (no Defender drama like the Mesh agent).

1. **Download** the installer (built + served by the Fleet deploy). On the laptop:
   ```powershell
   Invoke-WebRequest "http://<FLEET_HOSTNAME>/fleet-osquery.msi" -OutFile "$env:USERPROFILE\Downloads\fleet-osquery.msi"
   ```
   (`<FLEET_HOSTNAME>` is the `<fleet-eip>.sslip.io` printed by `fleet-deploy.sh`.)
2. **Install** (admin) — the MSI has the Fleet URL + enroll secret baked in:
   ```powershell
   msiexec /i "$env:USERPROFILE\Downloads\fleet-osquery.msi" /quiet
   ```
   Or double-click and approve UAC.
3. Within ~1 minute the host appears in **Fleet → Hosts**, and the 8 compliance policies
   (CP-01…CP-08) evaluate **pass/fail**.

**Verify (server-side):** `fleetctl get hosts` and the Fleet UI policy view. On a Windows
**Home** laptop, expect a realistic mix — e.g. Firewall/Defender/UAC/disk **pass**, BitLocker
**fail** (Home has no managed BitLocker), screen-lock and EDR likely **fail**. That mix *is*
the demo: real compliance gaps surfaced automatically.

**Remove fleetd:** uninstall "Fleet osquery" / "fleetd" from Apps (or `msiexec /x`), and delete
the host in Fleet.

> The MSI is served by a one-time HTTP server on the Fleet box's port 80. It's only needed for
> the initial download; it does not survive a reboot (and isn't needed after enrollment).

---

## 10. Enrollment at scale — two tracks (toward ~10,000 endpoints)

Manual install (above) is for the pilot. At scale there are two paths:

### Track A — zero-touch for NEW machines (the ~1,000-machine milestone)
Bake **both agents into the standard build / gold image** so a machine enrolls itself on
first boot — no per-device work, no desk visit.

- Pre-place the TRMM agent silent-install command and the fleetd MSI (URL + enroll secret
  baked in) in the image.
- ⚠️ **Imaging gotcha — do NOT capture an *already-enrolled* agent into the image.** If the
  reference machine has already checked in, every clone shares one identity and they collide.
  Install the agents but **enroll on first boot** (e.g., a `RunOnce` / scheduled first-logon
  task, or run install post-sysprep) so each device gets a **unique** TRMM agent id and fleetd
  node key.
- Validate with a small image build + a handful of machines before the 1k run.

### Track B — push to EXISTING machines
Roll out to in-service machines in controlled waves using existing tooling:
- **GPO** startup/scheduled-task script, **Intune**, **SCCM**, or **PDQ Deploy**.
- Deliver the TRMM agent silent `-m install` command (run via `cmd`, not PowerShell) and the
  fleetd `msiexec /i … /quiet` (test `/quiet` under SYSTEM; use `/qn` if needed).
- Include the Defender exclusions (§4) in the same package if endpoint AV flags the agents.

See the program rollout model in [`business-brief.md`](business-brief.md) §7 and the tracked
work in [`roadmap.md`](roadmap.md).
