<#
.SYNOPSIS
    DesktopDiag - optional deep checks that need administrator rights. Read-only.

.DESCRIPTION
    - Storage reliability counters (wear, temperature, errors) for every physical disk
    - SMART via smartctl (smartmontools) when it is installed
    - Read-only file system scan (Repair-Volume -Scan) of fixed NTFS volumes
    - Optional: crash dump analysis with cdb (WinDbg) when installed (-Dumps)
    - Optional: system file integrity check (sfc /verifyonly) (-Sfc, takes several minutes)

    Nothing is repaired or deleted. Crash dumps are copied to a temp folder before analysis.
    cdb downloads public symbols from Microsoft's symbol server (msdl.microsoft.com) on first use.

    Launch elevated from a non-admin shell (writes the JSON, then read it):
      Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<path>\collect-admin.ps1','-OutFile','<out.json>'

.PARAMETER OutFile
    JSON output path. Default: %LOCALAPPDATA%\DesktopDiag\history\<timestamp>-admin.json
.PARAMETER Dumps
    Analyse the most recent minidumps with cdb (if installed).
.PARAMETER MaxDumps
    How many recent minidumps to analyse. Default 3.
.PARAMETER Sfc
    Run sfc /verifyonly (read-only integrity check, slow).
#>
[CmdletBinding()]
param(
    [string]$OutFile,
    [switch]$Dumps,
    [int]$MaxDumps = 3,
    [switch]$Sfc
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$DDVersion = '0.2.0'
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

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$snap = [ordered]@{}
$snap.meta = [ordered]@{
    tool      = 'DesktopDiag'
    version   = $DDVersion
    kind      = 'admin'
    timestamp = $now.ToString('s')
    isAdmin   = $isAdmin
}

if (-not $isAdmin) {
    $snap.meta.error = 'Not elevated: run this script as administrator.'
} else {

    # ------------------------------------------------------------ reliability counters
    $snap.reliability = Invoke-Safe 'reliability' {
        @(Get-PhysicalDisk | ForEach-Object {
            $pd = $_
            $r = $pd | Get-StorageReliabilityCounter
            [ordered]@{
                number          = $pd.DeviceId
                name            = $pd.FriendlyName
                bus             = [string]$pd.BusType
                temperatureC    = $r.Temperature
                temperatureMaxC = $r.TemperatureMax
                wearPct         = $r.Wear
                powerOnHours    = $r.PowerOnHours
                startStopCycles = $r.StartStopCycleCount
                readErrors      = $r.ReadErrorsTotal
                readUncorrected = $r.ReadErrorsUncorrected
                writeErrors     = $r.WriteErrorsTotal
                writeUncorrected= $r.WriteErrorsUncorrected
                latencyMaxReadMs  = $r.ReadLatencyMax
                latencyMaxWriteMs = $r.WriteLatencyMax
            }
        })
    }

    # ------------------------------------------------------------ SMART (smartctl)
    $smartctl = $null
    foreach ($c in @("$env:ProgramFiles\smartmontools\bin\smartctl.exe", "${env:ProgramFiles(x86)}\smartmontools\bin\smartctl.exe")) {
        if ($c -and (Test-Path -LiteralPath $c)) { $smartctl = $c; break }
    }
    if (-not $smartctl) {
        $cmd = Get-Command smartctl -ErrorAction SilentlyContinue
        if ($cmd) { $smartctl = $cmd.Source }
    }
    $snap.smart = Invoke-Safe 'smart' {
        if (-not $smartctl) { return [ordered]@{ available = $false; hint = 'winget install smartmontools.smartmontools' } }
        $scan = (& $smartctl --scan-open -j 2>$null | Out-String) | ConvertFrom-Json
        $devs = @($scan.devices | ForEach-Object {
            $d = $_
            $raw = (& $smartctl -a -j $d.name 2>$null | Out-String) | ConvertFrom-Json
            $nv = $raw.nvme_smart_health_information_log
            $ata = $null
            if ($raw.ata_smart_attributes) {
                $want = 5, 9, 187, 188, 194, 196, 197, 198, 199, 231, 233, 241
                $ata = @($raw.ata_smart_attributes.table | Where-Object { $want -contains $_.id } | ForEach-Object {
                    [ordered]@{ id = $_.id; name = $_.name; value = $_.value; worst = $_.worst; thresh = $_.thresh; raw = $_.raw.value }
                })
            }
            [ordered]@{
                device      = $d.name
                type        = $d.type
                model       = $raw.model_name
                serialHash  = if ($raw.serial_number) { ([BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($raw.serial_number)))).Replace('-', '').Substring(0, 12) } else { $null }
                firmware    = $raw.firmware_version
                smartPassed = $raw.smart_status.passed
                temperatureC = $raw.temperature.current
                powerOnHours = $raw.power_on_time.hours
                nvme = if ($nv) {
                    [ordered]@{
                        criticalWarning     = $nv.critical_warning
                        percentageUsed      = $nv.percentage_used
                        availableSparePct   = $nv.available_spare
                        spareThresholdPct   = $nv.available_spare_threshold
                        mediaErrors         = $nv.media_errors
                        errorLogEntries     = $nv.num_err_log_entries
                        unsafeShutdowns     = $nv.unsafe_shutdowns
                        dataWrittenTB       = [math]::Round(([double]$nv.data_units_written) * 512000 / 1e12, 1)
                        warningTempMinutes  = $nv.warning_temp_time
                        criticalTempMinutes = $nv.critical_comp_time
                        temperatureSensors  = $nv.temperature_sensors
                    }
                } else { $null }
                ata = $ata
                messages = @($raw.smartctl.messages | Where-Object { $_ -and $_.string } | ForEach-Object { $_.string })
            }
        })
        [ordered]@{ available = $true; path = $smartctl; devices = $devs }
    }

    # ------------------------------------------------------------ file system scan (read-only)
    $snap.volumeScan = Invoke-Safe 'volumeScan' {
        @(Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem -eq 'NTFS' -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
            $v = $_
            $res = Invoke-Safe ('repairvolume-' + $v.DriveLetter) { Repair-Volume -DriveLetter $v.DriveLetter -Scan }
            [ordered]@{ drive = ('{0}:' -f $v.DriveLetter); result = [string]$res }
        })
    }

    # ------------------------------------------------------------ crash dumps (cdb)
    if ($Dumps) {
        $snap.dumpAnalysis = Invoke-Safe 'dumps' {
            $cdb = $null
            $candidates = @(
                "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe",
                "$env:ProgramFiles\Windows Kits\10\Debuggers\x64\cdb.exe"
            )
            $candidates += @(Get-ChildItem "$env:ProgramFiles\WindowsApps" -Directory -Filter 'Microsoft.WinDbg_*' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'amd64\cdb.exe' })
            foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { $cdb = $c; break } }
            if (-not $cdb) { return [ordered]@{ available = $false; hint = 'winget install Microsoft.WinDbg' } }

            $work = Join-Path $env:TEMP 'DesktopDiag-dumps'
            $null = New-Item -ItemType Directory -Path $work -Force
            $symCache = Join-Path $env:TEMP 'DesktopDiag-symbols'
            $results = @(Get-ChildItem -LiteralPath "$env:SystemRoot\Minidump" -Filter *.dmp | Sort-Object LastWriteTime -Descending | Select-Object -First $MaxDumps | ForEach-Object {
                $copy = Join-Path $work $_.Name
                Copy-Item -LiteralPath $_.FullName -Destination $copy -Force
                $log = Join-Path $work ($_.BaseName + '.txt')
                $p = Start-Process -FilePath $cdb -ArgumentList @('-z', "`"$copy`"", '-y', "`"srv*$symCache*https://msdl.microsoft.com/download/symbols`"", '-c', '"!analyze -v; q"', '-logo', "`"$log`"") -NoNewWindow -PassThru
                if (-not $p.WaitForExit(240000)) { try { $p.Kill() } catch {} }
                $text = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }
                $pick = {
                    param($pattern)
                    $m = [regex]::Match($text, $pattern, 'Multiline')
                    if ($m.Success) { $m.Groups[1].Value.Trim() } else { $null }
                }
                $code = & $pick '^BUGCHECK_CODE:\s*(\S+)'
                if ($code) { try { $code = '0x{0:X}' -f [Convert]::ToInt64($code, 16) } catch {} }
                $module = & $pick '^MODULE_NAME:\s*(\S+)'
                if ($module) { $module = $module -replace '_[0-9a-fA-F]{8,16}$', '' }
                [ordered]@{
                    file          = $_.Name
                    date          = ConvertTo-Iso $_.LastWriteTime
                    bugcheckCode  = $code
                    # Header line of !analyze -v, e.g. "SYSTEM_SERVICE_EXCEPTION (3b)"
                    bugcheckName  = & $pick '^([A-Z][A-Z0-9_]{5,})\s+\([0-9a-fA-F]+\)\s*$'
                    moduleName    = $module
                    imageName     = & $pick '^IMAGE_NAME:\s*(\S+)'
                    processName   = & $pick '^PROCESS_NAME:\s*(\S+)'
                    failureBucket = & $pick '^FAILURE_BUCKET_ID:\s*(\S+)'
                    timedOut      = -not $p.HasExited
                }
            })
            [ordered]@{ available = $true; results = $results }
        }
    }

    # ------------------------------------------------------------ boot performance
    # Diagnostics-Performance/Operational is admin-only. Event 100 = one boot, times in ms.
    # Events 101-110 = something slowed a boot down (app, driver, service...).
    $snap.bootPerformance = Invoke-Safe 'bootperf' {
        $log = 'Microsoft-Windows-Diagnostics-Performance/Operational'
        $boots = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Id = 100 } -MaxEvents 15 -ErrorAction SilentlyContinue | ForEach-Object {
            $d = @{}
            ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }
            [ordered]@{
                time        = ConvertTo-Iso $_.TimeCreated
                bootSec     = [math]::Round([double]$d.BootTime / 1000, 1)
                mainPathSec = [math]::Round([double]$d.MainPathBootTime / 1000, 1)
                postBootSec = [math]::Round([double]$d.BootPostBootTime / 1000, 1)
                degraded    = ($d.IsDegradation -eq 'true')
            }
        })
        $slow = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Id = 101..110; StartTime = $now.AddDays(-60) } -ErrorAction SilentlyContinue | ForEach-Object {
            $d = @{}
            ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }
            $name = @($d.FriendlyName, $d.Name, $d.FileName) | Where-Object { $_ } | Select-Object -First 1
            [pscustomobject]@{ key = ('{0} {1}' -f $_.Id, $name).Trim(); time = $_.TimeCreated; ms = [double]$d.DegradationTime }
        } | Group-Object key | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
            [ordered]@{
                key      = $_.Name
                count    = $_.Count
                last     = ConvertTo-Iso (($_.Group | Sort-Object time -Descending)[0].time)
                avgDelaySec = [math]::Round((($_.Group | Measure-Object ms -Average).Average) / 1000, 1)
            }
        })
        $times = @($boots | ForEach-Object { $_.bootSec })
        [ordered]@{
            lastBootSec  = if ($times.Count) { $times[0] } else { $null }
            avgBootSec   = if ($times.Count) { [math]::Round(($times | Measure-Object -Average).Average, 1) } else { $null }
            recentBoots  = $boots
            slowdowns    = $slow
        }
    }

    # ------------------------------------------------------------ sfc /verifyonly
    if ($Sfc) {
        $snap.sfc = Invoke-Safe 'sfc' {
            $out = Join-Path $env:TEMP 'DesktopDiag-sfc.txt'
            $p = Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" -ArgumentList '/verifyonly' -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
            # sfc writes UTF-16 with interleaved NULs; normalise.
            $txt = ''
            if (Test-Path -LiteralPath $out) { $txt = ([IO.File]::ReadAllText($out) -replace "`0", '') }
            $lines = @($txt -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 4)
            [ordered]@{ exitCode = $p.ExitCode; lastLines = $lines }
        }
    }
}

$snap.meta.durationSec = [math]::Round(((Get-Date) - $now).TotalSeconds, 1)
$snap.meta.collectErrors = @($script:collectErrors)

if (-not $OutFile) {
    $histDir = Join-Path $env:LOCALAPPDATA 'DesktopDiag\history'
    if (-not (Test-Path -LiteralPath $histDir)) { $null = New-Item -ItemType Directory -Path $histDir -Force }
    $OutFile = Join-Path $histDir ('{0}-admin.json' -f $now.ToString('yyyyMMdd-HHmmss'))
}
$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
[IO.File]::WriteAllText($OutFile, ($snap | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
'DesktopDiag admin {0} - written: {1}' -f $DDVersion, $OutFile
