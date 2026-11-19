# DesktopDiag

### Is your PC slow, glitchy, crashing... or do you just want a quick checkup?

DesktopDiag scans your Windows PC and tells you in plain words what's wrong, and what to do about it.

> **👋 A personal side project.** DesktopDiag started as a custom tool I built for my own PC, after
> chasing GPU freezes and blue screens, and grew into a skill I wanted to share. It is not a
> commercial product and it is far from finished.
>
> **Your feedback is very welcome!** Tried it? Found a bug, a wrong diagnosis, a missing check, or
> just have an idea? Please [open an issue](https://github.com/Lykroze9/DesktopDiag/issues), in
> English or French. Every comment helps make the skill better.

**Read-only Windows PC health check for Claude Code.** Ask "check my PC" or describe a problem
("my screen goes black in games", "random reboots") and Claude collects the data, explains it in
plain language, scores your PC and tells you what to do next. Reports in **English or French**.

[🇫🇷 Version française](README.fr.md)

## What it checks

| Area | Details |
|---|---|
| Stability | Blue screens (stop code + parameters), unexpected shutdowns, crash dumps, Windows reliability index |
| Graphics | Display driver resets (TDR), NVIDIA/AMD/Intel driver errors, driver version and age, overclocking tools at startup |
| Storage | Free space, disk health, SSD wear/temperature/errors (SMART via smartctl), disk errors mapped to the right drive (USB vs system SSD) |
| Hardware | WHEA hardware errors (CPU, RAM, PCIe), TPM errors, devices in error (code 10/43...) |
| Security | Antivirus status, firewall profiles, last successful Windows Update and recent failures, pending reboot, UAC, Secure Boot |
| Performance | Real CPU % (sampled, not cumulative), RAM and commit usage, top processes |
| Maintenance | Startup entries, temp folders, uptime |
| History | Every check is saved locally and compared with the previous one: new crashes since last time, space lost, driver/BIOS updates, startup entries added |
| Follow-up | After each report, Claude proposes the next check sized to what it found (in 2-4 days after a fix, weekly while problems settle, monthly otherwise) and schedules it on your OK with the Claude desktop app's local scheduled tasks |

## Why another one?

Existing Windows diagnostic skills/MCP servers skip the problems people actually hit: GPU driver
resets, NVMe wear, BSOD culprit drivers, and "did it get better since last week?". DesktopDiag
also:

- runs on the **built-in Windows PowerShell 5.1** (no PowerShell 7, Node or Python needed), Windows 10 and 11;
- needs **no admin** for the main check; an optional admin step adds SMART, dump analysis and a read-only file system scan;
- is **read-only**: fixes are proposed with risk levels and run only after your explicit OK;
- documents real-world traps (inflated crash counts in the Application log, `chkdsk` access denied, vendor utilities reinstalling drivers, sandboxed registry writes...);
- has a **share mode** that strips user name, computer name and paths for forum posts.

## Install

### As a Claude Code plugin

```
/plugin marketplace add Lykroze9/DesktopDiag
/plugin install desktopdiag@desktopdiag
```

### As a standalone skill

Copy `skills/desktopdiag` to `%USERPROFILE%\.claude\skills\desktopdiag` (all projects) or to
`.claude\skills\desktopdiag` in a project.

## Use

Just talk to Claude Code:

- "Check my PC" / "Is my PC healthy?"
- "My screen goes black for a few seconds when I play"
- "My PC rebooted by itself twice this week"
- "Is my SSD OK?"
- "Do a full check" (proposes the admin deep scan)
- "Make a shareable report for a forum"
- "Schedule a check every month" / "Check again in 4 days"

You can also run the collector yourself:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\desktopdiag\scripts\collect.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File skills\desktopdiag\scripts\compare.ps1
```

Snapshots are stored in `%LOCALAPPDATA%\DesktopDiag\history`.

## Optional tools

- [smartmontools](https://www.smartmontools.org/) (`winget install smartmontools.smartmontools`) for detailed SSD/HDD SMART data.
- WinDbg (`winget install Microsoft.WinDbg`) to identify the driver behind a blue screen. The first analysis downloads public symbols from Microsoft.

## Privacy

Everything runs locally. Nothing is uploaded (except Microsoft symbol downloads if you accept dump
analysis). Disk serial numbers are hashed. Use share mode before posting a report anywhere.

## Disclaimer

DesktopDiag reads system information and gives advice. It does not replace a technician. Hardware
interventions (BIOS updates, repasting, part replacement) are your decision and responsibility.

## License

MIT
