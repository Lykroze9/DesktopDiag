# Follow-up checks: when and how to schedule the next diagnostic

After every report, propose the next check. Creating a scheduled task is a persistent change:
**always ask first** (one short question with the proposed date/frequency), never create it silently.

## 1. Choose the cadence from the findings

Use the first row that matches.

| Situation after this check | Proposal | Why |
|---|---|---|
| A fix or change was just applied (driver, undervolt, BIOS, uninstall, cleanup...) | **One-time check in 3-4 days** | Confirms the fix worked while the user still remembers what changed. |
| Any 🔴 area with recent events (last 7 days) and no fix yet | **One-time check in 2-3 days**, after the user tries the first recommendation | Short loop while the problem is active. |
| 🔴 areas whose events are all older than 7 days (problem seems to have stopped) | **Weekly for 3 weeks**, then switch to monthly | Watch that it stays fixed; crash-free weeks also let the reliability index recover. |
| Only 🟡 areas | **Monthly** | Slow-moving issues (free space, SSD wear, temperatures). |
| Everything 🟢 | **Monthly**, or none if the user prefers | Light routine maintenance. |
| SSD wear >= 80%, SMART warnings, or disk errors on the system drive | **Weekly** until a backup/replacement is done | Data-loss risk. |

Re-evaluate at every follow-up: when a weekly series finds nothing new, propose to switch to
monthly; when a monthly check finds a new 🔴, propose a short one-time loop.

## 2. Pick the tool

Use what this environment offers, in this order:

1. **Local scheduled tasks of the Claude desktop app** (a `create_scheduled_task` /
   `update_scheduled_task` / `list_scheduled_tasks` tool, e.g. `mcp__scheduled-tasks__*`). Best
   option: the run happens on this PC, can execute the scripts and writes a full report.
   Runs only while the app is open; a missed run starts at the next launch. Tell the user that.
2. **No local scheduler available:** do **not** use cloud routines/remote agents: they run in a
   remote sandbox and cannot read this PC. Offer instead to remind the user in the report
   ("relance « check du PC » vers le <date>"), or, only if they want it, a Windows Task Scheduler
   job that runs `collect.ps1` alone (data snapshot, no report) so the history stays complete:

   ```powershell
   $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<skill-dir>\scripts\collect.ps1"'
   $t = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 20:00
   Register-ScheduledTask -TaskName 'DesktopDiag snapshot' -Action $a -Trigger $t -Description 'DesktopDiag read-only weekly snapshot'
   ```
   (Per-user task, no admin needed. Remove with `Unregister-ScheduledTask -TaskName 'DesktopDiag snapshot'`.)

## 3. Avoid duplicates

List existing scheduled tasks first. If a DesktopDiag task already exists (task id starting with
`desktopdiag-`), **update** it (new date, cadence or prompt) instead of creating another one.
Use one task per PC: `desktopdiag-followup` for one-time checks, `desktopdiag-routine` for
weekly/monthly ones. When a routine replaces a finished one-time series, disable the old task.

## 4. Time and date

- Read the PC's offset from the snapshot (`meta.utcOffset`, e.g. `+04:00`) or with
  `Get-Date -Format zzz`. Never assume a time zone from the language: a French speaker may live
  anywhere.
- One-time: `fireAt` = ISO 8601 with that offset, e.g. `2026-11-23T20:00:00+04:00`.
- Weekly: cron in **local** time, e.g. `0 20 * * 0` (Sundays 20:00). Monthly: `0 20 1 * *`
  (1st of the month 20:00) or the first Sunday via the app's options.
- Prefer an evening or weekend slot when the PC is likely on, unless the user says otherwise.
- After creating it, read back the time the tool reports and check it matches what you told the
  user (a wrong offset shifts the run by hours).

## 5. Write a self-contained prompt

Each run starts with no memory of this conversation. The prompt must include:

1. The instruction: run a DesktopDiag check in the user's language with the `desktopdiag` skill
   (give the skill's folder path), run `collect.ps1` then `compare.ps1`, write the report from
   `references/report.md`. Read-only; no admin step and no fixes without explicit consent.
2. **What to verify**, with dates and numbers from this check: the main question (e.g. "no new
   nvlddmkm event since 2026-11-17 12:00"), and the values to compare (free space, error counts,
   SSD wear/temperature, reliability index).
3. **Known causes already handled** (so old events are not presented as new) and **benign noise**
   seen on this PC, to ignore.
4. A reminder that the 30-day score lags behind: explain the trend.
5. The follow-up rule: at the end, propose the next cadence using this file.

### Template (FR)

```
Fais un check du PC en français avec le skill `desktopdiag` (dossier : <skill-dir>) : lance
scripts\collect.ps1, puis scripts\compare.ps1, puis rédige le rapport selon references\report.md.
Lecture seule : ne modifie rien et ne lance pas l'analyse admin sans accord explicite.

Contexte (check de suivi programmé le <date>) :
- Question principale : <ex. confirmer qu'aucune erreur nvlddmkm, aucun Kernel-Power 41 et aucun
  écran bleu n'est survenu depuis le <date heure> (<changement appliqué>)>. Réponds-y en premier.
- Valeurs à comparer : <C: X Go libres / Y %>, <disk/153 : N en 30 j>, <indice de fiabilité : Z>, ...
- Causes connues déjà traitées (ne pas présenter comme nouvelles) : <...>
- Bruit sans gravité à ignorer : <...>
- La note sur 30 jours réagit lentement : explique la tendance.
Termine par 3 à 5 recommandations (qui fait quoi) puis propose la prochaine fréquence de suivi
selon references\followup.md.
```

### Template (EN)

```
Run a PC health check in English with the `desktopdiag` skill (folder: <skill-dir>): run
scripts\collect.ps1, then scripts\compare.ps1, then write the report following
references\report.md. Read-only: change nothing and do not run the admin step without explicit consent.

Context (follow-up scheduled on <date>):
- Main question: <e.g. confirm no nvlddmkm event, no Kernel-Power 41 and no blue screen since
  <date time> (<change applied>)>. Answer it first.
- Values to compare: <C: X GB free / Y%>, <disk/153: N in 30 days>, <reliability index: Z>, ...
- Known causes already handled (do not report as new): <...>
- Benign noise to ignore: <...>
- The 30-day score lags: explain the trend.
End with 3-5 recommendations (who does what), then propose the next follow-up cadence following
references\followup.md.
```

## 6. Tell the user

One or two lines: date/time (with their local time), cadence, what it will verify, that the app
must be open (or it runs at next launch), and how to change or cancel it (the app's Scheduled
section, or ask Claude).
