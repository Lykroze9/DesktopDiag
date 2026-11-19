# Blue screens (BSOD) reference

Sources in the snapshot: `stability.bugchecks` (stop code + parameters), `stability.unexpectedShutdowns`
(Kernel-Power 41 with bugcheck code), `stability.minidumps`, and, with the admin script `-Dumps`,
`dumpAnalysis.results[]` (module and image that crashed, from WinDbg `!analyze -v`).

## Reading the pattern first

1. **Same stop code and same driver every time** -> that driver (update, roll back or remove the software that installs it).
2. **Different stop codes, different addresses, no common driver** -> suspect hardware instability: RAM (EXPO/XMP profile), CPU overclock/undervolt (PBO, Curve Optimizer), outdated BIOS, then PSU.
3. **Kernel-Power 41 with code 0x0 and no dump** -> hard freeze or power cut, not a classic BSOD: GPU hang, PSU, overheating, or the user forced power-off. Ask what the user saw (frozen image? black screens? sound still playing?).
4. **Crashes only under gaming load** -> GPU (see `gpu.md`), temperatures, PSU.
5. **Crashes at sleep/wake** -> 0x9F, drivers' power management, chipset driver, BIOS.

## Common stop codes

| Code | Name | Typical causes |
|---|---|---|
| 0x0A | IRQL_NOT_LESS_OR_EQUAL | A driver touched invalid memory. Look at the module. Also RAM instability. |
| 0xD1 | DRIVER_IRQL_NOT_LESS_OR_EQUAL | Faulty driver (network, Wi-Fi, USB, anti-cheat, VPN...). |
| 0x1E | KMODE_EXCEPTION_NOT_HANDLED | Driver exception. |
| 0x3B | SYSTEM_SERVICE_EXCEPTION | Driver or system service exception; c0000005 = access violation. Look at the module. |
| 0x50 | PAGE_FAULT_IN_NONPAGED_AREA | Driver bug or faulty RAM. |
| 0x1A | MEMORY_MANAGEMENT | RAM or memory profile instability; sometimes storage. |
| 0x7E | SYSTEM_THREAD_EXCEPTION_NOT_HANDLED | Driver exception (often GPU or storage drivers). |
| 0x7A | KERNEL_DATA_INPAGE_ERROR | Could not read paged data from disk: storage, cable, SSD firmware. |
| 0xF4 | CRITICAL_OBJECT_TERMINATION | Critical process died, frequently storage-related. |
| 0xEF | CRITICAL_PROCESS_DIED | Critical system process died: corruption, storage, security software. |
| 0x9F | DRIVER_POWER_STATE_FAILURE | Driver mishandled sleep/wake. |
| 0x101 | CLOCK_WATCHDOG_TIMEOUT | CPU core stopped responding: CPU overclock/undervolt, BIOS. |
| 0x124 | WHEA_UNCORRECTABLE_ERROR | Hardware error reported by the CPU: overclock, voltages, RAM, CPU, PCIe device. |
| 0x133 | DPC_WATCHDOG_VIOLATION | A driver or device blocked the system too long: storage firmware/driver, GPU hang, faulty device. |
| 0x139 | KERNEL_SECURITY_CHECK_FAILURE | Corrupted kernel structure: driver bug or RAM. |
| 0x116 | VIDEO_TDR_FAILURE | GPU did not recover from a timeout (see `gpu.md`). |
| 0x119 | VIDEO_SCHEDULER_INTERNAL_ERROR | GPU driver/scheduler error. |
| 0x154 | UNEXPECTED_STORE_EXCEPTION | Storage or memory compression store failure: SSD, RAM, antivirus drivers. |
| 0x19 | BAD_POOL_HEADER | Driver memory corruption. |
| 0xC2 / 0xC5 | BAD_POOL_CALLER / DRIVER_CORRUPTED_EXPOOL | Driver memory corruption. |

## Modules that point somewhere

`moduleName` / `imageName` from the dump analysis name the culprit, except generic kernel files.

| Module | What it belongs to |
|---|---|
| `ntoskrnl.exe`, `hal.dll`, `ntkrnlmp.exe` | Windows kernel: **not** a culprit by itself. Look at the stack or the pattern (often RAM/driver). |
| `nvlddmkm.sys` | NVIDIA display driver. |
| `amdkmdag.sys`, `atikmdag.sys`, `amdwddmg.sys` | AMD display driver. |
| `dxgkrnl.sys`, `dxgmms2.sys` | DirectX graphics kernel (GPU path, usually vendor driver or GPU hardware). |
| `vgk.sys` | Riot Vanguard anti-cheat. |
| `EasyAntiCheat*.sys`, `BEDaisy.sys` | Easy Anti-Cheat, BattlEye. |
| `AMDRyzenMasterDriver.sys` | AMD Ryzen Master / its SDK (also bundled by motherboard utilities and AMD Software metrics). Multiple versions loaded at once = conflict. |
| `RTCore64.sys` | MSI Afterburner / RivaTuner. |
| `WinRing0x64.sys` | Low-level hardware access used by fan/RGB/monitoring tools (old versions flagged as vulnerable). |
| `NTIOLib*.sys` | MSI utilities. |
| `stornvme.sys`, `storahci.sys`, `iaStor*.sys` | Storage drivers: check SSD firmware, cables, chipset driver. |
| `tcpip.sys`, `ndis.sys`, `netwtw*.sys`, `rt*.sys`, `mt*.sys` | Network stack / Wi-Fi or Ethernet drivers. |
| `wdfilter.sys`, `wdboot.sys` | Microsoft Defender (rarely the true cause). |

When a utility installs low-level drivers (overclocking, RGB, monitoring), several such tools on
the same PC is a classic source of conflicts. Recommend keeping only one.

## Dumps

- Minidumps live in `C:\Windows\Minidump`. Reading them needs admin: the admin script copies them to a temp folder before analysis.
- No minidump after a crash: `volmgr 161`, page file disabled/too small, or "Small memory dump" disabled in System Properties > Startup and Recovery.
- WinDbg (`winget install Microsoft.WinDbg`) provides `cdb.exe`. First analysis downloads symbols from Microsoft (`msdl.microsoft.com`), which can take a few minutes.
