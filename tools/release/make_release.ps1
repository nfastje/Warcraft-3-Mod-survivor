# Packs the engine build and survivor scripts into a self-extracting exe.
# Use -IncludeWarcraftData to make a private portable package from a local 1.29 install.
param(
    [switch]$IncludeWarcraftData,
    [string]$WarcraftDataDir = 'C:\Program Files (x86)\Warcraft III (Legacy)'
)

$ErrorActionPreference = 'Stop'
$root  = Split-Path (Split-Path $PSScriptRoot)
$dist  = Join-Path $root 'engine\dist\windows'
# release\ holds only the site's upload copy (make_upload.ps1): builds go here.
$out   = Join-Path $root 'engine\build\portable'
$stage = Join-Path $out 'stage\Warcraft Survivors'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$sfx = if ($IncludeWarcraftData) {
    Join-Path $PSScriptRoot '7zSD.sfx'
} else {
    'C:\Program Files\7-Zip\7z.sfx'
}

if (Test-Path (Join-Path $out 'stage')) { Remove-Item (Join-Path $out 'stage') -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

if ($IncludeWarcraftData) {
    $requiredFiles = @(
        'War3.mpq',
        'War3x.mpq',
        'Maps\FrozenThrone\(6)Moonglade.w3x'
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $WarcraftDataDir $file))) {
            throw "Missing required Warcraft III file in '$WarcraftDataDir': $file"
        }
    }

    $bundledDataDir = Join-Path $stage 'Warcraft III Legacy'
    New-Item -ItemType Directory -Path $bundledDataDir | Out-Null
    Get-ChildItem -LiteralPath $WarcraftDataDir -Force |
        Copy-Item -Destination $bundledDataDir -Recurse -Force
}

Copy-Item (Join-Path $dist '*.exe'), (Join-Path $dist '*.dll') $stage
Copy-Item (Join-Path $dist 'share') $stage -Recurse
# Test aids and the Reforged map are not needed to play.
Remove-Item (Join-Path $stage 'share\warcraft-3\Scripts\Survivor\test_*.lua')
Get-ChildItem (Join-Path $stage 'share\warcraft-3') -Filter *.cfg | Where-Object Name -ne 'config.cfg' | Remove-Item
Remove-Item (Join-Path $stage 'share\warcraft-3\Maps\WarcraftSurvivor.w3m') -ErrorAction SilentlyContinue
# Ship the current scripts from src/, not whatever was last copied into dist.
Copy-Item (Join-Path $root 'src\ashenvale_survivor.lua'), (Join-Path $root 'src\engine_boot.lua') `
    (Join-Path $stage 'share\warcraft-3\Scripts\Survivor')
Copy-Item (Join-Path $PSScriptRoot 'Play Warcraft Survivors.bat'), (Join-Path $PSScriptRoot 'README.txt') $stage

if ($IncludeWarcraftData) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'one_click_launcher.ps1') -Destination $stage

    @'
Warcraft Survivors - one-click personal build
=============================================

Double-click the EXE to unpack the game temporarily and start it. The temporary
files are removed after you close the game. No Warcraft III installation is
needed on this computer.

This package contains Blizzard game data. Keep it for your personal use and do
not upload or share this package.

Progress is saved in %APPDATA%\warcraft-3\CustomMapData\WarcraftSurvivors\.
'@ | Set-Content -LiteralPath (Join-Path $stage 'README.txt') -Encoding UTF8
}

$archive = Join-Path $out 'stage\pack.7z'
& $sevenZip a -t7z -mx=9 $archive (Join-Path $out 'stage\Warcraft Survivors') | Out-Null
if ($LASTEXITCODE) { throw "7z failed ($LASTEXITCODE)" }

$configFile = $null
if ($IncludeWarcraftData) {
    $configFile = Join-Path $out 'stage\sfx-config.txt'
    $sfxConfig = @'
;!@Install@!UTF-8!
Title="Warcraft Survivors"
Progress="yes"
Directory=""
RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%%T\\Warcraft Survivors\\one_click_launcher.ps1\""
;!@InstallEnd@!
'@
    [IO.File]::WriteAllText($configFile, $sfxConfig, [Text.UTF8Encoding]::new($false))
}

$exeName = if ($IncludeWarcraftData) { 'WarcraftSurvivors-OneClick.exe' } else { 'WarcraftSurvivors.exe' }
$exe = Join-Path $out $exeName
$fs = [IO.File]::Create($exe)
if ($IncludeWarcraftData) { $parts = @($sfx, $configFile, $archive) } else { $parts = @($sfx, $archive) }
foreach ($part in $parts) { $b = [IO.File]::ReadAllBytes($part); $fs.Write($b, 0, $b.Length) }
$fs.Close()
Remove-Item (Join-Path $out 'stage') -Recurse -Force
"{0} ({1:N1} MB)" -f $exe, ((Get-Item $exe).Length / 1MB)
