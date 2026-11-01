# Builds everything a release needs and lays it out for the user:
#
#   release\                         exactly what goes to the site's web root
#                                    (WinSCP: open it, copy everything)
#   engine\build\web\survivor-upload\download\Warcraft Survivors\WarcraftSurvivors.exe
#                                    the same portable build, playable, to test locally
#                                    before uploading
#
# Steps (each can be skipped when it is already done):
#   1. native engine: make openwarcraft3 (MSYS2), copied with src\*.lua into engine\dist\windows
#   2. browser engine: port/web/build-survivor.sh, then make_survivor_data.py (trimmed data)
#   3. portable build: make_portable.ps1 -Name 'Warcraft Survivors' (engine\build\portable:
#      the folder, WarcraftSurvivors.zip and update\portable)
#   4. stage_survivor_upload.py -> engine\build\web\survivor-upload (page, data, download\)
#   5. release\ mirrors survivor-upload (robocopy /MIR: anything else in release\ is deleted)
#   6. the playable copy goes to survivor-upload\download\Warcraft Survivors (after the
#      mirror, so it never reaches release\)
#
# Raise SURVIVOR_ENGINE.version and rewrite notes in src\engine_boot.lua before a release.
param(
    [switch]$SkipNative,
    [switch]$SkipWeb,
    [switch]$SkipPortable,
    [string]$WarcraftDataDir = 'C:\Program Files (x86)\Warcraft III (Legacy)'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot)
$engine = Join-Path $root 'engine'
$dist = Join-Path $engine 'dist\windows'
$portableOut = Join-Path $engine 'build\portable'
$web = Join-Path $engine 'build\web\survivor'
$upload = Join-Path $engine 'build\web\survivor-upload'
$release = Join-Path $root 'release'
$name = 'Warcraft Survivors'

function Step($text) { Write-Host ''; Write-Host "=== $text ===" -ForegroundColor Yellow }
function Check($what) { if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" } }
# robocopy: exit codes below 8 mean success.
function Mirror($from, $to) {
    & robocopy $from $to /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:1 | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $from -> $to failed ($LASTEXITCODE)" }
    $global:LASTEXITCODE = 0
}

$version = ([regex]::Match((Get-Content -Raw (Join-Path $root 'src\engine_boot.lua')), "version = '([^']*)'")).Groups[1].Value
Write-Host "Warcraft Survivors $version"

Push-Location $engine
try {
    if (-not $SkipNative) {
        Step 'Native engine'
        & 'C:\msys64\usr\bin\env.exe' MSYSTEM=UCRT64 OS=Windows_NT CHERE_INVOKING=1 /usr/bin/bash -lc `
            'make -j8 OS=Windows_NT BIN_DIR=build-windows/bin LIB_DIR=build-windows/lib openwarcraft3'
        Check 'make openwarcraft3'
        Copy-Item (Join-Path $engine 'build-windows\bin\openwarcraft3.exe') $dist
        Copy-Item (Join-Path $engine 'build-windows\lib\*.dll') $dist
    }
    # The scripts always come from src (the portable build copies them again).
    Copy-Item (Join-Path $root 'src\*.lua') (Join-Path $dist 'share\warcraft-3\Scripts\Survivor')

    if (-not $SkipWeb) {
        Step 'Browser engine (about 5 minutes)'
        & 'C:\Program Files\Git\bin\bash.exe' port/web/build-survivor.sh
        Check 'build-survivor.sh'
        Step 'Browser data'
        & python port/web/make_survivor_data.py $WarcraftDataDir build/web/survivor
        Check 'make_survivor_data.py'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $web 'data\files.json'))) {
        throw "No browser build with data in $web (run without -SkipWeb)"
    }

    if (-not $SkipPortable) {
        Step 'Portable build'
        & (Join-Path $PSScriptRoot 'make_portable.ps1') -Name $name -OutDir $portableOut -WarcraftDataDir $WarcraftDataDir
    }
    $zip = Join-Path $portableOut 'WarcraftSurvivors.zip'
    $updateDir = Join-Path $portableOut 'update\portable'
    $playable = Join-Path $portableOut $name
    foreach ($path in @($zip, (Join-Path $updateDir 'version.json'), (Join-Path $playable 'WarcraftSurvivors.exe'))) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path (run without -SkipPortable)" }
    }

    Step 'Upload folder'
    & python port/web/stage_survivor_upload.py build/web/survivor build/web/survivor-upload `
        --download $zip --portable-update $updateDir
    Check 'stage_survivor_upload.py'
} finally {
    Pop-Location
}

Step "release\ (copy all of it to the site with WinSCP)"
Mirror $upload $release

Step 'Playable copy to test'
$testCopy = Join-Path $upload "download\$name"
Mirror $playable $testCopy

$files = Get-ChildItem -LiteralPath $release -Recurse -File -Force
$served = (Get-Content -Raw (Join-Path $release 'download\portable\version.json') | ConvertFrom-Json).version
Write-Host ''
Write-Host ("Upload:  {0}  ({1} files, {2:N0} MB, version {3})" -f $release, $files.Count, (($files | Measure-Object Length -Sum).Sum / 1MB), $served) -ForegroundColor Green
Write-Host ("Test:    {0}" -f (Join-Path $testCopy 'WarcraftSurvivors.exe')) -ForegroundColor Green
Write-Host 'After the upload, open the site with Ctrl+F5 and check download/portable/version.json shows the new version.'
