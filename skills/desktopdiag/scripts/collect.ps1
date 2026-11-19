<#
.SYNOPSIS
    DesktopDiag - read-only Windows health collector. No admin rights required.

.DESCRIPTION
    Gathers system, hardware, stability, GPU, storage, security and maintenance data
    and writes one JSON snapshot. Nothing on the system is modified: the only write is
    the snapshot file itself (history folder and/or -OutFile).

    Compatible with Windows PowerShell 5.1 and PowerShell 7, Windows 10 and 11.

.PARAMETER Days
    Window (days) for general error statistics. Default 7.
.PARAMETER CrashDays
    Window (days) for crashes, GPU resets, disk and hardware errors. Default 30.
.PARAMETER OutFile
    Extra path to write the JSON to.
.PARAMETER NoSave
    Do not store the snapshot in the history folder (%LOCALAPPDATA%\DesktopDiag\history).
.PARAMETER Anonymize
    Replace user name, computer name and profile paths in the written JSON.
.PARAMETER Full
    Also run slower checks (winget pending upgrades, signed driver inventory).
.PARAMETER Stdout
    Print the JSON to stdout instead of a short summary.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File collect.ps1
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [int]$CrashDays = 30,
    [string]$OutFile,
    [switch]$NoSave,
    [switch]$Anonymize,
    [switch]$Full,
    [switch]$Stdout
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$DDVersion = '0.1.0'
$now = Get-Date
$script:collectErrors = New-Object System.Collections.Generic.List[string]

function Invoke-Safe {
    param([string]$Name, [scriptblock]$Block)
    try { & $Block }
    catch {
        $script:collectErrors.Add(('{0}: {1}' -f $Name, $_.Exception.Message))
    }
}

function ConvertTo-Iso {
    param($Value)
    if ($null -eq $Value) { return $null }
    try { return ([datetime]$Value).ToString('s') } catch { return $null }
}

function ConvertTo-GB {
    param($Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(([double]$Bytes) / 1GB, 1)
}

function Get-PropValue {
    param($EventRecord, [int]$Index)
    try {
        if ($EventRecord.Properties.Count -gt $Index) { return $EventRecord.Properties[$Index].Value }
    } catch {}
    return $null
}

function Get-ShortMessage {
    param($EventRecord, [int]$Max = 220)
    $m = $null
    try { $m = $EventRecord.Message } catch {}
    if (-not $m) { return $null }
    $m = ($m -replace '\s+', ' ').Trim()
    if ($m.Length -gt $Max) { $m = $m.Substring(0, $Max) + '...' }
    return $m
}

function Get-FolderSizeGB {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $sum = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $sum += $_.Length }
    return ConvertTo-GB $sum
}

function Get-NvidiaFriendlyVersion {
    param([string]$DriverVersion)
    # 32.0.16.2101 -> 621.01
    try {
        $p = $DriverVersion -split '\.'
        $s = $p[2] + $p[3]
        $s = $s.Substring($s.Length - 5)
        return ('{0}.{1}' -f $s.Substring(0, 3), $s.Substring(3))
    } catch { return $null }
}

$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

$snap = [ordered]@{}
$snap.meta = [ordered]@{
    tool        = 'DesktopDiag'
    version     = $DDVersion
    kind        = 'collect'
    timestamp   = $now.ToString('s')
    utcOffset   = $now.ToString('zzz')
    timeZone    = [TimeZoneInfo]::Local.Id
    psVersion   = $PSVersionTable.PSVersion.ToString()
    isAdmin     = $isAdmin
    uiCulture   = (Get-UICulture).Name
    windowDays  = $Days
    crashDays   = $CrashDays
    full        = [bool]$Full
}

