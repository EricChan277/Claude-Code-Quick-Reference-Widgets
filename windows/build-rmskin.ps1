# Build ClaudeUsage.rmskin
# Packages the skin from the repo root into a Rainmeter skin installer.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File windows/build-rmskin.ps1

param(
    [string]$Version = "3.0",
    [string]$OutDir  = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$SkinName = "ClaudeUsage"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$SkinSrc  = $RepoRoot   # top-level contains ClaudeUsage.ini and @Resources/
$OutFile  = Join-Path $OutDir "$SkinName-$Version.rmskin"

# --- sanity checks ----------------------------------------------------------
if (-not (Test-Path (Join-Path $SkinSrc "ClaudeUsage.ini"))) {
    Write-Error "ClaudeUsage.ini not found at $SkinSrc"
    exit 1
}

# --- staging area -----------------------------------------------------------
$Stage      = Join-Path $env:TEMP "rmskin-stage-$SkinName"
$SkinsStage = Join-Path $Stage "Skins\$SkinName"

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $SkinsStage -Force | Out-Null

# Skin files to include (exclude repo artifacts and runtime-generated files)
$ExcludeExact = @("windows", "mac", "README.md", "ARCHITECTURE.md", "LICENSE",
                  "install-agents.sh", ".git", ".claude", ".gitignore")
$ExcludeExt   = @(".png", ".rmskin")

Get-ChildItem $SkinSrc | Where-Object {
    $_.Name -notin $ExcludeExact -and $_.Extension -notin $ExcludeExt
} | ForEach-Object {
    Copy-Item $_.FullName $SkinsStage -Recurse -Force
}

# Remove runtime-generated files that shouldn't ship in the package
@("@Resources\usage.txt", "@Resources\agents.txt") | ForEach-Object {
    $f = Join-Path $SkinsStage $_
    if (Test-Path $f) { Remove-Item $f -Force }
}

# --- RMSKIN.ini -------------------------------------------------------------
@"
[rmskin]
Name=$SkinName
Author=Eric Chan
Version=$Version
LoadType=Skin
Load=$SkinName\ClaudeUsage.ini
MinimumRainmeter=4.5.0.0
MinimumWindows=5.1
"@ | Set-Content -Encoding UTF8 (Join-Path $Stage "RMSKIN.ini")

# --- zip and rename to .rmskin ----------------------------------------------
if (Test-Path $OutFile) { Remove-Item $OutFile -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $Stage,
    $OutFile,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

Remove-Item $Stage -Recurse -Force

$Size = (Get-Item $OutFile).Length / 1KB
Write-Host "Built: $OutFile  ($([math]::Round($Size,1)) KB)"
Write-Host "Double-click the .rmskin file on any Windows machine with Rainmeter installed."
