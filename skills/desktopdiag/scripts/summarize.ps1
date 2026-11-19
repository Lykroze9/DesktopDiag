<#
.SYNOPSIS
    DesktopDiag - print a compact JSON digest of a collect.ps1 snapshot.

.DESCRIPTION
    Key figures, event groups with count/first/last (no timestamp lists), no long lists.
    About 10x smaller than the full snapshot. collect.ps1 -Summary calls this script.
    Without -Path, uses the newest non-admin snapshot in %LOCALAPPDATA%\DesktopDiag\history.

.PARAMETER Path
    Snapshot to summarize.
.PARAMETER Anonymize
    Replace user name, computer name and profile path in the output.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Anonymize
)

$ErrorActionPreference = 'Stop'
# Invariant culture so numbers in digest strings use a dot (106.4, not 106,4).
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture

if (-not $Path) {
    $histDir = Join-Path $env:LOCALAPPDATA 'DesktopDiag\history'
    $Path = (Get-ChildItem -LiteralPath $histDir -Filter '*.json' | Where-Object { $_.Name -notmatch '-admin\.json$' } |
        Sort-Object Name -Descending | Select-Object -First 1).FullName
}
$s = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json

function Get-GroupDigest {
    param($Groups, [int]$Max = 10)
    @($Groups | Where-Object { $_ } | Select-Object -First $Max | ForEach-Object {
        [ordered]@{ key = $_.key; count = $_.count; first = $_.first; last = $_.last }
    })
}

function Get-OrNull {
    param($Object, [string]$Name)
    if ($null -ne $Object) { $Object.$Name } else { $null }
}

$sec = $s.security
$m = $s.maintenance
$nh = $s.networkHealth

