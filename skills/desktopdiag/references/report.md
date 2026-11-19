# Report: scoring and templates

## Areas and thresholds

**Levels and score come from `scripts/score.ps1`**, which applies `rules/rules.json` (the source of
truth, shared with the standalone app). green = 🟢, yellow = 🟡, red = 🔴, skipped = area not shown
(e.g. Battery on a desktop). Each rating needs one short reason with the actual number: use the
finding texts as a base. The table below is a readable summary of those rules; if it ever
disagrees with rules.json, rules.json wins.

| Area | 🔴 | 🟡 | 🟢 |
|---|---|---|---|
| **Stability** | Any BSOD or Kernel-Power 41 in the last 7 days, or >= 3 in 30 days | 1-2 in 30 days, or reliability index < 5 | None in 30 days |
| **Graphics** | >= 3 GPU reset/driver errors in 30 days, or any in 7 days matching the user's symptom, or device error 43 | 1-2 in 30 days, or GPU driver older than 12 months | None |
| **Storage space** | System drive < 8% or < 15 GB free | < 15% or < 30 GB free; data drive < 10% | OK |
| **Disk health** | Health not Healthy, SMART failed, NVMe critical warning / media errors, SATA 5/197/198 > 0, wear >= 100%, disk 7/51/Ntfs 55 on an internal disk | Wear 80-99%, SSD time above warning temperature, disk 153/129 retries (incl. USB) | OK |
| **Hardware errors** | WHEA 18, many (>10) corrected WHEA errors, problem device code 10/43 on a key device | A few corrected WHEA, TPM errors, other problem devices | None |
| **Security** | No active antivirus, real-time off, a firewall profile off | Signatures > 3 days old, last successful update > 30 days, recent update failures, UAC off | OK |
| **Performance now** | RAM > 90% or commit > 95% | RAM > 80%, commit > 85%, one process > 50% CPU | OK |
| **Boot time** | Admin full boot > 120 s (SSD system drive) | Firmware time > 30 s, or admin full boot 60-120 s, or a recurring boot slowdown > 10 s | OK, or no data |
| **Heat / throttling** | CPU throttling events (Kernel-Processor-Power 37) in the last 7 days on a desktop or on AC power, together with crashes or the user's symptom; thermal zone > 95 °C | A few throttling events in 30 days; `cpuPerfLimitPct` < 100 at idle; thermal zone > 85 °C | None |
| **Network** | DNS not responding, router not responding | Wi-Fi signal < 50%, >= 5 drops in 7 days, DNS > 300 ms, router > 50 ms | OK |
| **Battery** (laptops only) | Health < 60% of design capacity | Health < 80% | OK |
| **Maintenance** | (rarely red) | Reboot pending, uptime > 14 days, > 15 startup entries, temp folders > 5 GB | OK |

Score = 100 - 8 per 🟡 - 18 per 🔴, minimum 0.

| Score | FR | EN |
|---|---|---|
| 90-100 | Excellent | Excellent |
| 75-89 | Bon | Good |
| 60-74 | Moyen | Fair |
| < 60 | À surveiller | Needs attention |

The score is a summary for humans. Never let it hide a red item: list every 🔴 explicitly.

## Writing rules

- Plain language first, technical detail second (event IDs, codes in parentheses).
- Use the user's own symptom as the thread: "your black screens match 15 GPU resets on 16-17/11".
- Dates in the user's locale (FR: `17/11 à 11:06`; EN: `Nov 17, 11:06`).
- Separate facts (from the snapshot) from hypotheses ("likely", "to confirm").
- Mention what was not checked (items in `meta.needsAdmin`, missing smartctl) and offer the admin step.
- 3 to 5 recommendations max, most important first, each with who does it (me after your OK / you).
- If a previous snapshot exists, include the "Since last check" section.
- Benign noise (see `events.md`) goes in one line at most, or is omitted.

## Template - Français

```
## 🩺 DesktopDiag - <nom du PC ou modèle> - <date>

**Score : <N>/100 - <verdict>**  ·  Windows <version> (build <build>) · allumé depuis <X> j

| Domaine | État | En bref |
|---|---|---|
| Stabilité | 🟢/🟡/🔴 | <ex. 2 écrans bleus en 30 j (0x3B, 0x133)> |
| Carte graphique | | |
| Espace disque | | |
| Santé des disques | | |
| Erreurs matérielles | | |
| Sécurité | | |
| Performances (maintenant) | | |
| Démarrage | | |
| Chauffe | | |
| Réseau | | |
| Batterie (portable) | | |
| Entretien | | |

### Depuis le dernier check (<date>)
- <changements clés : nouveaux plantages, espace perdu, pilote mis à jour...>

### Ce qui compte
<2 à 4 paragraphes courts sur les points 🔴 puis 🟡, avec les chiffres.>

### Recommandations
1. **<action>** - <pourquoi> - *<je peux le faire après ton accord / à faire toi-même>*
2. ...

<Non vérifié : <éléments nécessitant l'admin>. Je peux lancer l'analyse approfondie (fenêtre admin à accepter).>

### Prochain check
<Proposition selon references/followup.md, ex. « Je te propose un check de suivi le lundi 23/11 à 20:00 pour vérifier que les erreurs GPU ne reviennent pas. Je le programme ? »>
```

## Template - English

```
## 🩺 DesktopDiag - <PC name or model> - <date>

**Score: <N>/100 - <verdict>**  ·  Windows <version> (build <build>) · up <X> days

| Area | Status | Summary |
|---|---|---|
| Stability | 🟢/🟡/🔴 | <e.g. 2 blue screens in 30 days (0x3B, 0x133)> |
| Graphics | | |
| Storage space | | |
| Disk health | | |
| Hardware errors | | |
| Security | | |
| Performance (now) | | |
| Boot time | | |
| Heat | | |
| Network | | |
| Battery (laptop) | | |
| Maintenance | | |

### Since last check (<date>)
- <key changes: new crashes, space lost, driver updated...>

### What matters
<2-4 short paragraphs on 🔴 then 🟡 items, with numbers.>

### Recommendations
1. **<action>** - <why> - *<I can do it after your OK / for you to do>*
2. ...

<Not checked: <items needing admin>. I can run the deep scan (you'll need to accept an admin prompt).>

### Next check
<Proposal from references/followup.md, e.g. "I suggest a follow-up check on Monday Nov 23 at 8 PM to confirm the GPU errors don't come back. Shall I schedule it?">
```

## Share mode

When the user wants to post the report on a forum or send it to someone, re-run the collector
with `-Anonymize -OutFile <file>` and build the report from that file. Do not include serial
numbers, user names, computer names, or full file paths.
