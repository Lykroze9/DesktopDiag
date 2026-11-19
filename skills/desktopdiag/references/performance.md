# Boot time, CPU throttling and temperatures

## Boot time

Two sources, read both when available.

### `boot` (no admin, collect.ps1)

From `Microsoft-Windows-Kernel-Boot` events in the System log.

- `firmwareSec`: time from power-on/reset to the moment the boot manager starts loading Windows
  (event 30, `LoadOSImageStart`). It is firmware (POST, memory training, RAID/USB init) plus the
  boot menu and BitLocker unlock. Task Manager's "Last BIOS time" is the same idea.
- `bootType` (event 27): `cold` = full boot, `fastStartup` = hybrid boot from a "Shut down" with
  Fast Startup on, `resumeHibernate` = resume from hibernation.
- `fastStartupEnabled`: Windows' Fast Startup (HiberbootEnabled).

| firmwareSec | Reading |
|---|---|
| < 15 s | Normal |
| 15-30 s | Common on AMD AM5 boards (DDR5 memory training) and boards with many USB/RAID controllers. Yellow only if the user complains |
| > 30 s | Yellow: long firmware phase |

Typical causes of long firmware time and what to suggest (user does it, in the BIOS):
- AM5 / DDR5: enable **Memory Context Restore** (MCR) if the board offers it; the first boot after
  a BIOS update, a CMOS reset or an EXPO/XMP change is always long (memory retraining), not a fault.
- Fast Boot option disabled in the BIOS, CSM/legacy boot enabled, unused RAID/SATA controllers.
- A USB drive or a dock connected at boot (the firmware scans it).
- Never advise a BIOS update only for boot time.

Fast Startup notes:
- With Fast Startup on, "Shut down" does not reset the kernel: `uptimeDays` keeps growing and
  driver problems survive a shutdown. A **Restart** is always a cold boot. When an uptime looks
  wrong or a driver fix "did not work", tell the user to use Restart, not Shut down.
- Fast Startup can cause dual-boot and USB/Wi-Fi wake issues. Mention it only if relevant.

### `bootPerformance` (admin, collect-admin.ps1)

From `Microsoft-Windows-Diagnostics-Performance/Operational` (admin-only log).

- `bootSec`: whole boot including the post-boot phase (desktop usable).
- `mainPathSec`: power-on of Windows to desktop shown. `postBootSec`: desktop shown to idle.
- `degraded`: Windows itself flagged this boot as slower than usual.
- `slowdowns`: events 101-110, what delayed boots: 101 application, 102 driver, 103 service,
  106 background optimisation, 109 device. `avgDelaySec` is the average extra time it caused.

| bootSec (SSD system drive) | Reading |
|---|---|
| < 60 s | Normal (includes the post-boot phase, so 30-50 s is typical) |
| 60-120 s | Yellow: look at `slowdowns` and `maintenance.startup` |
| > 120 s | Red: something is clearly wrong (startup app, failing disk, driver timeout) |

On an HDD system drive, add ~60 s to each threshold and recommend an SSD.

A slowdown that comes back on most boots with `avgDelaySec` > 10 s is worth naming in the
report (e.g. "the Riot Vanguard service delays each boot by ~12 s").

## CPU throttling

`thermal.cpuThrottleEvents` groups `Microsoft-Windows-Kernel-Processor-Power` event **37**:
"The speed of processor X in group Y is being limited by system firmware". The firmware lowers
the CPU speed, usually because of **heat** or a **power limit**.

| Pattern | Reading |
|---|---|
| None | Normal |
| A few, laptop on battery or in a power-saver mode | Benign: power limit |
| Repeated on a desktop, or on a laptop on AC power | Yellow: cooling problem likely |
| Repeated + crashes, freezes or the user reports heat/fan noise | Red |

Live counters (sampled once during the collect):
- `cpuPerfLimitPct`: 100 = no limit right now. Below 100 at idle means the CPU is being held back
  now (heat, power, or a firmware limit).
- `cpuPctOfMaxFreq` and `cpuFrequencyMHz`: low values at idle are **normal** power saving. Never
  flag them alone.

Ordered advice for throttling (user does it):
1. Check that fans spin and vents are clean (dust); laptop on a hard, flat surface.
2. Windows power mode: "Balanced" or "Best performance" on AC.
3. Undervolting or overclocking tools at startup (Ryzen Master, MSI Afterburner, ThrottleStop,
   Intel XTU): an aggressive profile can both throttle and crash. See `gpu.md` for OC tools.
4. Laptop: vendor control app (performance profile), BIOS update only if the vendor lists a
   thermal fix.
5. Old PC (4+ years): thermal paste replacement, by the user or a technician.

## Temperatures

- `thermal.thermalZones`: ACPI thermal zones. Present mostly on laptops. Many desktops expose
  none, and some report a fixed fake value (e.g. always 27.8 °C or 29.8 °C): if the value is
  identical across snapshots, ignore it. `passiveLimitPct` < 100 means the zone is actively
  slowing the CPU down.
- NVMe/SSD temperatures: see `storage.md`.
- Real CPU and GPU core temperatures are not exposed to Windows without vendor drivers. When the
  user worries about heat and the data is inconclusive, suggest a monitoring tool they install
  themselves (HWiNFO, or the GPU vendor's overlay), and what to look for: CPU > 95 °C or GPU
  > 85 °C under load is too hot for most models.

## In the report

- "Démarrage" / "Boot time" row: give the firmware time and, if the admin step ran, the full boot
  time and the main slowdown. "No data" is 🟢, not a problem.
- "Chauffe" / "Heat" row: number of throttling events and when, live limit, thermal zone if real.
- Facts vs hypotheses: throttling events prove the CPU was slowed, not why. Say "probably heat"
  unless the user is on battery.
