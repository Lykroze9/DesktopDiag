<#
.SYNOPSIS
    DesktopDiag - compare two collect.ps1 snapshots and print what changed (JSON).

.DESCRIPTION
    Without parameters, compares the two most recent snapshots in
    %LOCALAPPDATA%\DesktopDiag\history (admin snapshots are ignored).
    "New since previous" counts only events dated after the previous snapshot.

.PARAMETER Current
    Path of the newer snapshot.
.PARAMETER Previous
    Path of the older snapshot.
#>
[CmdletBinding()]
param(
    [string]$Current,
    [string]$Previous
)

$ErrorActionPreference = 'Stop'

function Read-Snapshot {
    param([string]$Path)
    [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json
}

if (-not $Current -or -not $Previous) {
    $histDir = Join-Path $env:LOCALAPPDATA 'DesktopDiag\history'
    $files = @(Get-ChildItem -LiteralPath $histDir -Filter '*.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '-admin\.json$' } | Sort-Object Name -Descending)
    if ($files.Count -lt 2) {
        [ordered]@{ comparable = $false; reason = 'Less than two snapshots in history.'; historyDir = $histDir } | ConvertTo-Json
        return
    }
    if (-not $Current) { $Current = $files[0].FullName }
    if (-not $Previous) { $Previous = $files[1].FullName }
}

$cur = Read-Snapshot $Current
$prev = Read-Snapshot $Previous
$since = [datetime]$prev.meta.timestamp

function Get-NewCount {
    param($Times)
    @($Times | Where-Object { $_ -and ([datetime]$_) -gt $since }).Count
}

function Compare-Groups {
    param($CurGroups)
    @($CurGroups | ForEach-Object {
        $n = Get-NewCount $_.times
        if ($n -gt 0) { [ordered]@{ key = $_.key; newSincePrevious = $n; last = $_.last } }
    })
}

$out = [ordered]@{
    comparable = $true
    previous   = [ordered]@{ file = $Previous; timestamp = $prev.meta.timestamp }
    current    = [ordered]@{ file = $Current; timestamp = $cur.meta.timestamp }
    daysBetween = [math]::Round(([datetime]$cur.meta.timestamp - $since).TotalDays, 1)
}

# Volumes
$out.volumes = @($cur.storage.volumes | ForEach-Object {
    $c = $_
    $p = $prev.storage.volumes | Where-Object { $_.drive -eq $c.drive } | Select-Object -First 1
    [ordered]@{
        drive        = $c.drive
        freeGB       = $c.freeGB
        freePct      = $c.freePct
        deltaFreeGB  = if ($p) { [math]::Round($c.freeGB - $p.freeGB, 1) } else { $null }
        isNew        = (-not $p)
    }
})

# Stability
$out.stability = [ordered]@{
    newUnexpectedShutdowns = Get-NewCount @($cur.stability.unexpectedShutdowns | ForEach-Object { $_.time })
    newBugchecks           = @($cur.stability.bugchecks | Where-Object { ([datetime]$_.time) -gt $since })
    reliabilityIndex       = [ordered]@{
        previous = $prev.stability.reliabilityIndex.index
        current  = $cur.stability.reliabilityIndex.index
    }
}
$out.newGpuEvents      = @(Compare-Groups $cur.gpuEvents)
$out.newDiskEvents     = @(Compare-Groups $cur.diskEvents)
$out.newHardwareErrors = @(Compare-Groups $cur.hardwareErrors)
$out.newTpmEvents      = @(Compare-Groups $cur.tpmEvents)

# Disks (reliability counters, only if both have them)
$out.disks = @($cur.storage.physicalDisks | ForEach-Object {
    $c = $_
    $p = $prev.storage.physicalDisks | Where-Object { $_.name -eq $c.name } | Select-Object -First 1
    [ordered]@{
        name          = $c.name
        health        = $c.health
        healthChanged = ($p -and $p.health -ne $c.health)
        wearPct       = $c.reliability.wearPct
        deltaWearPct  = if ($p -and $null -ne $c.reliability.wearPct -and $null -ne $p.reliability.wearPct) { $c.reliability.wearPct - $p.reliability.wearPct } else { $null }
    }
})

# Versions
$changes = @()
if ($prev.system.build -ne $cur.system.build) { $changes += ('Windows build {0} -> {1}' -f $prev.system.build, $cur.system.build) }
if ($prev.hardware.biosVersion -ne $cur.hardware.biosVersion) { $changes += ('BIOS {0} -> {1}' -f $prev.hardware.biosVersion, $cur.hardware.biosVersion) }
foreach ($g in $cur.hardware.gpus) {
    $pg = $prev.hardware.gpus | Where-Object { $_.name -eq $g.name } | Select-Object -First 1
    if ($pg -and $pg.driverVersion -ne $g.driverVersion) {
        $changes += ('GPU driver {0}: {1} -> {2}' -f $g.name, $pg.driverVersion, $g.driverVersion)
    }
}
$out.versionChanges = $changes

# Startup entries
$curNames = @($cur.maintenance.startup | ForEach-Object { $_.name })
$prevNames = @($prev.maintenance.startup | ForEach-Object { $_.name })
$out.startup = [ordered]@{
    count   = $cur.maintenance.startupCount
    added   = @($curNames | Where-Object { $prevNames -notcontains $_ })
    removed = @($prevNames | Where-Object { $curNames -notcontains $_ })
}

# Devices
$prevDev = @($prev.problemDevices | Where-Object { $_ } | ForEach-Object { $_.name })
$out.newProblemDevices = @($cur.problemDevices | Where-Object { $_ -and $prevDev -notcontains $_.name })
$curDev = @($cur.problemDevices | Where-Object { $_ } | ForEach-Object { $_.name })
$out.resolvedProblemDevices = @($prevDev | Where-Object { $curDev -notcontains $_ })

# Security
$out.security = [ordered]@{
    rebootPending     = $cur.security.rebootPending
    defenderRealTime  = $cur.security.defender.realTime
    lastUpdateSuccess = $cur.security.windowsUpdate.lastSuccess
}

$out | ConvertTo-Json -Depth 6
