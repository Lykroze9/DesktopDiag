# Changelog

All notable changes to DesktopDiag. Format: newest first. / Les nouveautés de DesktopDiag, les plus récentes en premier.

## App 1.0.0 - 2026-11-20

First release of the standalone Windows app (`app/`, tag `app-v1.0.0`), for people without Claude.
/ Première version de l'appli Windows autonome, pour ceux qui n'ont pas Claude.

### Added
- `DesktopDiag.exe`: one portable file (C# 5, .NET Framework 4.8, WebView2 UI) that embeds the
  skill's scripts and `rules.json`, so both always run the same checks and give the same score.
- Results by area, 3-part advice for every rule with "Open it for me" (fixed list of Windows
  screens), "Done" tracking verified at the next check, symptom mode, score curve, since-last-check,
  compare two checks, glossary tooltips, PDF, copy for a forum, technician view, keyboard shortcuts.
- Optional deep scan with admin rights (`collect-admin.ps1` through the UAC prompt); smartctl and
  WinDbg installed with winget after confirmation, or their official page when winget is missing.
- 4 themes (system, light, dark, high contrast), text size, English/French, French UI uses "vous".
- Self-update from GitHub Releases (`app-v*` tags only), SHA-256 checked, with a What's new popup.

## 0.3.0 - 2026-11-20

### Added
- **Shared rules and computed score**: `rules/rules.json` + `scripts/score.ps1`. The same PC always
  gets the same score; the rules will be shared with the standalone app.
- **New checks**: Windows Memory Diagnostic result, battery health via `powercfg /batteryreport`
  (design vs current capacity, cycles), network health (Wi-Fi signal, router ping, DNS time,
  Wi-Fi and Ethernet drops), page file and hibernation file sizes.
- New report areas: Network, Battery (laptops only).
- `scripts/summarize.ps1` (the `-Summary` digest, now testable on its own).
- Tests: `tests/run-tests.ps1` with synthetic fixtures (no real machine data), GitHub Actions CI
  with PSScriptAnalyzer.
- Bilingual issue templates, Discussions, this changelog.

## 0.2.0 - 2026-11-20

### Added
- `collect.ps1 -Summary`: compact digest, about 10x smaller, used by the skill by default.
- Boot time: firmware time per boot, Fast Startup; admin step: total boot time and boot slowdowns,
  with detection of a stale boot log.
- CPU throttling (Kernel-Processor-Power 37), live performance limit, ACPI thermal zones.
- `references/performance.md`.

## 0.1.0 - 2026-11-19

- First public version: read-only collection (stability, GPU, storage, SMART, hardware errors,
  security, performance, maintenance), admin deep scan (SMART, dump analysis, volume scan),
  history and comparison, FR/EN reports, follow-up scheduling.