# ---------------------------------------------------------------- system
$os = Invoke-Safe 'os' { Get-CimInstance Win32_OperatingSystem }
$cs = Invoke-Safe 'computersystem' { Get-CimInstance Win32_ComputerSystem }
$cv = Invoke-Safe 'currentversion' { Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' }

$snap.system = Invoke-Safe 'system' {
    $boot = $os.LastBootUpTime
    [ordered]@{
        os             = $os.Caption
        displayVersion = $cv.DisplayVersion
        build          = ('{0}.{1}' -f $os.BuildNumber, $cv.UBR)
        architecture   = $os.OSArchitecture
        installDate    = ConvertTo-Iso $os.InstallDate
        lastBoot       = ConvertTo-Iso $boot
        uptimeDays     = [math]::Round(($now - $boot).TotalDays, 1)
        insiderChannel = Invoke-Safe 'insider' { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\Applicability' -ErrorAction Stop).BranchName }
    }
}

# ---------------------------------------------------------------- hardware
$snap.hardware = Invoke-Safe 'hardware' {
    $bios = Get-CimInstance Win32_BIOS
    $bb = Get-CimInstance Win32_BaseBoard
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [ordered]@{
            slot       = $_.DeviceLocator
            gb         = ConvertTo-GB $_.Capacity
            maker      = $_.Manufacturer
            part       = ($_.PartNumber -as [string]).Trim()
            ratedMHz   = $_.Speed
            runningMHz = $_.ConfiguredClockSpeed
        }
    })
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        $friendly = $null
        if ($_.Name -match 'NVIDIA') { $friendly = Get-NvidiaFriendlyVersion $_.DriverVersion }
        [ordered]@{
            name            = $_.Name
            driverVersion   = $_.DriverVersion
            nvidiaVersion   = $friendly
            driverDate      = ConvertTo-Iso $_.DriverDate
            status          = $_.Status
            resolution      = if ($_.CurrentHorizontalResolution) { '{0}x{1}@{2}Hz' -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution, $_.CurrentRefreshRate } else { $null }
        }
    })
    $monitors = @(Invoke-Safe 'monitors' {
        Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
            $n = ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
            $m = ($_.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
            ('{0} {1}' -f $m, $n).Trim()
        }
    })
    [ordered]@{
        manufacturer = $cs.Manufacturer
        model        = $cs.Model
        board        = ('{0} {1}' -f $bb.Manufacturer, $bb.Product).Trim()
        biosVersion  = $bios.SMBIOSBIOSVersion
        biosDate     = ConvertTo-Iso $bios.ReleaseDate
        cpu          = ($cpu.Name -as [string]).Trim()
        cores        = $cpu.NumberOfCores
        threads      = $cpu.NumberOfLogicalProcessors
        ramTotalGB   = ConvertTo-GB $cs.TotalPhysicalMemory
        ramModules   = $ram
        gpus         = $gpus
        monitors     = $monitors
        isLaptop     = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    }
}

# ---------------------------------------------------------------- load (real %, sampled)
$snap.load = Invoke-Safe 'load' {
    $threads = [int]$env:NUMBER_OF_PROCESSORS
    if ($threads -lt 1) { $threads = 1 }
    $null = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process
    Start-Sleep -Milliseconds 1500
    $cpuTotal = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
    # Aggregate multi-instance processes (brave#1, brave#2...) under one name.
    $topCpu = @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } |
        Group-Object { $_.Name -replace '#\d+$', '' } | ForEach-Object {
            [ordered]@{
                name      = $_.Name
                instances = $_.Count
                cpuPct    = [math]::Round((($_.Group | Measure-Object PercentProcessorTime -Sum).Sum) / $threads, 1)
            }
        } | Sort-Object { $_.cpuPct } -Descending | Select-Object -First 8 | Where-Object { $_.cpuPct -gt 0 })
    $topMem = @(Get-Process | Group-Object ProcessName | ForEach-Object {
        [ordered]@{
            name      = $_.Name
            instances = $_.Count
            memMB     = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB)
        }
    } | Sort-Object { $_.memMB } -Descending | Select-Object -First 8)
    $totalKB = [double]$os.TotalVisibleMemorySize
    $freeKB = [double]$os.FreePhysicalMemory
    [ordered]@{
        cpuPct         = $cpuTotal
        ramUsedPct     = [math]::Round((1 - $freeKB / $totalKB) * 100)
        ramFreeGB      = [math]::Round($freeKB / 1MB, 1)
        commitUsedPct  = [math]::Round((1 - [double]$os.FreeVirtualMemory / [double]$os.TotalVirtualMemorySize) * 100)
        processCount   = @(Get-Process).Count
        topCpu         = $topCpu
        topMemory      = $topMem
    }
}

