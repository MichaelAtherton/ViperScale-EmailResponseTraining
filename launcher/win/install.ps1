#Requires -Version 5.1
# Enzo - Viper Scale Racing AI Assistant Installer
# Runs user-scope only. No admin rights required.

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:LogPath = Join-Path $PSScriptRoot ".install-log.txt"

function Log([string]$event) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -Path $script:LogPath -Value "[$ts] $event"
}

function FailExit([string]$msg) {
    Write-Host "`n  X $msg" -ForegroundColor Red
    Log "ERROR $msg"
    Write-Host "`n  If you need help, email michael@airevolutionlabs.com"
    Write-Host "  and attach .install-log.txt from this folder.`n"
    Read-Host "  Press Enter to close"
    exit 1
}

function RefreshPath() {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ── Scene 1: Welcome ──────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host "     Enzo - Viper Scale Racing Setup  (v$Version)" -ForegroundColor Cyan
Write-Host "  =======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "     This will check for and install:"
Write-Host "       1. Git for Windows         (required)"
Write-Host "       2. Claude Code             (required)"
Write-Host "       3. Python 3.11+            (required)"
Write-Host "       4. WooCommerce connection  (your site)"
Write-Host "       5. Desktop shortcut"
Write-Host ""
Write-Host "     Time: ~10 minutes. No admin rights needed."
Write-Host ""
Read-Host "     Press ENTER to begin (or close this window to cancel)"
Log "START install v$Version"

# ── Scene 2: Git for Windows ──────────────────────────────
Write-Host ""
Write-Host "  [1/5] Checking Git for Windows..." -ForegroundColor Yellow

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVer = (git --version 2>&1) -replace "git version ", ""
    Write-Host "  OK  Git found ($gitVer)" -ForegroundColor Green
    Log "CHECK git: found $gitVer"
} else {
    Write-Host "  --  Git not found. Installing..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "ACTION install git via winget"
        winget install --id Git.Git --scope user --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { FailExit "Git install failed (winget exit code $LASTEXITCODE)" }
        RefreshPath
        Start-Sleep -Seconds 2
        RefreshPath
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            FailExit "Git installed but not found in PATH. Close this window, reopen, and run START-HERE again."
        }
        Write-Host "  OK  Git installed" -ForegroundColor Green
        Log "VERIFY git: installed"
    } else {
        Write-Host ""
        Write-Host "  winget is not available. Please install Git manually:" -ForegroundColor Yellow
        Start-Process "https://git-scm.com/download/win"
        FailExit "Install Git for Windows, then run START-HERE again."
    }
}

# ── Scene 2.5: Initialize git repo ────────────────────────
$repoUrl = "https://github.com/MichaelAtherton/ViperScale-EmailResponseTraining.git"

if (-not (Test-Path (Join-Path $PSScriptRoot ".git"))) {
    Write-Host ""
    Write-Host "  [..] Setting up update channel..." -ForegroundColor Yellow
    Push-Location $PSScriptRoot
    try {
        git init 2>&1 | Out-Null
        git remote add origin $repoUrl 2>&1 | Out-Null
        git fetch origin main 2>&1 | Out-Null
        git reset origin/main 2>&1 | Out-Null
        Write-Host "  OK  Update channel configured" -ForegroundColor Green
        Log "ACTION git init+fetch+reset"
    } catch {
        Write-Host "  !!  Could not set up update channel. Enzo will still work," -ForegroundColor Yellow
        Write-Host "      but won't receive automatic updates." -ForegroundColor Yellow
        Log "WARN git init failed: $_"
    }
    Pop-Location
} else {
    Log "CHECK git repo: already initialized"
}

# ── Scene 3: Claude Code ──────────────────────────────────
Write-Host ""
Write-Host "  [2/5] Checking Claude Code..." -ForegroundColor Yellow

# Known install location for Claude Code on Windows
$claudeDir = Join-Path $env:USERPROFILE ".local\bin"
$claudeExe = Join-Path $claudeDir "claude.exe"

function FindClaude() {
    if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path $claudeExe) {
        $env:PATH = "$claudeDir;$env:PATH"
        Log "ACTION added $claudeDir to PATH"
        return $true
    }
    return $false
}

