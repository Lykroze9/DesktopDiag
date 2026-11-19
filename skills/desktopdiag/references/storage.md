# Storage: free space, SSD health, disk errors

Sources: `storage.volumes`, `storage.physicalDisks` (health + reliability counters, counters
often empty without admin), `diskEvents`, and from the admin script `reliability`, `smart`
(smartctl) and `volumeScan`.

## Free space (system drive)

| Free on system drive | Rating |
|---|---|
| >= 15% and >= 30 GB | Green |
| < 15% or < 30 GB | Yellow: Windows updates, page file and SSD performance suffer. |
| < 8% or < 15 GB | Red |

Data drives: yellow under 10%, red under 5%. Reclaimable space (temp, Downloads) is information,
not a score penalty: show sizes and let the user decide.

## SSD / NVMe health (smartctl or reliability counters)

| Indicator | Green | Yellow | Red |
|---|---|---|---|
| `smartPassed` / `health` | true / Healthy | | false / Warning / Unhealthy |
| NVMe `criticalWarning` | 0 | | anything else |
| NVMe `mediaErrors` | 0 | | > 0 |
| NVMe `percentageUsed` (wear) | < 80 | 80-99 | >= 100 (rated endurance reached) |
| NVMe `availableSparePct` | > threshold + 10 | close to threshold | <= `spareThresholdPct` |
| NVMe `warningTempMinutes` / `criticalTempMinutes` | 0 or low | warning time growing | critical time > 0 recently |
| SATA attr 5 / 197 / 198 raw (reallocated / pending / uncorrectable) | 0 | | > 0 |
| SATA attr 199 raw (CRC errors) | 0 | > 0: cable/port | |
| Reliability `wearPct` | < 80 | 80-99 | >= 100 |

Context worth giving the user:
- `percentageUsed` is the manufacturer's endurance estimate, not remaining life. Many drives
  keep working past 100%, but backups become essential.
- `dataWrittenTB` vs the drive's rated TBW (check the model's datasheet) tells how much
  endurance has been used.
- Lots of `unsafeShutdowns` match forced power-offs and crashes; not a defect by itself.
- An NVMe drive spending time above its warning temperature at light load usually lacks a
  heatsink or airflow. Thermal throttling causes stutters and slow copies.

## Disk errors in the event log

Always map the error to the right disk: `\Device\HarddiskN\DRN` = `physicalDisks[].number` N.

- **External USB disk with `disk/153` retries:** usually cable, USB port (prefer a rear port),
  enclosure, or power (2.5" disks on unpowered hubs). USB selective suspend can contribute.
  Advise backing up what matters on it, then testing another cable/port.
- **Internal disk with `disk/7`, `disk/51`, `Ntfs/55`:** back up first, then run the read-only
  scan and SMART check.
- **`stornvme/129` or `storahci/129` resets:** SSD firmware update, chipset driver, disable
  aggressive power saving (PCIe Link State Power Management) as a test, check cable for SATA.

## Read-only file system scan

`Repair-Volume -DriveLetter C -Scan` (admin) is read-only and works where `chkdsk` may answer
"Access denied" in some sandboxed or non-interactive shells. Results: `NoErrorsFound`,
`ScanNeeded`, `SpotFixNeeded`, `FullRepairNeeded`. Anything but `NoErrorsFound` -> recommend a
repair the user launches themselves (`chkdsk C: /scan` then `/spotfix`, or a full `chkdsk /f`
at next reboot), after a backup.

## Tools

- smartmontools: `winget install smartmontools.smartmontools` (smartctl needs admin on Windows).
- CrystalDiskInfo: friendly GUI for SMART, good to suggest to non-technical users.
- Manufacturer tools (Samsung Magician, Crucial Storage Executive, WD Dashboard...) for firmware updates.