# ---------------------------------------------------------------- storage
$snap.storage = Invoke-Safe 'storage' {
    $vols = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3 OR DriveType=2' | Where-Object { $_.Size } | ForEach-Object {
        [ordered]@{
            drive     = $_.DeviceID
            label     = $_.VolumeName
            fs        = $_.FileSystem
            type      = if ($_.DriveType -eq 2) { 'removable' } else { 'fixed' }
            sizeGB    = ConvertTo-GB $_.Size
            freeGB    = ConvertTo-GB $_.FreeSpace
            freePct   = [math]::Round(([double]$_.FreeSpace / [double]$_.Size) * 100, 1)
        }
    })
    $disks = @(Invoke-Safe 'physicaldisk' {
        Get-PhysicalDisk | ForEach-Object {
            $pd = $_
            $rel = Invoke-Safe 'reliability' { $pd | Get-StorageReliabilityCounter }
            [ordered]@{
                number      = $pd.DeviceId
                name        = $pd.FriendlyName
                media       = [string]$pd.MediaType
                bus         = [string]$pd.BusType
                sizeGB      = ConvertTo-GB $pd.Size
                firmware    = $pd.FirmwareVersion
                health      = [string]$pd.HealthStatus
                operational = ($pd.OperationalStatus -join ',')
                reliability = if ($rel) {
                    [ordered]@{
                        temperatureC     = $rel.Temperature
                        temperatureMaxC  = $rel.TemperatureMax
                        wearPct          = $rel.Wear
                        powerOnHours     = $rel.PowerOnHours
                        readErrors       = $rel.ReadErrorsTotal
                        readUncorrected  = $rel.ReadErrorsUncorrected
                        writeErrors      = $rel.WriteErrorsTotal
                    }
                } else { $null }
            }
        }
    })
    [ordered]@{ volumes = $vols; physicalDisks = $disks }
}

# ---------------------------------------------------------------- events
$crashStart = $now.AddDays(-$CrashDays)
$winStart = $now.AddDays(-$Days)

$sysEvents = @(Invoke-Safe 'events-system' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2, 3; StartTime = $crashStart } -MaxEvents 30000 -ErrorAction Stop
})
$lifecycle = @(Invoke-Safe 'events-lifecycle' {
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1074, 6005, 6006, 6008; StartTime = $crashStart } -ErrorAction Stop
})

function New-EventGroup {
    param($Events, [scriptblock]$KeyBlock, [int]$MaxTimes = 50)
    @($Events | Group-Object -Property $KeyBlock | Sort-Object Count -Descending | ForEach-Object {
        $sorted = $_.Group | Sort-Object TimeCreated -Descending
        [ordered]@{
            key      = $_.Name
            count    = $_.Count
            last     = ConvertTo-Iso $sorted[0].TimeCreated
            first    = ConvertTo-Iso $sorted[-1].TimeCreated
            times    = @($sorted | Select-Object -First $MaxTimes | ForEach-Object { ConvertTo-Iso $_.TimeCreated })
            sample   = Get-ShortMessage $sorted[0]
        }
    })
}

$snap.stability = Invoke-Safe 'stability' {
    $kp41 = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -eq 41 } | Sort-Object TimeCreated -Descending)
    $bug = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-WER-SystemErrorReporting' -and $_.Id -eq 1001 } | Sort-Object TimeCreated -Descending)
    $dirty = @($lifecycle | Where-Object { $_.Id -eq 6008 })
    $planned = @($lifecycle | Where-Object { $_.Id -eq 1074 })
    $boots = @($lifecycle | Where-Object { $_.Id -eq 6005 })
    $stabIndex = Invoke-Safe 'reliabilityindex' {
        $r = Get-CimInstance Win32_ReliabilityStabilityMetrics -ErrorAction Stop | Sort-Object TimeGenerated -Descending | Select-Object -First 1
        if ($r) { [ordered]@{ index = [math]::Round($r.SystemStabilityIndex, 2); at = ConvertTo-Iso $r.TimeGenerated } }
    }
    $dumps = Invoke-Safe 'minidumps' {
        @(Get-ChildItem -LiteralPath "$env:SystemRoot\Minidump" -Filter *.dmp -ErrorAction Stop | Sort-Object LastWriteTime -Descending | Select-Object -First 15 | ForEach-Object {
            [ordered]@{ file = $_.Name; date = ConvertTo-Iso $_.LastWriteTime; kb = [math]::Round($_.Length / 1KB) }
        })
    }
    $fullDump = Test-Path -LiteralPath "$env:SystemRoot\MEMORY.DMP"
    [ordered]@{
        unexpectedShutdowns = @($kp41 | ForEach-Object {
            $code = Get-PropValue $_ 0
            [ordered]@{
                time         = ConvertTo-Iso $_.TimeCreated
                bugcheckCode = if ($code) { '0x{0:X}' -f [int64]$code } else { '0x0' }
            }
        })
        bugchecks = @($bug | ForEach-Object {
            [ordered]@{
                time     = ConvertTo-Iso $_.TimeCreated
                bugcheck = [string](Get-PropValue $_ 0)
                dumpFile = [string](Get-PropValue $_ 1)
            }
        })
        dirtyShutdownCount = $dirty.Count
        plannedShutdownCount = $planned.Count
        bootCount = $boots.Count
        reliabilityIndex = $stabIndex
        minidumps = $dumps
        minidumpsReadable = ($null -ne $dumps)
        fullMemoryDumpPresent = $fullDump
    }
}