if (FindClaude) {
    $ccVer = (claude --version 2>&1) | Select-Object -First 1
    Write-Host "  OK  Claude Code found ($ccVer)" -ForegroundColor Green
    Log "CHECK claude: found $ccVer"
} else {
    Write-Host "  --  Claude Code not found. Installing..." -ForegroundColor Yellow
    Log "ACTION install claude-code"

    # Clean any broken staging cache from a previous failed install
    $ccCache = Join-Path $env:USERPROFILE ".cache\claude"
    if (Test-Path $ccCache) {
        Remove-Item -Recurse -Force $ccCache -ErrorAction SilentlyContinue
        Log "ACTION cleaned stale CC staging cache"
    }

    # Strategy: try winget first (handles its own HTTPS, avoids PS TLS issues)
    # Fall back to PowerShell iex method if winget unavailable
    $ccInstalled = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  --  Installing via winget..." -ForegroundColor Yellow
        Log "ACTION install claude-code via winget"
        winget install Anthropic.ClaudeCode --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            $ccInstalled = $true
        } else {
            Write-Host "  !!  winget install returned exit code $LASTEXITCODE, trying alternative..." -ForegroundColor Yellow
            Log "WARN winget CC install exit code $LASTEXITCODE"
        }
    }

    if (-not $ccInstalled) {
        Write-Host "  --  Installing via Anthropic installer..." -ForegroundColor Yellow
        Log "ACTION install claude-code via iex"
        try {
            Invoke-RestMethod "https://claude.ai/install.ps1" | Invoke-Expression
        } catch {
            Log "WARN CC iex installer error: $_"
        }
    }

    Start-Sleep -Seconds 3
    RefreshPath

    if (-not (FindClaude)) {
        Write-Host ""
        Write-Host "  Could not find Claude Code after install." -ForegroundColor Yellow
        Write-Host "  Try installing manually:" -ForegroundColor Yellow
        Write-Host "    Option 1: winget install Anthropic.ClaudeCode" -ForegroundColor Cyan
        Write-Host "    Option 2: irm claude.ai/install.ps1 | iex" -ForegroundColor Cyan
        Write-Host "  Then run START-HERE again." -ForegroundColor Yellow
        FailExit "Claude Code not found after install attempt."
    }

    $ccVer = (claude --version 2>&1) | Select-Object -First 1
    if (-not $ccVer) {
        FailExit "Claude Code binary exists but failed to run. Try: winget install Anthropic.ClaudeCode"
    }
    Write-Host "  OK  Claude Code installed ($ccVer)" -ForegroundColor Green
    Log "VERIFY claude: installed $ccVer"
}

# ── Scene 4: Python 3.11+ ─────────────────────────────────
Write-Host ""
Write-Host "  [3/5] Checking Python..." -ForegroundColor Yellow

$pythonCmd = $null
foreach ($candidate in @("python", "python3")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        $verOutput = & $candidate --version 2>&1
        if ($verOutput -match "Python 3\.(1[1-9]|[2-9][0-9])") {
            $pythonCmd = $candidate
            break
        }
    }
}

if (-not $pythonCmd) {
    Write-Host "  --  Python 3.11+ not found. Installing..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "ACTION install python via winget"
        winget install --id Python.Python.3.11 --scope user --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { FailExit "Python install failed (winget exit code $LASTEXITCODE)" }
        RefreshPath
        Start-Sleep -Seconds 2
        RefreshPath
        $pythonCmd = "python"
        $verCheck = & python --version 2>&1
        if ($verCheck -notmatch "Python 3\.(1[1-9]|[2-9][0-9])") {
            FailExit "Python installed but version check failed: $verCheck"
        }
        Write-Host "  OK  Python installed" -ForegroundColor Green
        Log "VERIFY python: installed"
    } else {
        Start-Process "https://www.python.org/downloads/"
        FailExit "Install Python 3.11+, then run START-HERE again."
    }
} else {
    $pyVer = & $pythonCmd --version 2>&1
    Write-Host "  OK  $pyVer found" -ForegroundColor Green
    Log "CHECK python: $pyVer"
}

# Create venv + install WC dependencies
Write-Host "  --  Setting up WooCommerce integration..." -ForegroundColor Yellow
$venvPath = Join-Path $PSScriptRoot "integrations\woocommerce\.venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$venvPip = Join-Path $venvPath "Scripts\pip.exe"
$reqsPath = Join-Path $PSScriptRoot "integrations\woocommerce\requirements.txt"

if (-not (Test-Path $venvPython)) {
    & $pythonCmd -m venv $venvPath
    if ($LASTEXITCODE -ne 0) { FailExit "Python venv creation failed" }
    Log "ACTION create venv"
}

& $venvPip install -r $reqsPath 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { FailExit "pip install failed - check your internet connection and run START-HERE again" }

& $venvPython -c "import requests, dotenv" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { FailExit "WooCommerce integration imports failed after install" }

Write-Host "  OK  WooCommerce integration ready" -ForegroundColor Green
Log "VERIFY woocommerce imports OK"

