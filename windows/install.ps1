# Install ClaudeUsage Rainmeter skin
# Copies the skin into your Rainmeter skins directory and loads it.
# Launch via install.bat (double-click) or:
#   powershell -ExecutionPolicy Bypass -File windows/install.ps1

$ErrorActionPreference = "Stop"

$SkinName = "ClaudeUsage"
$RepoRoot = Split-Path $PSScriptRoot -Parent   # repo root holds ClaudeUsage.ini + @Resources

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

if (-not (Test-Path (Join-Path $RepoRoot "ClaudeUsage.ini"))) {
    Fail "ClaudeUsage.ini not found at $RepoRoot. Run this from the cloned repo."
}

# --- locate Rainmeter -------------------------------------------------------
$RainmeterIni = Join-Path $env:APPDATA "Rainmeter\Rainmeter.ini"
$RainmeterExe = $null
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $base) { continue }
    $candidate = Join-Path $base "Rainmeter\Rainmeter.exe"
    if (Test-Path $candidate) { $RainmeterExe = $candidate; break }
}
if (-not $RainmeterExe) {
    $cmd = Get-Command Rainmeter.exe -ErrorAction SilentlyContinue
    if ($cmd) { $RainmeterExe = $cmd.Source }
}
if (-not $RainmeterExe) {
    $url = "https://www.rainmeter.net/"
    Write-Host "Rainmeter is not installed." -ForegroundColor Red
    Write-Host "ClaudeUsage is a Rainmeter skin, so Rainmeter (free) is required." -ForegroundColor Gray
    Write-Host "Download it here: $url" -ForegroundColor Cyan
    $open = Read-Host "Open the Rainmeter download page now? [Y/n]"
    if ($open -notmatch '^[nN]') {
        try { Start-Process $url } catch { Write-Host "Could not open a browser. Visit $url manually." -ForegroundColor Yellow }
    }
    Write-Host ""
    Write-Host "Install Rainmeter, then run this installer again." -ForegroundColor Gray
    Read-Host "Press Enter to exit"
    exit 1
}

# --- resolve the skins directory (read SkinPath from Rainmeter.ini) ----------
$SkinPath = $null
if (Test-Path $RainmeterIni) {
    $line = Select-String -Path $RainmeterIni -Pattern '^\s*SkinPath\s*=\s*(.+)$' | Select-Object -First 1
    if ($line) { $SkinPath = $line.Matches[0].Groups[1].Value.Trim() }
}
if (-not $SkinPath) { $SkinPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "Rainmeter\Skins" }

$Dest = Join-Path $SkinPath $SkinName

# --- copy skin files --------------------------------------------------------
$srcResolved  = (Resolve-Path $RepoRoot).Path.TrimEnd('\')
$destResolved = $Dest.TrimEnd('\')

if ($srcResolved -ieq $destResolved) {
    Write-Host "Skin source is already the installed location ($Dest) - skipping copy." -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null

    Copy-Item (Join-Path $RepoRoot "ClaudeUsage.ini") $Dest -Force

    $resSrc = Join-Path $RepoRoot "@Resources"
    $resDst = Join-Path $Dest "@Resources"
    New-Item -ItemType Directory -Path $resDst -Force | Out-Null
    # ship only the engine; usage.txt/agents.txt are created at runtime
    Copy-Item (Join-Path $resSrc "usage.lua") $resDst -Force

    Write-Host "Copied skin to $Dest" -ForegroundColor Green
}

# --- load the skin in Rainmeter ---------------------------------------------
& $RainmeterExe "!ActivateConfig" "$SkinName" "ClaudeUsage.ini"
& $RainmeterExe "!Refresh" "$SkinName"

Write-Host ""
Write-Host "Installed and loaded '$SkinName'." -ForegroundColor Green
Write-Host "The widget will show 'no data' until your Claude Code statusline writes" -ForegroundColor Gray
Write-Host "$($Dest)\@Resources\usage.txt (see README for statusline.ps1 setup)." -ForegroundColor Gray
Write-Host ""
if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to close" }