$gpuProviders = @('nvlddmkm', 'amdkmdag', 'amdkmdap', 'amdwddmg', 'amduw23g', 'igfx', 'igfxn', 'igfxnd', 'Display', 'Microsoft-Windows-DxgKrnl')
$diskProviders = @('disk', 'stornvme', 'storahci', 'Ntfs', 'volmgr', 'iaStorA', 'iaStorAC', 'iaStorAVC', 'partmgr', 'nvstor', 'amdsata', 'USBSTOR', 'Microsoft-Windows-Ntfs', 'Microsoft-Windows-StorPort')
$scmIds = @(7000, 7001, 7009, 7011, 7022, 7023, 7024, 7026, 7031, 7034, 7043)

$snap.gpuEvents = @(Invoke-Safe 'gpuEvents' {
    $ev = @($sysEvents | Where-Object { $gpuProviders -contains $_.ProviderName })
    New-EventGroup $ev { '{0}/{1}' -f $_.ProviderName, $_.Id }
})

$snap.diskEvents = @(Invoke-Safe 'diskEvents' {
    $ev = @($sysEvents | Where-Object { $diskProviders -contains $_.ProviderName })
    New-EventGroup $ev {
        $dev = [string](Get-PropValue $_ 0)
        if ($dev -notmatch 'Harddisk|\\Device\\|^[A-Z]:') { $dev = '' }
        ('{0}/{1} {2}' -f $_.ProviderName, $_.Id, $dev).Trim()
    }
})

$snap.hardwareErrors = @(Invoke-Safe 'whea' {
    $ev = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-WHEA-Logger' })
    New-EventGroup $ev { 'WHEA/{0}' -f $_.Id }
})

$snap.tpmEvents = @(Invoke-Safe 'tpm' {
    $ev = @($sysEvents | Where-Object { $_.ProviderName -match 'TPM' -and $_.Level -le 2 })
    New-EventGroup $ev { '{0}/{1}' -f $_.ProviderName, $_.Id } 10
})

$snap.serviceFailures = @(Invoke-Safe 'services' {
    $ev = @($sysEvents | Where-Object { $_.ProviderName -eq 'Service Control Manager' -and $scmIds -contains $_.Id -and $_.TimeCreated -ge $winStart })
    New-EventGroup $ev { '{0} {1}' -f $_.Id, [string](Get-PropValue $_ 0) } 10
})

$snap.topSystemErrors = @(Invoke-Safe 'topSystemErrors' {
    $ev = @($sysEvents | Where-Object { $_.Level -le 2 -and $_.TimeCreated -ge $winStart })
    @(New-EventGroup $ev { '{0}/{1}' -f $_.ProviderName, $_.Id } 5 | Select-Object -First 15)
})

$snap.appCrashes = Invoke-Safe 'appCrashes' {
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000, 1002; StartTime = $winStart } -ErrorAction SilentlyContinue)
    $crash = @($ev | Where-Object { $_.Id -eq 1000 })
    $hang = @($ev | Where-Object { $_.Id -eq 1002 })
    [ordered]@{
        crashes = @(New-EventGroup $crash { '{0} [{1}]' -f [string](Get-PropValue $_ 0), [string](Get-PropValue $_ 3) } 5 | Select-Object -First 10)
        hangs   = @(New-EventGroup $hang { [string](Get-PropValue $_ 0) } 5 | Select-Object -First 10)
    }
}

