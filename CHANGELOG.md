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

## Skill history

Versions 0.1.0 to 0.3.0 were the Claude Code skill, now in its own repository: see the
[DesktopDiag-Skill changelog](https://github.com/Lykroze9/DesktopDiag-Skill/blob/main/CHANGELOG.md).
