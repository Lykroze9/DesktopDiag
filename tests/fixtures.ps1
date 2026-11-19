<#
    Synthetic DesktopDiag snapshots for tests. Generic hardware, no real machine data.
    Dot-source this file, then call New-DDSnapshot and the case helpers.
#>

function New-DDGroup {
    param([string]$Key, [datetime[]]$Times, [string]$Sample = '')
    $sorted = @($Times | Sort-Object -Descending)
    [ordered]@{
        key    = $Key
        count  = $sorted.Count
        last   = $sorted[0].ToString('s')
        first  = $sorted[-1].ToString('s')
        times  = @($sorted | ForEach-Object { $_.ToString('s') })
        sample = $Sample
    }
}

function New-DDSnapshot {
    param([datetime]$At = (Get-Date '2026-06-15T12:00:00'))
    [ordered]@{
        meta = [ordered]@{
            tool = 'DesktopDiag'; version = 'test'; kind = 'collect'; timestamp = $At.ToString('s')
            utcOffset = '+00:00'; timeZone = 'UTC'; psVersion = '5.1'; isAdmin = $false; uiCulture = 'en-US'
            windowDays = 7; crashDays = 30; full = $false; durationSec = 20; needsAdmin = @(); collectErrors = @()
        }
        system = [ordered]@{
            os = 'Microsoft Windows 11 Pro'; displayVersion = '24H2'; build = '26100.1000'; architecture = '64-bit'
            installDate = '2025-01-01T10:00:00'; lastBoot = $At.AddDays(-1).ToString('s'); uptimeDays = 1.0; insiderChannel = $null
        }
        hardware = [ordered]@{
            manufacturer = 'Contoso'; model = 'Desktop 1000'; board = 'Contoso B100'; biosVersion = '1.0'; biosDate = '2025-01-01T00:00:00'
            cpu = 'Generic 8-Core Processor'; cores = 8; threads = 16; ramTotalGB = 31.9
            ramModules = @([ordered]@{ slot = 'A1'; gb = 16; maker = 'Contoso'; part = 'X'; ratedMHz = 4800; runningMHz = 4800 },
                           [ordered]@{ slot = 'B1'; gb = 16; maker = 'Contoso'; part = 'X'; ratedMHz = 4800; runningMHz = 4800 })
            gpus = @([ordered]@{ name = 'NVIDIA GeForce RTX 0000'; driverVersion = '32.0.15.6000'; nvidiaVersion = '560.00'; driverDate = $At.AddDays(-60).ToString('s'); status = 'OK'; resolution = '2560x1440@144Hz' })
            monitors = @('CON Monitor'); isLaptop = $false
        }
        load = [ordered]@{ cpuPct = 5; ramUsedPct = 40; ramFreeGB = 19; commitUsedPct = 45; processCount = 200; topCpu = @(); topMemory = @() }
        boot = [ordered]@{ lastFirmwareSec = 9.5; avgFirmwareSec = 9.8; fastStartupEnabled = $true
            recentBoots = @([ordered]@{ time = $At.AddDays(-1).ToString('s'); firmwareSec = 9.5; bootType = 'cold' }) }
        storage = [ordered]@{
            volumes = @([ordered]@{ drive = 'C:'; label = ''; fs = 'NTFS'; type = 'fixed'; sizeGB = 930; freeGB = 400; freePct = 43 })
            physicalDisks = @([ordered]@{ number = '0'; name = 'Contoso NVMe 1TB'; media = 'SSD'; bus = 'NVMe'; sizeGB = 931.5; firmware = '1'; health = 'Healthy'; operational = 'OK'; reliability = $null })
        }
        stability = [ordered]@{
            unexpectedShutdowns = @(); bugchecks = @(); dirtyShutdownCount = 0; plannedShutdownCount = 5; bootCount = 20
            reliabilityIndex = [ordered]@{ index = 9.5; at = $At.ToString('s') }; minidumps = @(); minidumpsReadable = $true; fullMemoryDumpPresent = $false
        }
        gpuEvents = @(); diskEvents = @(); hardwareErrors = @(); tpmEvents = @(); serviceFailures = @(); topSystemErrors = @()
        appCrashes = [ordered]@{ crashes = @(); hangs = @() }
        thermal = [ordered]@{ cpuThrottleEvents = @(); cpuPerfLimitPct = 100; cpuPctOfMaxFreq = 60; cpuFrequencyMHz = 3000; thermalZones = @() }
        memoryDiagnostics = [ordered]@{ lastRun = $null; result = $null; errorsFound = $null }
        problemDevices = @()
        security = [ordered]@{
            defender = [ordered]@{ mode = 'Normal'; antivirusEnabled = $true; realTime = $true; signatureAgeDays = 0; quickScanAgeDays = 1; tamperProtection = $true }
            antivirusProducts = @([ordered]@{ name = 'Windows Defender'; enabled = $true; upToDate = $true })
            firewall = @([ordered]@{ profile = 'Domain'; enabled = $true }, [ordered]@{ profile = 'Private'; enabled = $true }, [ordered]@{ profile = 'Public'; enabled = $true })
            windowsUpdate = [ordered]@{ lastSuccess = $At.AddDays(-3).ToString('s'); recentFailures = @() }
            rebootPending = $false; uacEnabled = $true; secureBoot = $true
        }
        maintenance = [ordered]@{
            startupCount = 6; startup = @(1..6 | ForEach-Object { [ordered]@{ name = "App$_"; command = "C:\Program Files\App$_\app.exe"; location = 'HKU'; hives = 1 } })
            userTempGB = 0.5; windowsTempGB = 0.1; downloadsGB = 2
            pagefile = [ordered]@{ automatic = $true; files = @([ordered]@{ path = 'C:\pagefile.sys'; allocatedGB = 4; currentUsageGB = 0.2; peakUsageGB = 0.5 }) }
            hibernation = [ordered]@{ enabled = $true; hiberfilGB = 12.7 }
        }
        network = @([ordered]@{ name = 'Ethernet'; description = 'Contoso 2.5GbE'; status = 'Up'; linkSpeed = '1 Gbps'; driverDate = '2025-01-01T00:00:00' })
        networkHealth = [ordered]@{ wifi = $null; gatewayPingMs = 1; dnsMs = 20; dnsOk = $true; disconnects = @() }
        battery = $null
    }
}