$digest = [ordered]@{
    fullSnapshot = $Path
    meta         = [ordered]@{ version = $s.meta.version; timestamp = $s.meta.timestamp; utcOffset = $s.meta.utcOffset; uiCulture = $s.meta.uiCulture; windowDays = $s.meta.windowDays; crashDays = $s.meta.crashDays; needsAdmin = @($s.meta.needsAdmin); collectErrors = @($s.meta.collectErrors) }
    system       = $s.system
    hardware     = if ($s.hardware) { [ordered]@{
        model = ('{0} {1}' -f $s.hardware.manufacturer, $s.hardware.model).Trim(); board = $s.hardware.board
        bios = ('{0} ({1})' -f $s.hardware.biosVersion, $s.hardware.biosDate); cpu = $s.hardware.cpu; ramGB = $s.hardware.ramTotalGB
        ramModules = @($s.hardware.ramModules).Count; ramRunningMHz = @($s.hardware.ramModules | ForEach-Object { $_.runningMHz } | Select-Object -Unique)
        gpus = @($s.hardware.gpus | ForEach-Object { [ordered]@{ name = $_.name; driver = $(if ($_.nvidiaVersion) { $_.nvidiaVersion } else { $_.driverVersion }); driverDate = $_.driverDate; status = $_.status } })
        isLaptop = $s.hardware.isLaptop } } else { $null }
    load         = if ($s.load) { [ordered]@{ cpuPct = $s.load.cpuPct; ramUsedPct = $s.load.ramUsedPct; commitUsedPct = $s.load.commitUsedPct
        topCpu = @($s.load.topCpu | Select-Object -First 3 | ForEach-Object { '{0} {1}%' -f $_.name, $_.cpuPct })
        topMemory = @($s.load.topMemory | Select-Object -First 3 | ForEach-Object { '{0} {1}MB' -f $_.name, $_.memMB }) } } else { $null }
    boot         = if ($s.boot) { [ordered]@{ lastFirmwareSec = $s.boot.lastFirmwareSec; avgFirmwareSec = $s.boot.avgFirmwareSec; fastStartupEnabled = $s.boot.fastStartupEnabled
        bootTypes = @($s.boot.recentBoots | Group-Object { $_.bootType } | ForEach-Object { '{0} x{1}' -f $_.Name, $_.Count }) } } else { $null }
    thermal      = if ($s.thermal) { [ordered]@{ cpuThrottleEvents = @(Get-GroupDigest $s.thermal.cpuThrottleEvents); cpuPerfLimitPct = $s.thermal.cpuPerfLimitPct; cpuPctOfMaxFreq = $s.thermal.cpuPctOfMaxFreq; thermalZones = @($s.thermal.thermalZones) } } else { $null }
    storage      = if ($s.storage) { [ordered]@{
        volumes = @($s.storage.volumes | ForEach-Object { '{0} {1} {2}/{3}GB free ({4}%)' -f $_.drive, $_.type, $_.freeGB, $_.sizeGB, $_.freePct })
        disks = @($s.storage.physicalDisks | ForEach-Object { $r = $_.reliability; [ordered]@{ number = $_.number; name = $_.name; bus = $_.bus; media = $_.media; health = $_.health
            tempC = (Get-OrNull $r 'temperatureC'); wearPct = (Get-OrNull $r 'wearPct'); readUncorrected = (Get-OrNull $r 'readUncorrected') } }) } } else { $null }
    stability    = if ($s.stability) { [ordered]@{
        unexpectedShutdowns = @($s.stability.unexpectedShutdowns).Count
        lastShutdowns = @($s.stability.unexpectedShutdowns | Select-Object -First 5 | ForEach-Object { '{0} {1}' -f $_.time, $_.bugcheckCode })
        bugchecks = @($s.stability.bugchecks | Select-Object -First 5 | ForEach-Object { '{0} {1}' -f $_.time, $_.bugcheck })
        dirtyShutdowns = $s.stability.dirtyShutdownCount; boots = $s.stability.bootCount
        reliabilityIndex = $s.stability.reliabilityIndex; minidumps = @($s.stability.minidumps).Count; minidumpsReadable = $s.stability.minidumpsReadable } } else { $null }
    gpuEvents         = @(Get-GroupDigest $s.gpuEvents)
    diskEvents        = @(Get-GroupDigest $s.diskEvents)
    hardwareErrors    = @(Get-GroupDigest $s.hardwareErrors)
    memoryDiagnostics = if ($s.memoryDiagnostics -and $s.memoryDiagnostics.lastRun) { [ordered]@{ lastRun = $s.memoryDiagnostics.lastRun; result = $s.memoryDiagnostics.result } } else { 'never run' }
    tpmEvents         = @(Get-GroupDigest $s.tpmEvents 5)
    serviceFailures   = @(Get-GroupDigest $s.serviceFailures 8)
    topSystemErrors   = @(Get-GroupDigest $s.topSystemErrors 8)
    appCrashes        = if ($s.appCrashes) { [ordered]@{ crashes = @($s.appCrashes.crashes | Select-Object -First 5 | ForEach-Object { '{0} x{1} (last {2})' -f $_.key, $_.count, $_.last }); hangs = @($s.appCrashes.hangs | Select-Object -First 5 | ForEach-Object { '{0} x{1}' -f $_.key, $_.count }) } } else { $null }
    problemDevices    = @($s.problemDevices | Where-Object { $_ } | ForEach-Object { '{0} (code {1}, present {2})' -f $_.name, $_.errorCode, $_.present })
    security          = if ($sec) { [ordered]@{
        defender = $sec.defender; antivirus = @($sec.antivirusProducts | ForEach-Object { '{0} enabled={1} upToDate={2}' -f $_.name, $_.enabled, $_.upToDate })
        firewallOff = @($sec.firewall | Where-Object { -not $_.enabled } | ForEach-Object { $_.profile })
        wuLastSuccess = (Get-OrNull $sec.windowsUpdate 'lastSuccess'); wuRecentFailures = @((Get-OrNull $sec.windowsUpdate 'recentFailures')).Count
        rebootPending = $sec.rebootPending; uac = $sec.uacEnabled; secureBoot = $sec.secureBoot } } else { $null }
    maintenance       = if ($m) { [ordered]@{ startupCount = $m.startupCount; startup = @($m.startup | ForEach-Object { $_.name }); userTempGB = $m.userTempGB; windowsTempGB = $m.windowsTempGB; downloadsGB = $m.downloadsGB
        pagefile = if ($m.pagefile) { '{0}; {1}' -f $(if ($m.pagefile.automatic) { 'automatic' } else { 'manual' }), ((@($m.pagefile.files) | ForEach-Object { '{0} {1}GB (peak {2}GB)' -f $_.path, $_.allocatedGB, $_.peakUsageGB }) -join ', ') } else { $null }
        hibernation = if ($m.hibernation) { 'enabled={0} hiberfil={1}GB' -f $m.hibernation.enabled, $m.hibernation.hiberfilGB } else { $null } } } else { $null }
    network           = @($s.network | ForEach-Object { '{0}: {1} {2}' -f $_.name, $_.status, $_.linkSpeed })
    networkHealth     = if ($nh) { [ordered]@{ wifi = $nh.wifi; gatewayPingMs = $nh.gatewayPingMs; dnsMs = $nh.dnsMs; dnsOk = $nh.dnsOk; disconnects = @(Get-GroupDigest $nh.disconnects 5) } } else { $null }
    battery           = $s.battery
}
if ($s.extra) { $digest.extra = [ordered]@{ wingetUpgrades = (Get-OrNull $s.extra.wingetUpgrades 'count'); drivers = @($s.extra.drivers).Count } }

$out = $digest | ConvertTo-Json -Depth 6 -Compress
if ($Anonymize) {
    foreach ($f in @($env:USERPROFILE, $env:USERNAME, $env:COMPUTERNAME)) {
        if ($f) { $out = [regex]::Replace($out, [regex]::Escape(($f -replace '\\', '\\')), '<redacted>', 'IgnoreCase') }
    }
}
$out