# ---------------------------------------------------------------- devices
$snap.problemDevices = @(Invoke-Safe 'problemDevices' {
    @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' | ForEach-Object {
        [ordered]@{ name = $_.Name; class = $_.PNPClass; errorCode = $_.ConfigManagerErrorCode; present = $_.Present }
    })
})

# ---------------------------------------------------------------- security
$snap.security = Invoke-Safe 'security' {
    $mp = Invoke-Safe 'defender' { Get-MpComputerStatus }
    $av = @(Invoke-Safe 'securitycenter' {
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object {
            $state = [int]$_.productState
            [ordered]@{
                name     = $_.displayName
                enabled  = ((($state -shr 12) -band 0xF) -eq 1)
                upToDate = ((($state -shr 4) -band 0xF) -eq 0)
            }
        }
    })
    $fw = @(Invoke-Safe 'firewall' {
        Get-NetFirewallProfile | ForEach-Object { [ordered]@{ profile = $_.Name; enabled = [bool]$_.Enabled } }
    })
    $wu = Invoke-Safe 'windowsupdate' {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $total = $searcher.GetTotalHistoryCount()
        $hist = @()
        if ($total -gt 0) { $hist = @($searcher.QueryHistory(0, [math]::Min(15, $total))) }
        $ok = @($hist | Where-Object { $_.ResultCode -eq 2 -and $_.Operation -eq 1 })
        $failed = @($hist | Where-Object { $_.ResultCode -in 4, 5 })
        [ordered]@{
            lastSuccess = if ($ok.Count) { ConvertTo-Iso (($ok | Sort-Object Date -Descending)[0].Date) } else { $null }
            recentFailures = @($failed | Select-Object -First 5 | ForEach-Object {
                [ordered]@{ date = ConvertTo-Iso $_.Date; title = $_.Title; hresult = ('0x{0:X8}' -f $_.HResult) }
            })
        }
    }
    $rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                     (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    [ordered]@{
        defender = if ($mp) {
            [ordered]@{
                mode               = [string]$mp.AMRunningMode
                antivirusEnabled   = $mp.AntivirusEnabled
                realTime           = $mp.RealTimeProtectionEnabled
                signatureAgeDays   = $mp.AntivirusSignatureAge
                quickScanAgeDays   = $mp.QuickScanAge
                tamperProtection   = $mp.IsTamperProtected
            }
        } else { $null }
        antivirusProducts = $av
        firewall          = $fw
        windowsUpdate     = $wu
        rebootPending     = $rebootPending
        uacEnabled        = [bool](Invoke-Safe 'uac' { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA })
        secureBoot        = $(if ($sb = Invoke-Safe 'secureboot' { Confirm-SecureBootUEFI }) { $sb } else { $null })
    }
}

# ---------------------------------------------------------------- maintenance
$snap.maintenance = Invoke-Safe 'maintenance' {
    # The same entry often appears under several hives (SYSTEM, .DEFAULT, user): keep one per name+command.
    $startup = @(Get-CimInstance Win32_StartupCommand | Group-Object { '{0}|{1}' -f $_.Name, $_.Command } | ForEach-Object {
        $first = $_.Group[0]
        [ordered]@{ name = $first.Name; command = $first.Command; location = $first.Location; hives = $_.Count }
    })
    [ordered]@{
        startupCount  = $startup.Count
        startup       = $startup
        userTempGB    = Get-FolderSizeGB $env:TEMP
        windowsTempGB = Get-FolderSizeGB "$env:SystemRoot\Temp"
        downloadsGB   = Get-FolderSizeGB (Join-Path $env:USERPROFILE 'Downloads')
    }
}

$snap.network = @(Invoke-Safe 'network' {
    @(Get-NetAdapter -Physical | ForEach-Object {
        [ordered]@{ name = $_.Name; description = $_.InterfaceDescription; status = [string]$_.Status; linkSpeed = $_.LinkSpeed; driverDate = ConvertTo-Iso $_.DriverDate }
    })
})

$snap.battery = Invoke-Safe 'battery' {
    $b = Get-CimInstance Win32_Battery | Select-Object -First 1
    if ($b) {
        $full = Invoke-Safe 'battery-full' { (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object -First 1).FullChargedCapacity }
        $design = Invoke-Safe 'battery-design' { (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData | Select-Object -First 1).DesignedCapacity }
        [ordered]@{
            chargePct = $b.EstimatedChargeRemaining
            status    = $b.BatteryStatus
            healthPct = if ($full -and $design) { [math]::Round($full / $design * 100) } else { $null }
        }
    }
}

# ---------------------------------------------------------------- optional slow checks
if ($Full) {
    $snap.extra = [ordered]@{}
    $snap.extra.wingetUpgrades = Invoke-Safe 'winget' {
        $w = Get-Command winget -ErrorAction Stop
        $out = & $w.Source upgrade --include-unknown --accept-source-agreements 2>$null | Out-String
        $lines = @($out -split "`r?`n" | Where-Object { $_ -match '\S+\s+\S+\s+\d[\w\.\-]*\s+\d[\w\.\-]*\s+\S+\s*$' -and $_ -notmatch '^-+' })
        [ordered]@{ count = $lines.Count; lines = @($lines | Select-Object -First 40 | ForEach-Object { ($_ -replace '\s{2,}', ' | ').Trim() }) }
    }
    $snap.extra.drivers = Invoke-Safe 'drivers' {
        @(Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceClass -in 'DISPLAY', 'NET', 'SYSTEM', 'MEDIA', 'HDC', 'SCSIADAPTER', 'USB' -and $_.DriverProviderName -and $_.DriverProviderName -ne 'Microsoft' } |
            Sort-Object DeviceName -Unique | ForEach-Object {
                [ordered]@{ device = $_.DeviceName; class = $_.DeviceClass; provider = $_.DriverProviderName; version = $_.DriverVersion; date = ConvertTo-Iso $_.DriverDate }
            })
    }
}