# Each case returns @{ name; snapshot; expect = @{ area = level } }.
function Get-DDTestCases {
    $at = Get-Date '2026-06-15T12:00:00'
    $cases = @()

    $s = New-DDSnapshot -At $at
    $cases += @{ name = 'healthy'; snapshot = $s; expect = @{ stability = 'green'; graphics = 'green'; storageSpace = 'green'; diskHealth = 'green'; security = 'green'; heat = 'green' } }

    $s = New-DDSnapshot -At $at
    $s.stability.unexpectedShutdowns = @([ordered]@{ time = $at.AddDays(-2).ToString('s'); bugcheckCode = '0x3B' })
    $s.stability.bugchecks = @([ordered]@{ time = $at.AddDays(-2).ToString('s'); bugcheck = '0x0000003b (0x00000000c0000005, 0x0, 0x0, 0x0)'; dumpFile = 'C:\Windows\Minidump\x.dmp' })
    $s.stability.minidumps = @([ordered]@{ file = 'x.dmp'; date = $at.AddDays(-2).ToString('s'); kb = 900 })
    $cases += @{ name = 'bsod-recent'; snapshot = $s; expect = @{ stability = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.stability.unexpectedShutdowns = @([ordered]@{ time = $at.AddDays(-20).ToString('s'); bugcheckCode = '0x0' })
    $cases += @{ name = 'one-old-crash'; snapshot = $s; expect = @{ stability = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.gpuEvents = @(New-DDGroup 'nvlddmkm/153' @($at.AddDays(-1), $at.AddDays(-3), $at.AddDays(-9)))
    $cases += @{ name = 'gpu-tdr'; snapshot = $s; expect = @{ graphics = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.hardware.gpus[0].driverDate = $at.AddDays(-500).ToString('s')
    $cases += @{ name = 'old-gpu-driver'; snapshot = $s; expect = @{ graphics = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.storage.volumes[0].freeGB = 40; $s.storage.volumes[0].freePct = 4.3
    $cases += @{ name = 'disk-full'; snapshot = $s; expect = @{ storageSpace = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.storage.volumes[0].freeGB = 110; $s.storage.volumes[0].freePct = 11.8
    $cases += @{ name = 'disk-low'; snapshot = $s; expect = @{ storageSpace = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.storage.physicalDisks[0].reliability = [ordered]@{ temperatureC = 45; temperatureMaxC = 70; wearPct = 88; powerOnHours = 20000; readErrors = 0; readUncorrected = 0; writeErrors = 0 }
    $cases += @{ name = 'ssd-worn'; snapshot = $s; expect = @{ diskHealth = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.storage.physicalDisks[0].health = 'Warning'
    $cases += @{ name = 'disk-unhealthy'; snapshot = $s; expect = @{ diskHealth = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.storage.physicalDisks += [ordered]@{ number = '1'; name = 'USB Stick'; media = 'Unspecified'; bus = 'USB'; sizeGB = 64; firmware = '1'; health = 'Healthy'; operational = 'OK'; reliability = $null }
    $s.diskEvents = @(New-DDGroup 'disk/153 \Device\Harddisk1\DR1' @($at.AddDays(-1), $at.AddDays(-2)))
    $cases += @{ name = 'usb-retries'; snapshot = $s; expect = @{ diskHealth = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.hardwareErrors = @(New-DDGroup 'WHEA/18' @($at.AddDays(-4)))
    $cases += @{ name = 'whea-fatal'; snapshot = $s; expect = @{ hardwareErrors = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.memoryDiagnostics = [ordered]@{ lastRun = $at.AddDays(-5).ToString('s'); result = 'errors'; errorsFound = $true }
    $cases += @{ name = 'ram-test-failed'; snapshot = $s; expect = @{ hardwareErrors = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.security.defender.realTime = $false
    $cases += @{ name = 'realtime-off'; snapshot = $s; expect = @{ security = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.security.windowsUpdate.lastSuccess = $at.AddDays(-45).ToString('s')
    $cases += @{ name = 'updates-old'; snapshot = $s; expect = @{ security = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.load.ramUsedPct = 93
    $cases += @{ name = 'ram-full'; snapshot = $s; expect = @{ performance = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.boot.lastFirmwareSec = 38; $s.boot.avgFirmwareSec = 36
    $cases += @{ name = 'slow-firmware'; snapshot = $s; expect = @{ bootTime = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.thermal.cpuThrottleEvents = @(New-DDGroup 'Kernel-Processor-Power/37' @($at.AddDays(-1), $at.AddDays(-2), $at.AddDays(-3)))
    $cases += @{ name = 'throttling'; snapshot = $s; expect = @{ heat = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.system.uptimeDays = 21; $s.maintenance.startupCount = 18
    $cases += @{ name = 'maintenance'; snapshot = $s; expect = @{ maintenance = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.hardware.isLaptop = $true
    $s.battery = [ordered]@{ chargePct = 80; status = 2; healthPct = 55; designWh = 60; fullWh = 33; cycleCount = 900 }
    $cases += @{ name = 'battery-worn'; snapshot = $s; expect = @{ battery = 'red' } }

    $s = New-DDSnapshot -At $at
    $s.networkHealth.wifi = [ordered]@{ ssidHidden = $true; signalPct = 30; band = '2.4 GHz'; rxMbps = 72; txMbps = 72 }
    $s.networkHealth.disconnects = @(New-DDGroup 'WLAN-AutoConfig/8003' @($at.AddDays(-1), $at.AddDays(-1).AddHours(2), $at.AddDays(-2), $at.AddDays(-3), $at.AddDays(-4), $at.AddDays(-5)))
    $cases += @{ name = 'wifi-weak'; snapshot = $s; expect = @{ network = 'yellow' } }

    $s = New-DDSnapshot -At $at
    $s.networkHealth.dnsOk = $false; $s.networkHealth.dnsMs = $null
    $cases += @{ name = 'dns-down'; snapshot = $s; expect = @{ network = 'red' } }

    return $cases
}
