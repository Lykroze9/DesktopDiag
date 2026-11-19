# Windows events reference

What the collector groups, what each event means, and what to do. Keys in the snapshot look
like `Provider/Id` (for example `nvlddmkm/153`, `disk/153 \Device\Harddisk1\DR1`).

Event *messages* are localized (French Windows writes French text). Rely on provider + ID,
not on message text.

## Shutdowns and crashes (`stability`)

| Event | Meaning | Notes |
|---|---|---|
| Kernel-Power 41 | The PC restarted without a clean shutdown. | `bugcheckCode` 0x0 = no blue screen: power loss, hard freeze, forced power-off (holding the button). Non-zero = a BSOD happened, the code is the stop code. |
| EventLog 6008 | "The previous system shutdown was unexpected." | Usually paired with Kernel-Power 41. |
| WER-SystemErrorReporting 1001 (System log) | A blue screen was recorded after reboot. | Contains the stop code and parameters, plus the dump path. See `bsod.md`. |
| volmgr 161 | The crash dump could not be written. | Dump missing = cause unknown from the dump. Common with hard hangs, page file too small, or storage issues during the crash. |
| volmgr 162 | Crash dump written successfully. | |
| User32 1074 | Planned restart/shutdown (user, Windows Update, an installer). | Normal. Many in a short time = an app forcing restarts. |
| EventLog 6005 / 6006 | Boot / clean shutdown. | `bootCount` counts 6005. |

**Counting trap:** the *Application* log's "Windows Error Reporting 1001" re-queues the same
report at every boot, which inflates crash counts. Count crashes from the *System* log only
(Kernel-Power 41 and WER-SystemErrorReporting 1001), which is what the collector does.

`reliabilityIndex` is Windows' own stability score (1 = bad, 10 = perfect), recomputed hourly.
Below 5 after recent crashes is expected; it climbs back slowly when the PC stays stable.

## Graphics (`gpuEvents`) - see `gpu.md`

| Event | Meaning |
|---|---|
| Display 4101 | "Display driver stopped responding and has successfully recovered" (TDR). |
| nvlddmkm 13 | NVIDIA graphics engine exception (often logged with an Xid/channel error). |
| nvlddmkm 14 | NVIDIA driver internal error. |
| nvlddmkm 153 | NVIDIA GPU/channel reset, typically the TDR recovery itself. |
| amdkmdag / amdwddmg / amduw23g errors | AMD driver timeouts or resets (AMD equivalent of TDR). |
| igfx / igfxn errors | Intel graphics driver errors. |
| DxgKrnl errors | DirectX kernel graphics errors, often alongside the vendor driver's. |

## Storage (`diskEvents`) - see `storage.md`

| Event | Meaning | Severity |
|---|---|---|
| disk 7 | Bad block on the device. | Red: back up, check SMART. |
| disk 11 | Controller error on the device. | Red if internal disk; check cable/port. |
| disk 51 | Error during a paging operation. | Red if repeated. |
| disk 153 | I/O operation was retried. | Yellow. Very common with USB disks (cable, port, enclosure, power). |
| storahci/stornvme 129 | Reset issued to the device. | Yellow/red depending on frequency: firmware, power saving, cable. |
| Ntfs 55 / 98 | File system corruption detected / volume needs checking. | Red: run a read-only scan (`Repair-Volume -Scan`), back up. |

The key includes the device (`\Device\Harddisk1\DR1` = physical disk number 1, matching
`storage.physicalDisks[].number`). Always map the error to the actual disk before concluding:
errors on an external USB disk do not mean the system SSD is failing.

## Hardware (`hardwareErrors`, `tpmEvents`, `problemDevices`)

| Event | Meaning | Severity |
|---|---|---|
| WHEA-Logger 18 | Fatal machine check (CPU/cache/bus). Usually followed by a BSOD 0x124. | Red. |
| WHEA-Logger 19 | Corrected machine check. | Yellow if a few, red if many: instability (overclock, EXPO/XMP, voltages). |
| WHEA-Logger 17 | Corrected PCIe error. | Yellow. Often a PCIe device or ASPM power saving; many = red. |
| WHEA-Logger 47 | Corrected memory error. | Yellow/red: RAM, EXPO/XMP profile. |
| TPM-related errors (TPM, TPM-WMI) | TPM/fTPM firmware problem. | Yellow: usually a BIOS update fixes it. |
| `problemDevices` errorCode 10 | Device cannot start. | Red if it is a key device. |
| errorCode 28 | No driver installed. | Yellow. |
| errorCode 43 | Device reported a problem and was stopped (classic for GPUs/USB). | Red. |
| errorCode 22 | Device disabled. | Info. |
| errorCode 45 | Device not currently connected. | Info (ghost device). |

## Services (`serviceFailures`)

| Event | Meaning |
|---|---|
| SCM 7000 / 7009 / 7011 | Service failed to start / timed out. |
| SCM 7023 / 7024 | Service stopped with an error. |
| SCM 7031 / 7034 | Service crashed unexpectedly. |
| SCM 7026 | A boot driver failed to load. |

A handful of these for game launchers, Xbox services or vendor utilities is common and usually
harmless. Flag them only when a core service fails repeatedly (for example Windows Update,
audio, networking) or when they match the user's symptom.

## Usually benign (do not alarm the user)

- DistributedCOM 10010 / 10016: permission/timeout noise from COM servers.
- Windows Firewall 2042 on Insider builds: known noise.
- Service 7023/7024 for "XboxService", "Downloaded Maps Manager" and similar when unused.
- Single DNS-Client 1014/1023, Tcpip 4207 warnings.
- Application Hang 1002 for an app the user force-closed once.

## Application crashes (`appCrashes`)

Application Error 1000 key = `app.exe [faulting module]`. Repeated crashes with the same module
point to that module (for example an overlay DLL, a GPU driver DLL such as `nvwgf2umx.dll`, or
`ntdll.dll` which is generic). Application Hang 1002 = the app stopped responding.

## Boot and throttling events

- `Microsoft-Windows-Kernel-Boot` 27 (boot type), 30 (firmware boot metrics): informational, read by the `boot` section. Not errors.
- `Microsoft-Windows-Kernel-Processor-Power` 37 (warning): CPU speed limited by firmware, usually heat or power limit. 55 is informational (processor capabilities at boot), ignore it.
- Diagnostics-Performance 100-110: admin-only boot performance log, read by `bootPerformance`.

Interpretation and thresholds: `performance.md`.
