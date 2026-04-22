#Requires -Version 5.1
# Enzo - Viper Scale Racing AI Assistant Installer
# Runs user-scope only. No admin rights required.

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# install.ps1 lives at launcher\win\ — project root is two levels up
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$script:LogPath = Join-Path $ProjectRoot ".install-log.txt"

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

if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    Write-Host ""
    Write-Host "  [..] Setting up update channel..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
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

function AddToUserPath([string]$dir) {
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$dir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$dir;$currentPath", "User")
        $env:PATH = "$dir;$env:PATH"
        Log "ACTION added $dir to USER PATH permanently"
    }
}

function FindClaude() {
    if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path $claudeExe) {
        AddToUserPath $claudeDir
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
    $pyInstalled = $false

    # Try winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "ACTION install python via winget"
        winget install --id Python.Python.3.11 --scope user --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            $pyInstalled = $true
        } else {
            Write-Host "  !!  winget install failed (restricted capabilities or old winget)." -ForegroundColor Yellow
            Log "WARN winget python install failed exit code $LASTEXITCODE"
        }
    }

    if ($pyInstalled) {
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
        Write-Host ""
        Write-Host "  Please install Python manually:" -ForegroundColor Yellow
        Write-Host "    1. Download from https://www.python.org/downloads/" -ForegroundColor Cyan
        Write-Host "    2. Run the installer" -ForegroundColor Cyan
        Write-Host "    3. IMPORTANT: Check 'Add Python to PATH' at the bottom" -ForegroundColor Cyan
        Write-Host "    4. Click 'Install Now'" -ForegroundColor Cyan
        Write-Host "    5. After it finishes, run START-HERE again" -ForegroundColor Cyan
        Start-Process "https://www.python.org/downloads/"
        FailExit "Install Python 3.11+ with 'Add to PATH' checked, then run START-HERE again."
    }
} else {
    $pyVer = & $pythonCmd --version 2>&1
    Write-Host "  OK  $pyVer found" -ForegroundColor Green
    Log "CHECK python: $pyVer"
}

# Create venv + install WC dependencies
Write-Host "  --  Setting up WooCommerce integration..." -ForegroundColor Yellow
$venvPath = Join-Path $ProjectRoot "integrations\woocommerce\.venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$venvPip = Join-Path $venvPath "Scripts\pip.exe"
$reqsPath = Join-Path $ProjectRoot "integrations\woocommerce\requirements.txt"

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

# -- Scene 4.5: Node.js -------------------------------------------
Write-Host ""
Write-Host "  [3.5/5] Checking Node.js..." -ForegroundColor Yellow

if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVer = (node --version 2>&1)
    Write-Host "  OK  Node.js found ($nodeVer)" -ForegroundColor Green
    Log "CHECK node: found $nodeVer"
} else {
    Write-Host "  --  Node.js not found. Installing..." -ForegroundColor Yellow
    $nodeInstalled = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "ACTION install node via winget"
        winget install OpenJS.NodeJS.LTS --scope user --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) { $nodeInstalled = $true }
        else { Log "WARN winget node install failed exit code $LASTEXITCODE" }
    }
    if ($nodeInstalled) {
        RefreshPath
        Start-Sleep -Seconds 2
        RefreshPath
        Write-Host "  OK  Node.js installed" -ForegroundColor Green
        Log "VERIFY node: installed"
    } else {
        Write-Host "  Please install Node.js manually:" -ForegroundColor Yellow
        Write-Host "    Download from https://nodejs.org/" -ForegroundColor Cyan
        Write-Host "    Run the installer, then run START-HERE again" -ForegroundColor Cyan
        Start-Process "https://nodejs.org/"
        FailExit "Install Node.js LTS, then run START-HERE again."
    }
}

# Install chat UI server dependencies
Write-Host "  --  Installing chat UI dependencies..." -ForegroundColor Yellow
$launcherWin = Join-Path $ProjectRoot "launcher\win"
Push-Location $launcherWin
npm install --production 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { FailExit "npm install failed in launcher\win" }
Pop-Location
Write-Host "  OK  Chat UI ready" -ForegroundColor Green
Log "VERIFY npm install OK"

# ── Scene 5: WooCommerce credentials ──────────────────────
Write-Host ""
Write-Host "  [4/5] WooCommerce Connection" -ForegroundColor Yellow