# ── Scene 5: WooCommerce credentials ──────────────────────
Write-Host ""
Write-Host "  [4/5] WooCommerce Connection" -ForegroundColor Yellow

$envPath = Join-Path $PSScriptRoot ".env"

if (Test-Path $envPath) {
    Write-Host ""
    Write-Host "  Existing WooCommerce credentials found."
    $keepEnv = Read-Host "  Keep them? (y/n)"
    if ($keepEnv -eq "y" -or $keepEnv -eq "Y") {
        Write-Host "  OK  Keeping existing credentials" -ForegroundColor Green
        Log "CHECK .env: kept existing"
    } else {
        Remove-Item $envPath
        Log "ACTION .env: user chose to replace"
    }
}

if (-not (Test-Path $envPath)) {
    Write-Host ""
    Write-Host "  Get your API keys from:" -ForegroundColor Cyan
    Write-Host "  WP Admin > WooCommerce > Settings > Advanced > REST API"
    Write-Host ""

    do {
        $baseUrl = (Read-Host "  Store URL (e.g. https://viperscaleracing.com)").Trim()
        if ($baseUrl -notmatch "^https?://") {
            Write-Host "  Must start with http:// or https://" -ForegroundColor Red
        }
    } until ($baseUrl -match "^https?://")

    do {
        $consumerKey = (Read-Host "  Consumer Key (starts with ck_)").Trim()
        if ($consumerKey -notmatch "^ck_") {
            Write-Host "  Must start with ck_" -ForegroundColor Red
        }
    } until ($consumerKey -match "^ck_")

    do {
        $secureSecret = Read-Host "  Consumer Secret (starts with cs_ - hidden as you type)" -AsSecureString
        $consumerSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret))
        if ($consumerSecret -notmatch "^cs_") {
            Write-Host "  Must start with cs_" -ForegroundColor Red
        }
    } until ($consumerSecret -match "^cs_")

    $envLines = @(
        "WC_BASE_URL=$baseUrl",
        "WC_CONSUMER_KEY=$consumerKey",
        "WC_CONSUMER_SECRET=$consumerSecret",
        "WC_TIMEOUT_SECONDS=15"
    )
    Set-Content -Path $envPath -Value ($envLines -join "`r`n") -Encoding UTF8
    Write-Host "  OK  Credentials saved" -ForegroundColor Green
    Log "WRITE .env (3 fields)"
}

# ── Scene 6: Desktop shortcut ─────────────────────────────
Write-Host ""
Write-Host "  [5/5] Creating desktop shortcut..." -ForegroundColor Yellow

$shortcutPath = Join-Path $env:USERPROFILE "Desktop\Enzo.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $PSScriptRoot "launch.bat"
$shortcut.WorkingDirectory = $PSScriptRoot
$icoPath = Join-Path $PSScriptRoot "assets\viper.ico"
if (Test-Path $icoPath) {
    $shortcut.IconLocation = $icoPath
}
$shortcut.Description = "Enzo - Viper Scale Racing AI Assistant"
$shortcut.Save()
Write-Host "  OK  'Enzo' shortcut added to Desktop" -ForegroundColor Green
Log "WRITE shortcut Enzo.lnk"

# ── Scene 7: Pre-warm category cache ──────────────────────
Write-Host ""
Write-Host "  Warming up the WooCommerce catalog..." -ForegroundColor Yellow
$bashExe = (Get-Command bash -ErrorAction SilentlyContinue).Source
if ($bashExe) {
    Push-Location $PSScriptRoot
    try {
        & $bashExe "scripts/wc.sh" health 2>$null | Out-Null
        Write-Host "  OK  Catalog ready" -ForegroundColor Green
        Log "ACTION cache pre-warm OK"
    } catch {
        Write-Host "  !!  Cache will build on first use (not a problem)" -ForegroundColor Yellow
        Log "WARN cache pre-warm failed: $_"
    }
    Pop-Location
} else {
    Write-Host "  !!  bash not found - cache will build on first use" -ForegroundColor Yellow
    Log "WARN bash not in PATH, skipping cache pre-warm"
}

# ── Scene 8: Success ──────────────────────────────────────
Write-Host ""
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host "     Setup complete!" -ForegroundColor Green
Write-Host "  =======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "     Look for 'Enzo' on your desktop."
Write-Host "     Double-click to start."
Write-Host ""
Write-Host "     The first time you open Enzo, it will ask you"
Write-Host "     to sign into Claude in your browser."
Write-Host "     After that, you won't need to sign in again."
Write-Host ""
Write-Host "     Questions? michael@airevolutionlabs.com"
Write-Host "     Attach .install-log.txt from this folder."
Write-Host ""
Log "SUCCESS complete"
Read-Host "  Press Enter to close"
