param(
    [string]$WarcraftDataDir = 'C:\Program Files (x86)\Warcraft III (Legacy)',
    # Folder under the output folder (an existing one is moved aside to
    # .previous-<stamp>, older ones deleted). The shared zip is built with
    # -Name 'Warcraft Survivors' (make_upload.ps1 does).
    [string]$Name = 'Warcraft Survivors Portable',
    # Builds go to engine\build\portable: release\ holds only the site's upload
    # copy (make_upload.ps1).
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path (Split-Path $PSScriptRoot)
$dist = Join-Path $root 'engine\dist\windows'
$out = if ($OutDir) { $OutDir } else { Join-Path $root 'engine\build\portable' }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$destination = Join-Path $out $Name
$stage = Join-Path $out "$Name.stage"
$runtime = Join-Path $stage 'OpenRealm'
$data = Join-Path $stage 'Data'
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

if (Test-Path -LiteralPath $stage) {
    throw "Staging folder already exists: $stage. Inspect it before removing it."
}
if (-not (Test-Path -LiteralPath $csc)) {
    throw "The .NET Framework C# compiler was not found at $csc"
}

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

New-Item -ItemType Directory -Force -Path $runtime, $data | Out-Null

# Copy the OpenRealm runtime and its own share/config tree, not benilla-config.
Copy-Item (Join-Path $dist '*.exe'), (Join-Path $dist '*.dll') $runtime
Copy-Item -LiteralPath (Join-Path $dist 'share') -Destination $runtime -Recurse
Remove-Item (Join-Path $runtime 'share\warcraft-3\Scripts\Survivor\test_*.lua')
Get-ChildItem -LiteralPath (Join-Path $runtime 'share\warcraft-3') -Filter *.cfg |
    Where-Object Name -ne 'config.cfg' | Remove-Item
Remove-Item (Join-Path $runtime 'share\warcraft-3\Maps\WarcraftSurvivor.w3m') -ErrorAction SilentlyContinue
Copy-Item (Join-Path $root 'src\ashenvale_survivor.lua'), (Join-Path $root 'src\engine_boot.lua') `
    (Join-Path $runtime 'share\warcraft-3\Scripts\Survivor')

# Only the Blizzard files the game reads: the four archives trimmed to the web build's
# reads list (tools/web_trace_reads.txt, plus War3zUpdate*.mpq) and the arena maps.
# The engine mounts them from Data the same way the browser does (~200 MB, not 1.5 GB).
$trim = Join-Path $out "$Name.trim"
if (Test-Path -LiteralPath $trim) { Remove-Item -LiteralPath $trim -Recurse -Force }
& python (Join-Path $root 'engine\port\web\make_survivor_data.py') $WarcraftDataDir $trim
if ($LASTEXITCODE -ne 0) {
    throw "Trimming the Warcraft III data failed with exit code $LASTEXITCODE"
}
# Real copies: the script hard-links the maps from the install.
Get-ChildItem -LiteralPath (Join-Path $trim 'data') -Force |
    Where-Object Name -ne 'files.json' |
    Copy-Item -Destination $data -Recurse -Force
Remove-Item -LiteralPath $trim -Recurse -Force

$launcher = Join-Path $stage 'WarcraftSurvivors.exe'
# The icon comes from tools/make_icon.py (the engine exe carries the same one).
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll `
    "/win32icon:$(Join-Path $PSScriptRoot 'warcraft_survivors.ico')" `
    "/out:$launcher" (Join-Path $PSScriptRoot 'warcraft_survivors_launcher.cs')
if ($LASTEXITCODE -ne 0) {
    throw "Launcher compilation failed with exit code $LASTEXITCODE"
}

@'
Warcraft Survivors - portable build
===================================

Double-click WarcraftSurvivors.exe to start the game. Keep the Data and OpenRealm
folders beside it. Data contains the Warcraft III 1.29 files the game reads
(trimmed archives and the arena maps); OpenRealm contains the modified OpenRealm
engine, its configuration, and the survivor scripts.

This package includes Blizzard game data taken from the builder's local install.

Progress is saved in %APPDATA%\warcraft-3\CustomMapData\WarcraftSurvivors\.

When a new version is out, the game says so on its main screen and can
download it (only the files that changed) and restart. Updates never touch
your progress.
'@ | Set-Content -LiteralPath (Join-Path $stage 'README.txt') -Encoding UTF8

# version.json: this build's version and files, which the launcher compares
# with the uploaded release (SURVIVOR_ENGINE.update) to offer updates.
& python (Join-Path $PSScriptRoot 'portable_manifest.py') write $stage
if ($LASTEXITCODE -ne 0) { throw "portable_manifest.py write failed ($LASTEXITCODE)" }

$backup = $null
# Keep one previous build at most (each is ~200 MB).
Get-ChildItem -LiteralPath $out -Directory -Filter "$Name.previous-*" | Remove-Item -Recurse -Force
if (Test-Path -LiteralPath $destination) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $out "$Name.previous-$stamp"
    if (Test-Path -LiteralPath $backup) {
        $backup = Join-Path $out "$Name.previous-$stamp-$([guid]::NewGuid().ToString('N'))"
    }
    Move-Item -LiteralPath $destination -Destination $backup
}

try {
    Move-Item -LiteralPath $stage -Destination $destination
} catch {
    if ($backup -and -not (Test-Path -LiteralPath $destination)) {
        Move-Item -LiteralPath $backup -Destination $destination
    }
    throw
}

# The update folder players' launchers download from (download/portable/ on
# the site, stage_survivor_upload.py --portable-update). Unchanged files keep
# their timestamp, so a WinSCP synchronize uploads only what changed.
$update = Join-Path $out 'update\portable'
& python (Join-Path $PSScriptRoot 'portable_manifest.py') stage $destination $update
if ($LASTEXITCODE -ne 0) { throw "portable_manifest.py stage failed ($LASTEXITCODE)" }

# The browser lobby's Download button serves this zip (stage_survivor_upload.py --download).
$zip = Join-Path $out 'WarcraftSurvivors.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
if (Test-Path -LiteralPath $sevenZip) {
    & $sevenZip a -tzip -mx=9 $zip $destination | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z failed ($LASTEXITCODE)" }
} else {
    Compress-Archive -LiteralPath $destination -DestinationPath $zip
}

"Portable folder created: $destination"
"Zip: {0} ({1:N0} MB)" -f $zip, ((Get-Item $zip).Length / 1MB)
if ($backup) { "Previous build preserved at: $backup" }
