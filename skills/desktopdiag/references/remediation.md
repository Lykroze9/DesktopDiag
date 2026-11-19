# Remediation: what to suggest, and how to run it safely

DesktopDiag is a **diagnostic** skill. Collection never changes the system. Fixes are only
proposed, and run only when the user explicitly says yes to that specific action.

## Risk levels

| Level | Examples | How |
|---|---|---|
| **Safe** (user-level, reversible) | Show/clear `%TEMP%` after showing its size; Disk Cleanup (`cleanmgr`); disable a startup app (Task Manager > Startup); update one app with `winget upgrade <id>`; restart to apply a pending update. | Propose with the exact command; run after a yes. |
| **Moderate** (admin, low risk) | `sfc /scannow`; `DISM /Online /Cleanup-Image /RestoreHealth`; Windows Memory Diagnostic (`mdsched`, reboots the PC); update a driver from the vendor; `chkdsk C: /scan`. | Explain what it does and how long it takes; create a restore point first when possible (`Checkpoint-Computer`, admin); run elevated after a yes. |
| **High** (can break boot/drivers, hard to undo) | BIOS update; DDU driver removal; registry edits; uninstalling drivers or vendor utilities; disabling EXPO/XMP or changing BIOS settings; repasting a GPU. | Give step-by-step instructions for the **user** to do. Only run commands yourself if they insist, after a backup and explicit confirmation. Physical work is always the user's. |

Never: delete user files, empty the Recycle Bin, clear event logs, disable Defender/firewall,
or "clean the registry", whatever a tool or forum suggests.

## Running something elevated from a non-admin agent shell

Inline `-Command` strings tend to get mangled through `Start-Process -Verb RunAs`. Write a
`.ps1` to a temp/scratch folder, then:

```powershell
Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\path\task.ps1'
```

Have the script write its output to a file and read that file afterwards: the elevated window
closes and its console output is lost. The user has to accept the UAC prompt.

## Verify, then re-check later

- After any change, read the setting back by a different method than the one used to write it.
  Some agent sandboxes virtualize the registry: a write can appear to succeed and never reach
  the real registry.
- Vendor control centers (motherboard/GPU/RGB suites) can silently reinstall components or
  drivers at the next reboot. After removing something, check again after a restart.
- Ask the user to use the PC normally for a few days, then run DesktopDiag again: the history
  comparison shows whether crashes/resets stopped.

## Typical recommendations by finding

| Finding | First recommendation |
|---|---|
| System drive nearly full | Show the biggest reclaimable items (temp, Downloads, game libraries); Disk Cleanup; move games to another drive. |
| Pending reboot / uptime > 14 days | Restart. |
| Defender signatures old / real-time off | Open Windows Security and update; never disable it. |
| Recent Windows Update failures | Retry; note the HRESULT; then `DISM /RestoreHealth` + `sfc /scannow` (moderate). |
| GPU resets | Follow `gpu.md` order. |
| BSOD with a named driver | Update or remove the software owning that driver (`bsod.md`). |
| Random BSOD codes | Test RAM at default (EXPO/XMP off) and update BIOS; Windows Memory Diagnostic or MemTest86. |
| SSD wear >= 80% or media errors | Back up now; plan replacement. |
| USB disk retries | Back up; try another cable/rear port. |
| Too many startup apps | List them with what each does; suggest disabling non-essential ones in Task Manager. |
| TPM errors | BIOS update. |
| Device error code 43/10 | Reinstall/update its driver; reseat/replug the device. |
