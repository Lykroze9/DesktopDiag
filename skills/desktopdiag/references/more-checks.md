# RAM test, battery, network, page file and hibernation

## Windows Memory Diagnostic (`memoryDiagnostics`)

Read from `Microsoft-Windows-MemoryDiagnostics-Results` in the System log (latest result only).

- `lastRun` null: the test was never run (or its result was cleared). Normal for most PCs.
- `result = noErrors` (event 1101/1201): RAM passed the last test. It is a basic test: it does not
  rule out every RAM problem, especially with EXPO/XMP overclocked memory.
- `result = errors` (event 1102/1202): hardware errors detected. Red. Check `sample` to confirm.

When to suggest running it (user does it, needs a reboot, 10-20 min): random blue screens with
different stop codes (0x1A, 0x50, 0x3B, 0x0A, 0x139...), WHEA memory errors, crashes that started
after a RAM change or enabling EXPO/XMP. Launch: Start > "Windows Memory Diagnostic" > "Restart now
and check for problems". After the reboot, run a new check: the result appears here.
For EXPO/XMP systems, also suggest testing once with EXPO/XMP disabled before blaming the sticks.
MemTest86 (bootable USB) is more thorough if the user is comfortable with it.

## Battery (`battery`, laptops only)

From `powercfg /batteryreport` (no admin): `designWh` (capacity when new), `fullWh` (capacity
today), `healthPct` = fullWh / designWh, `cycleCount` (charge cycles, not always reported).
`status` 1 = discharging (on battery), 2 = on AC.

| healthPct | Reading |
|---|---|
| >= 80% | Normal wear |
| 60-79% | Worn: less autonomy, still fine for daily use |
| < 60% | Heavily worn: replacement worth considering, especially if the laptop shuts down at 10-20% |

Some vendors report a design capacity that is off; if `healthPct` is above 100 or `fullWh` is 0,
say the reading is unreliable. Battery life also depends on `load` (a process eating CPU drains
it): check `load.topCpu` before blaming the battery. Tips: vendor charge limit (e.g. 80%) for
laptops always plugged in, avoid heat.

## Network (`networkHealth`)

- `wifi`: only when connected to Wi-Fi. `signalPct` from netsh (Windows' 0-100 scale): >= 70 good,
  50-69 fair, < 50 weak. `band` (2.4 GHz reaches farther but is slower and more crowded; 5/6 GHz
  faster, shorter range), `rxMbps`/`txMbps` current link rates. The network name is not collected.
- `gatewayPingMs`: average ping to the router (3 pings). -1 = no reply (some routers block ping:
  only a problem together with other symptoms). Wired normal < 2 ms, Wi-Fi < 10 ms.
- `dnsMs`: best of two lookups of Microsoft connectivity-test names (the same Windows uses to
  detect internet access). `dnsOk = false` with a working router = DNS problem: suggest restarting
  the router, then a public DNS (the user changes it in Settings > Network). Over 300 ms = slow.
- `disconnects`: Wi-Fi disconnections (WLAN-AutoConfig 8003) and Ethernet link drops (event 27
  from the network card's driver) in the last `windowDays`. Some are normal (sleep, moving away);
  >= 5 in 7 days while the PC is in use is worth investigating: Wi-Fi driver (network card vendor
  or PC vendor site, not the generic Windows one), power saving on the adapter, cable/port.
- VPN adapters are not physical adapters: their disconnects are not counted.

## Page file and hibernation file (`maintenance.pagefile`, `maintenance.hibernation`)

Both are hidden system files on C: that can take a lot of space.

- Page file: `automatic` true is the recommended setting. `allocatedGB` is its current size,
  `peakUsageGB` the highest use since boot. A manual page file that is tiny (< 2 GB) or disabled
  can cause "out of memory" crashes in games and creative apps even with free RAM: suggest going
  back to automatic. Never suggest disabling it to save space.
- Hibernation file: `hiberfilGB` is often 40% of RAM (12-13 GB with 32 GB of RAM). On a desktop
  that never hibernates, turning hibernation off frees that space but also turns off Fast Startup
  (`powercfg /hibernate off`, admin, reversible with `/hibernate on`). On laptops, keep it: it
  protects against battery drain. Offer it only when C: space is yellow or red, as a proposal with
  its trade-off (see `remediation.md`).
