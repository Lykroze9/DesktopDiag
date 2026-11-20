# Builds app\bin\DesktopDiag.exe with the .NET Framework 4.8 compiler already on Windows (no SDK).
# Embeds the WebView2 DLLs (app\lib, see README), the UI (app\ui) and the skill's scripts and rules
# (single source: skills\desktopdiag). Writes DesktopDiag.exe.sha256 next to the exe.
param([switch]$Run, [string]$Version, [string]$OutDir)
$ErrorActionPreference = 'Stop'
$app  = $PSScriptRoot
if (-not $Version) { $Version = (Get-Content (Join-Path $app 'version.txt') -TotalCount 1).Trim() }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Bad version '$Version' (expected X.Y.Z)" }
$repo = Split-Path -Parent $app
$skill = Join-Path $repo 'skills\desktopdiag'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$lib = Join-Path $app 'lib'
$out = Join-Path $app 'bin'

$dlls = 'Microsoft.Web.WebView2.Core.dll', 'Microsoft.Web.WebView2.WinForms.dll', 'WebView2Loader.dll'
foreach ($d in $dlls) { if (-not (Test-Path (Join-Path $lib $d))) { throw "Missing app\lib\$d (WebView2 SDK, see app\README.md)" } }

$res = @()
foreach ($d in $dlls) { $res += '/resource:{0},bin/{1}' -f (Join-Path $lib $d), $d }
Get-ChildItem (Join-Path $app 'ui') -File | ForEach-Object { $res += '/resource:{0},ui/{1}' -f $_.FullName, $_.Name }
foreach ($s in 'collect.ps1', 'collect-admin.ps1', 'compare.ps1', 'score.ps1', 'summarize.ps1') {
    $res += '/resource:{0},scripts/{1}' -f (Join-Path $skill "scripts\$s"), $s
}
$res += '/resource:{0},rules/rules.json' -f (Join-Path $skill 'rules\rules.json')

if ($OutDir) { $out = $OutDir }
New-Item -ItemType Directory -Force $out | Out-Null
$exe = Join-Path $out 'DesktopDiag.exe'
$gen = Join-Path $env:TEMP ('DesktopDiag-Version-{0}.g.cs' -f $PID)
[IO.File]::WriteAllText($gen, "namespace DesktopDiag { static class AppVersion { public const string Value = `"$Version`"; } }`r`n")
$cscArgs = @('/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/codepage:65001',
    "/out:$exe", ('/win32manifest:' + (Join-Path $app 'app.manifest')),
    '/r:System.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll', '/r:System.Web.Extensions.dll',
    ('/r:' + (Join-Path $lib 'Microsoft.Web.WebView2.Core.dll')), ('/r:' + (Join-Path $lib 'Microsoft.Web.WebView2.WinForms.dll'))) +
    $res + (Get-ChildItem (Join-Path $app 'src') -Filter *.cs | ForEach-Object { $_.FullName }) + $gen
& $csc @cscArgs
$code = $LASTEXITCODE
Remove-Item $gen -ErrorAction SilentlyContinue
if ($code) { throw "csc failed ($code)" }

$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$exe.sha256", "$hash  DesktopDiag.exe`n", (New-Object Text.UTF8Encoding($false)))
'{0}  {1:N0} KB  sha256 {2}' -f $exe, ((Get-Item $exe).Length / 1KB), $hash
if ($Run) { Start-Process $exe }