$snap.meta.durationSec = [math]::Round(((Get-Date) - $now).TotalSeconds, 1)
# Access-denied items are expected without admin: report them separately from real failures.
$denied = @($script:collectErrors | Where-Object { $_ -match 'denied|refus|not available|pas disponible|privil' })
$snap.meta.needsAdmin = @($denied | ForEach-Object { ($_ -split ':')[0] } | Select-Object -Unique)
$snap.meta.collectErrors = @($script:collectErrors | Where-Object { $denied -notcontains $_ })

# ---------------------------------------------------------------- output
$json = $snap | ConvertTo-Json -Depth 8
$publicJson = $json
if ($Anonymize) {
    $pairs = @(
        @{ find = $env:USERPROFILE; repl = 'C:\\Users\\<user>' },
        @{ find = $env:USERNAME; repl = '<user>' },
        @{ find = $env:COMPUTERNAME; repl = '<pc>' }
    )
    foreach ($p in $pairs) {
        if ($p.find) {
            $escapedJson = $p.find -replace '\\', '\\'
            $publicJson = [regex]::Replace($publicJson, [regex]::Escape($escapedJson), $p.repl, 'IgnoreCase')
            $publicJson = [regex]::Replace($publicJson, [regex]::Escape($p.find), $p.repl, 'IgnoreCase')
        }
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$written = @()
if (-not $NoSave) {
    $histDir = Join-Path $env:LOCALAPPDATA 'DesktopDiag\history'
    if (-not (Test-Path -LiteralPath $histDir)) { $null = New-Item -ItemType Directory -Path $histDir -Force }
    $histFile = Join-Path $histDir ('{0}.json' -f $now.ToString('yyyyMMdd-HHmmss'))
    [IO.File]::WriteAllText($histFile, $json, $utf8)
    $written += $histFile
}
if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    [IO.File]::WriteAllText($OutFile, $publicJson, $utf8)
    $written += (Resolve-Path -LiteralPath $OutFile).Path
}

if ($Stdout -or $written.Count -eq 0) {
    $publicJson
} else {
    'DesktopDiag {0} - snapshot written ({1}s, {2} collect errors, {3} items need admin):' -f $DDVersion, $snap.meta.durationSec, $snap.meta.collectErrors.Count, $snap.meta.needsAdmin.Count
    $written | ForEach-Object { '  ' + $_ }
}