$envPath = Join-Path $ProjectRoot ".env"

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
    Write-Host "  Enzo needs to connect to the Viper Scale Racing online store" -ForegroundColor Cyan
    Write-Host "  so it can look up parts and inventory when answering customers." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Michael should have given you 3 pieces of information:" -ForegroundColor Cyan
    Write-Host "    - Your website address  (e.g. https://viperscaleracing.com)" -ForegroundColor Cyan
    Write-Host "    - A consumer key        (starts with: ck_)" -ForegroundColor Cyan
    Write-Host "    - A consumer secret     (starts with: cs_)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  If you don't have these, ask Michael. He can send them to you." -ForegroundColor Yellow
    Write-Host ""

    do {
        $baseUrl = (Read-Host "  Your website address (e.g. https://viperscaleracing.com)").Trim()
        if (-not $baseUrl) {
            Write-Host "  Please enter your website address" -ForegroundColor Red
        } elseif ($baseUrl -notmatch "^https?://") {
            Write-Host "  That doesn't look right - it should start with https://" -ForegroundColor Red
        }
    } until ($baseUrl -match "^https?://")

    do {
        $consumerKey = (Read-Host "  Consumer Key").Trim()
        if ($consumerKey -notmatch "^ck_") {
            Write-Host "  That doesn't look right - it should start with ck_" -ForegroundColor Red
        }
    } until ($consumerKey -match "^ck_")

    do {
        $consumerSecret = (Read-Host "  Consumer Secret (starts with cs_)").Trim()
        if ($consumerSecret -notmatch "^cs_") {
            Write-Host "  That doesn't look right - it should start with cs_" -ForegroundColor Red
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

# -- Scene 5.5: User config ----------------------------------------
Write-Host ""
Write-Host "  [4.5/5] Personalizing Enzo" -ForegroundColor Yellow

$enzoDir = Join-Path $ProjectRoot ".enzo"
$configPath = Join-Path $enzoDir "config.json"

if (-not (Test-Path $configPath)) {
    if (-not (Test-Path $enzoDir)) { New-Item -ItemType Directory -Path $enzoDir | Out-Null }
    $name = Read-Host "  Your name (how Enzo will greet you)"
    if (-not $name) { $name = "Team" }
    $role = Read-Host "  Your role (e.g. Shop Owner)"
    if (-not $role) { $role = "User" }

    $configLines = @(
        '{',
        '  "userName": "' + $name + '",',
        '  "userRole": "' + $role + '",',
        '  "appName": "Enzo",',
        '  "subtitle": "Viper Shop Assistant",',
        '  "greeting": "Hey ' + $name + ' - what are we wrenching on?",',
        '  "heroSubtext": "Customer questions, tuning advice, or the numbers - ask away.",',
        '  "quickActions": [',
        '    { "icon": "package", "label": "Order lookup", "prompt": "Look up order " },',
        '    { "icon": "zap", "label": "Recommend a setup", "prompt": "Recommend a setup for " },',
        '    { "icon": "chart", "label": "Sales report", "prompt": "Pull a sales report for " },',
        '    { "icon": "book", "label": "Product specs", "prompt": "Give me the specs for " }',
        '  ],',
        '  "suggestions": [',
        '    { "icon": "zap", "label": "Best chassis for 12V drag racing?" },',
        '    { "icon": "package", "label": "Check order status by number" },',
        '    { "icon": "chart", "label": "Q1 sales summary" },',
        '    { "icon": "wrench", "label": "Mega-G+ tuning walkthrough" },',
        '    { "icon": "flag", "label": "SCDRL Spring Nationals details" },',
        '    { "icon": "users", "label": "Top customers by lifetime value" }',
        '  ],',
        '  "disclaimer": "Enzo can make mistakes on live orders - double-check dollar figures before replying to customers.",',
        '  "port": 3456',
        '}'
    )
    Set-Content -Path $configPath -Value ($configLines -join "`r`n") -Encoding UTF8
    Write-Host "  OK  Enzo configured for $name" -ForegroundColor Green
    Log "WRITE .enzo/config.json for $name"
} else {
    Write-Host "  OK  Config already exists" -ForegroundColor Green
    Log "CHECK .enzo/config.json: exists"
}

# ── Scene 6: Desktop shortcut ─────────────────────────────
Write-Host ""
Write-Host "  [5/5] Creating desktop shortcut..." -ForegroundColor Yellow

# Use Shell API to get the real Desktop path (handles OneDrive redirection)
$shell = New-Object -ComObject WScript.Shell
$desktopPath = $shell.SpecialFolders("Desktop")
$shortcutPath = Join-Path $desktopPath "Enzo.lnk"
$shortcut = $shell.CreateShortcut($shortcutPath)
$launcherDir = Join-Path $ProjectRoot "launcher\win"
$shortcut.TargetPath = Join-Path (Join-Path $ProjectRoot "launcher\win") "launch-ui.bat"
$shortcut.WorkingDirectory = $ProjectRoot
$icoPath = Join-Path $ProjectRoot "assets\viper.ico"
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
    Push-Location $ProjectRoot
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
