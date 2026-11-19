# Graphics card: freezes, black screens, driver resets

Use when `gpuEvents` is not empty, or the user reports: black screens for a few seconds, screen
freezes with sound still playing, "display driver stopped responding", artifacts, game crashes
to desktop, crashes only in games, monitors turning off.

## What a TDR is

Windows gives the GPU about 2 seconds to answer. If it does not, Windows resets the driver
(Timeout Detection and Recovery). The user sees the screen freeze or go black, then come back
(Display 4101, nvlddmkm 153). If the reset fails, it becomes a BSOD 0x116 / 0x119, or a hard
hang with Kernel-Power 41 code 0 or 0x133.

**Hint:** if sound keeps playing while the image is frozen, the CPU and system are still alive:
it is the GPU/display path, not the whole PC or the power supply cutting out.

Raising `TdrDelay` in the registry only hides the symptom. Do not recommend it as a fix.

## Triage order (cheapest and safest first)

1. **Correlate.** When did the events start? Did they begin after a driver update
   (`hardware.gpus[].driverDate`), a new game, a new monitor, or an overclocking tool?
2. **Overclocking/tuning tools at startup.** Look in `maintenance.startup` for MSI Afterburner,
   EVGA Precision, ASUS GPU Tweak, vendor "game boost" utilities. A factory or manual overclock
   that was stable can become unstable as the card ages or gets dusty. Suggest resetting to
   defaults as a test.
3. **Temperatures under load.** Ask the user to monitor with HWiNFO or GPU-Z while gaming.
   Watch the hotspot and memory junction temperatures, not only the core. Thermal throttling,
   fans at 100% and hotspot well above core temperature mean cooling trouble: dust, then
   thermal paste/pads. Undervolting or a lower power limit (for example 80%) reduces heat and
   transient spikes at a small performance cost and is a good test.
4. **Clean driver reinstall.** Use DDU (Display Driver Uninstaller) in Safe Mode, then install a
   known-stable driver. If problems started with a new driver, try the previous version; if the
   driver is old, try the latest. Disable automatic driver updates by Windows during the test.
5. **Multi-monitor setups.** Mixed refresh rates or a mix of DisplayPort/HDMI can trigger resets
   on some drivers. Test with a single monitor; reseat or replace cables.
6. **Power.** Use separate PCIe power cables from the PSU (no single daisy-chained cable for a
   high-power card). An aging or undersized PSU can drop out on transient spikes. If sound stops
   too and the PC reboots, power becomes more likely.
7. **Hardware.** Reseat the card, try another PCIe slot, set the PCIe slot to Gen3/Gen4 in the
   BIOS as a test. If everything above fails and errors continue at stock settings, the card
   may be faulty (warranty).
8. **Windows settings to test (reversible).** Hardware-accelerated GPU scheduling on/off
   (Settings > Display > Graphics), game overlays (Discord, Steam, NVIDIA/AMD overlay) off.

## Stress testing

OCCT, 3DMark, FurMark or Unigine can reproduce a fault, but a stress test on an unstable card
can freeze the PC. Always tell the user, have them save their work, and never start one without
explicit consent. Compare temperatures and clock behaviour before/after each change.

## Vendor specifics

- **NVIDIA:** friendly driver version is in `hardware.gpus[].nvidiaVersion` (e.g. `621.01`).
  nvlddmkm 13 + 153 together = engine exception followed by reset.
- **AMD:** errors from `amdkmdag`/`amdwddmg`; AMD Software can also report "driver timeout".
  Also check the AMD Software overlay/metrics.
- **Laptops with two GPUs:** check which GPU the game uses, and the power plan.
- **Integrated + dedicated GPU on a desktop:** the iGPU appears in the list too; monitors should
  be plugged into the dedicated card.
