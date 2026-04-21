# Enzo Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Windows installer that delivers the Viper Scale Racing second-brain ("Enzo") to Dan with full WooCommerce integration.

**Architecture:** Ship a zip from GitHub Releases. Dan extracts it, double-clicks `START-HERE.cmd`, which runs `install.ps1` (PowerShell, user-scope, no admin). The installer checks/installs Git, Claude Code, and Python, creates a venv for the WC integration, prompts for WooCommerce creds, creates a desktop shortcut, and initializes the project as a git repo pointed at Michael's remote for auto-updates. OAuth deferred to first launch.

**Tech Stack:** PowerShell 5.1+, Git Bash (for hooks), Python 3.11+ (for WC integration), Claude Code CLI.

**Spec:** `output/viper-racing/installer/TECHNICAL-SPEC.md` (v2)

**Build target directory:** `/Users/michaelatherton/viper-second-brain/`

---

### Task 1: Ship-time file modifications (wc.sh, auto-commit.sh, relationship.md)

These edits go into the source repo. They're needed for Windows compatibility and client delivery. Commit to a feature branch so main stays clean until we're ready.

**Files:**
- Modify: `scripts/wc.sh:22-36`
- Modify: `.claude/hooks/auto-commit.sh:85-93`
- Modify: `.claude/src/relationship.md:3`

- [ ] **Step 1: Create feature branch**

```bash
cd /Users/michaelatherton/viper-second-brain
git checkout -b feat/enzo-installer
```

- [ ] **Step 2: Add Windows venv path fallback to wc.sh**

Edit `scripts/wc.sh`. Replace lines 22-36 with:

```bash
# Pick Python: venv first (Unix then Windows), then system.
VENV_PY="$VAULT_ROOT/integrations/woocommerce/.venv/bin/python"
VENV_PY_WIN="$VAULT_ROOT/integrations/woocommerce/.venv/Scripts/python.exe"
if [[ -x "$VENV_PY" ]]; then
  PY="$VENV_PY"
elif [[ -x "$VENV_PY_WIN" ]]; then
  PY="$VENV_PY_WIN"
else
  # Fall back to python3, then python.
  if command -v python3 >/dev/null 2>&1; then
    PY="python3"
  elif command -v python >/dev/null 2>&1; then
    PY="python"
  else
    echo '{"ok": false, "command": "wrapper", "error": "config_error", "message": "no python interpreter found; create integrations/woocommerce/.venv or install python3"}' >&2
    exit 1
  fi
fi
```

- [ ] **Step 3: Verify wc.sh still works on Mac**

```bash
cd /Users/michaelatherton/viper-second-brain
bash scripts/wc.sh health
```

Expected: JSON output with `"ok": true`. The Unix path still matches first, so Mac behavior is unchanged.

- [ ] **Step 4: Remove git push from auto-commit.sh**

Edit `.claude/hooks/auto-commit.sh`. Replace lines 85-93 (the `sync_and_push` function body) with:

```bash
    if ! git pull --no-rebase origin main 2>>"$LOG_FILE"; then
      log_error "merge also failed for $REL_PATH — local commit saved but not synced"
      return 1
    fi
  fi
  # Push removed for client delivery — commits stay local
  # Dan's corrections are harvested manually during check-ins
}
```

- [ ] **Step 5: Verify auto-commit still commits locally**

```bash
cd /Users/michaelatherton/viper-second-brain
echo "test" >> /tmp/test-autocommit.txt
# Manually invoke the hook logic to verify commit works
git status
```

The hook fires on Write/Edit tool calls inside Claude Code, so full verification happens during §9 testing. For now, confirm the file parses (no syntax errors): `bash -n .claude/hooks/auto-commit.sh`

- [ ] **Step 6: Commit ship-time modifications**

```bash
git add scripts/wc.sh .claude/hooks/auto-commit.sh
git commit -m "feat(installer): add Windows venv path + remove git push for client delivery"
```

---

### Task 2: Promote portable permission rules into settings.json

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Edit settings.json**

Replace the entire `permissions.allow` array in `.claude/settings.json` with:

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Read(.claude/src/*)",
      "Edit(.claude/src/*)",
      "Write(.claude/src/*)",
      "Bash(bash scripts/wc.sh:*)",
      "Bash(python -m integrations.woocommerce.cli:*)",
      "Bash(python3 -m integrations.woocommerce.cli:*)",
      "Skill(draft-reply)",
      "Skill(draft-facebook-reply)",
      "Skill(catalog-lookup)",
      "Skill(categorize-email)",
      "Skill(teach)",
      "Skill(onboard)",
      "Skill(extract-knowledge)",
      "Skill(ingest-catalog)",
      "Skill(ingest-emails)",
      "Skill(ingest-facebook)",
      "Skill(ingest-site)"
    ]
  },
  "hooks": {
```

Keep the entire `hooks` block unchanged — just expand the `allow` array.

- [ ] **Step 2: Validate JSON syntax**

```bash
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "valid JSON"
```

Expected: `valid JSON`

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat(installer): promote portable permission rules for zero-prompt client UX"
```

---

### Task 3: Create installer files (START-HERE.cmd, launch.bat, .env.template, README.md)

**Files:**
- Create: `START-HERE.cmd`
- Create: `launch.bat`
- Create: `.env.template`
- Create: `README.md` (client-facing — the existing README is `WOOCOMMERCE-INTEGRATION-HANDOFF.md`, not a client doc)

- [ ] **Step 1: Create START-HERE.cmd**

```cmd
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
```

- [ ] **Step 2: Create launch.bat**

```cmd
@echo off
cd /d "%~dp0"
claude
```

- [ ] **Step 3: Create .env.template**

```
# Viper WooCommerce Connection
# Get your keys at: WP Admin > WooCommerce > Settings > Advanced > REST API

WC_BASE_URL=https://viperscaleracing.com
WC_CONSUMER_KEY=ck_replace_with_your_key
WC_CONSUMER_SECRET=cs_replace_with_your_secret
WC_TIMEOUT_SECONDS=15
```

- [ ] **Step 4: Create README.md**

```markdown
# Enzo — Viper Scale Racing AI Assistant Setup

Three steps, once. Then you're done.

## Step 1: Unblock the zip (important!)
1. Find the zip file you downloaded (probably in Downloads)
2. Right-click it > Properties
3. At the bottom, check "Unblock" > OK

## Step 2: Extract
1. Right-click the zip > "Extract All" > Extract
2. The folder name must be "viper-second-brain" — don't rename it

## Step 3: Run the installer
1. Open the viper-second-brain folder
2. Double-click **START-HERE**
3. Follow the prompts (~10 minutes)

When finished, you'll see an **Enzo** icon on your desktop.
Double-click that anytime to use the assistant.

The first time you open Enzo, it will ask you to sign into your
Claude account in your browser. After that, you won't need to
sign in again.

---

Trouble? Email michael@airevolutionlabs.com and attach the file
`.install-log.txt` from inside the viper-second-brain folder.
```

- [ ] **Step 5: Update .gitignore to include new files but exclude install artifacts**

Add to `.gitignore`:

```
# Install artifacts (per-machine)
.install-log.txt
```

`START-HERE.cmd`, `launch.bat`, `.env.template`, and `README.md` should be tracked in git (they ship to Dan).

- [ ] **Step 6: Commit**

```bash
git add START-HERE.cmd launch.bat .env.template README.md .gitignore
git commit -m "feat(installer): add client-facing launcher and setup files"
```

---

### Task 4: Create install.ps1

The largest single file. See TECHNICAL-SPEC.md §6 for full scene-by-scene spec. All code below is the real implementation — test on PowerShell before shipping.

**Files:**
- Create: `install.ps1`

- [ ] **Step 1: Create install.ps1 with helpers and Scene 1 (Welcome)**

```powershell
#Requires -Version 5.1
# Enzo — Viper Scale Racing AI Assistant Installer
# Runs user-scope only. No admin rights required.

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
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
Write-Host "     Enzo — Viper Scale Racing Setup  (v$Version)" -ForegroundColor Cyan
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
```

- [ ] **Step 2: Add Scene 2 (Git for Windows)**

Append to `install.ps1`:

```powershell
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
```

- [ ] **Step 3: Add Scene 2.5 (Git repo init)**

Append to `install.ps1`:

```powershell
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
```

- [ ] **Step 4: Add Scene 3 (Claude Code)**

Append to `install.ps1`:

```powershell
# ── Scene 3: Claude Code ──────────────────────────────────
Write-Host ""
Write-Host "  [2/5] Checking Claude Code..." -ForegroundColor Yellow

if (Get-Command claude -ErrorAction SilentlyContinue) {
    $ccVer = (claude --version 2>&1) | Select-Object -First 1
    Write-Host "  OK  Claude Code found ($ccVer)" -ForegroundColor Green
    Log "CHECK claude: found $ccVer"
} else {
    Write-Host "  --  Claude Code not found. Installing..." -ForegroundColor Yellow
    Log "ACTION install claude-code"
    try {
        Invoke-RestMethod "https://claude.ai/install.ps1" | Invoke-Expression
    } catch {
        FailExit "Claude Code install failed: $_"
    }
    RefreshPath
    Start-Sleep -Seconds 2
    RefreshPath
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        FailExit "Claude Code installed but not found in PATH. Close this window, reopen, and run START-HERE again."
    }
    Write-Host "  OK  Claude Code installed" -ForegroundColor Green
    Log "VERIFY claude: installed"
}
```

- [ ] **Step 5: Add Scene 4 (Python + venv)**

Append to `install.ps1`:

```powershell
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
if ($LASTEXITCODE -ne 0) { FailExit "pip install failed — check your internet connection and run START-HERE again" }

& $venvPython -c "import requests, dotenv" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { FailExit "WooCommerce integration imports failed after install" }

Write-Host "  OK  WooCommerce integration ready" -ForegroundColor Green
Log "VERIFY woocommerce imports OK"
```

- [ ] **Step 6: Add Scene 5 (WooCommerce credentials)**

Append to `install.ps1`:

```powershell
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

    # Store URL
    do {
        $baseUrl = (Read-Host "  Store URL (e.g. https://viperscaleracing.com)").Trim()
        if ($baseUrl -notmatch "^https?://") {
            Write-Host "  Must start with http:// or https://" -ForegroundColor Red
        }
    } until ($baseUrl -match "^https?://")

    # Consumer Key
    do {
        $consumerKey = (Read-Host "  Consumer Key (starts with ck_)").Trim()
        if ($consumerKey -notmatch "^ck_") {
            Write-Host "  Must start with ck_" -ForegroundColor Red
        }
    } until ($consumerKey -match "^ck_")

    # Consumer Secret (masked)
    do {
        $secureSecret = Read-Host "  Consumer Secret (starts with cs_ — hidden as you type)" -AsSecureString
        $consumerSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret))
        if ($consumerSecret -notmatch "^cs_") {
            Write-Host "  Must start with cs_" -ForegroundColor Red
        }
    } until ($consumerSecret -match "^cs_")

    $envContent = @"
WC_BASE_URL=$baseUrl
WC_CONSUMER_KEY=$consumerKey
WC_CONSUMER_SECRET=$consumerSecret
WC_TIMEOUT_SECONDS=15
"@
    Set-Content -Path $envPath -Value $envContent -Encoding UTF8
    Write-Host "  OK  Credentials saved" -ForegroundColor Green
    Log "WRITE .env (3 fields)"
}
```

- [ ] **Step 7: Add Scene 6 (Desktop shortcut) + Scene 7 (Cache pre-warm) + Scene 8 (Success)**

Append to `install.ps1`:

```powershell
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
$shortcut.Description = "Enzo — Viper Scale Racing AI Assistant"
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
    Write-Host "  !!  bash not found — cache will build on first use" -ForegroundColor Yellow
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
```

- [ ] **Step 8: Verify install.ps1 parses without errors**

```bash
# On Mac, we can't run PowerShell, but we can check for obvious issues:
wc -l /Users/michaelatherton/viper-second-brain/install.ps1
cat /Users/michaelatherton/viper-second-brain/install.ps1 | head -5
```

Full verification happens on the Windows VM (Task 7).

- [ ] **Step 9: Commit**

```bash
git add install.ps1
git commit -m "feat(installer): add install.ps1 guided Windows installer"
```

---

### Task 5: Create assets directory and placeholder icon

**Files:**
- Create: `assets/viper.ico`

- [ ] **Step 1: Create assets directory**

```bash
mkdir -p /Users/michaelatherton/viper-second-brain/assets
```

- [ ] **Step 2: Create a placeholder .ico**

Use ImageMagick or a simple generator to create a 64x64 placeholder icon:

```bash
# If ImageMagick is available:
convert -size 64x64 xc:"#1a1a2e" -fill "#e94560" -font Helvetica -pointsize 40 -gravity center -annotate +0+0 "E" /Users/michaelatherton/viper-second-brain/assets/viper.ico
```

If ImageMagick isn't available, create a simple PNG and convert it, or use any 64x64 .ico file as a placeholder. The shortcut creation in install.ps1 gracefully skips the icon if the file doesn't exist.

- [ ] **Step 3: Commit**

```bash
git add assets/
git commit -m "feat(installer): add placeholder icon for desktop shortcut"
```

---

### Task 6: Create build-release.sh

The script Michael runs on his Mac to produce the release zip.

**Files:**
- Create: `build-release.sh`

- [ ] **Step 1: Create build-release.sh**

```bash
#!/usr/bin/env bash
# Build a release zip for the Enzo installer.
# Run from the viper-second-brain project root.
#
# Usage: bash build-release.sh [version]
#   e.g.: bash build-release.sh 1.0.0

set -euo pipefail

VERSION="${1:-1.0.0}"
RELEASE_DIR="/tmp/viper-release-$$"
ZIP_NAME="viper-second-brain-v${VERSION}.zip"

echo "=== Building Enzo Installer v${VERSION} ==="

# ── Step 1: Clean slate via git archive ────────────────────
echo "[1/7] Exporting from git..."
mkdir -p "$RELEASE_DIR"
git archive HEAD | tar -x -C "$RELEASE_DIR"

# ── Step 2: Apply exclude list ─────────────────────────────
echo "[2/7] Removing excluded files..."
rm -rf "$RELEASE_DIR"/audit
rm -rf "$RELEASE_DIR"/prd
rm -rf "$RELEASE_DIR"/scratch
rm -rf "$RELEASE_DIR"/doc
rm -rf "$RELEASE_DIR"/.obsidian
rm -f  "$RELEASE_DIR"/scripts/wc-*.sh
rm -rf "$RELEASE_DIR"/integrations/woocommerce/.venv
rm -rf "$RELEASE_DIR"/integrations/woocommerce/__pycache__
rm -f  "$RELEASE_DIR"/.claude/settings.local.json
rm -rf "$RELEASE_DIR"/.claude/cache
rm -rf "$RELEASE_DIR"/.claude/logs
rm -f  "$RELEASE_DIR"/.claude/hooks/error.log
rm -f  "$RELEASE_DIR"/.env
rm -f  "$RELEASE_DIR"/.env.*
find "$RELEASE_DIR" -name "*.pyc" -delete
find "$RELEASE_DIR" -name ".DS_Store" -delete
find "$RELEASE_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# ── Step 3: Apply ship-time edits ──────────────────────────
echo "[3/7] Applying ship-time edits..."

# Reset relationship.md first_met to null
if [[ -f "$RELEASE_DIR/.claude/src/relationship.md" ]]; then
  sed -i '' 's/^first_met: .*/first_met: null/' "$RELEASE_DIR/.claude/src/relationship.md"
  echo "  relationship.md: first_met reset to null"
fi

# Ensure outputs/ dir exists (empty)
mkdir -p "$RELEASE_DIR/outputs"

# ── Step 4: Grep sweep ─────────────────────────────────────
echo "[4/7] Running grep sweep..."
FAIL=0

if grep -r "/Users/michaelatherton" "$RELEASE_DIR" --include="*.md" --include="*.json" --include="*.sh" --include="*.py" --include="*.cmd" --include="*.bat" 2>/dev/null; then
  echo "FAIL: Found /Users/michaelatherton in release files"
  FAIL=1
fi

if grep -ri -E '\bmarshall\b|\bmarsh\b' "$RELEASE_DIR" --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | grep -v "Notable Moments" | grep -v "renamed me from"; then
  echo "FAIL: Found Marshall/Marsh references in release files"
  FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
  echo "=== BUILD FAILED — fix the above before releasing ==="
  rm -rf "$RELEASE_DIR"
  exit 1
fi
echo "  Grep sweep passed"

# ── Step 5: Assert settings.json ───────────────────────────
echo "[5/7] Validating settings.json..."
SETTINGS="$RELEASE_DIR/.claude/settings.json"
for rule in 'Bash(bash scripts/wc.sh' 'Bash(python -m integrations.woocommerce.cli' 'Skill(draft-reply)' 'Skill(teach)' 'Skill(catalog-lookup)'; do
  if ! grep -q "$rule" "$SETTINGS"; then
    echo "FAIL: settings.json missing rule: $rule"
    rm -rf "$RELEASE_DIR"
    exit 1
  fi
done

if [[ -f "$RELEASE_DIR/.claude/settings.local.json" ]]; then
  echo "FAIL: settings.local.json should not be in the release"
  rm -rf "$RELEASE_DIR"
  exit 1
fi
echo "  settings.json validated"

# ── Step 6: Zip ────────────────────────────────────────────
echo "[6/7] Creating zip..."
cd "$RELEASE_DIR"
zip -r "/tmp/$ZIP_NAME" . -x '*.DS_Store' > /dev/null
cd -

# ── Step 7: Summary ────────────────────────────────────────
echo "[7/7] Release built:"
echo "  File: /tmp/$ZIP_NAME"
echo "  Size: $(du -h "/tmp/$ZIP_NAME" | cut -f1)"
echo ""
echo "  File count: $(unzip -l "/tmp/$ZIP_NAME" | tail -1 | awk '{print $2}')"
echo ""
echo "  Upload to: https://github.com/MichaelAtherton/ViperScale-EmailResponseTraining/releases/new"
echo "  Tag: v${VERSION}"

# Cleanup
rm -rf "$RELEASE_DIR"
echo ""
echo "=== Done ==="
```

- [ ] **Step 2: Make executable**

```bash
chmod +x build-release.sh
```

- [ ] **Step 3: Test the build script (dry run)**

```bash
cd /Users/michaelatherton/viper-second-brain
bash build-release.sh 0.0.1-test
```

Expected: creates `/tmp/viper-second-brain-v0.0.1-test.zip`, prints file count and size. If grep sweep fails, fix the flagged files before proceeding.

- [ ] **Step 4: Verify zip contents**

```bash
unzip -l /tmp/viper-second-brain-v0.0.1-test.zip | head -40
```

Verify: no `.env`, no `settings.local.json`, no `audit/`, no `prd/`, no `scratch/`, no `wc-*.sh` (except `wc.sh`). Verify `install.ps1`, `START-HERE.cmd`, `launch.bat`, `.env.template`, `README.md` are present.

- [ ] **Step 5: Clean up test zip**

```bash
rm /tmp/viper-second-brain-v0.0.1-test.zip
```

- [ ] **Step 6: Commit**

```bash
git add build-release.sh
git commit -m "feat(installer): add build-release.sh with exclude list + grep sweep + validation"
```

---

### Task 7: Persona rename sweep

**Files:**
- Potentially modify: any file containing "Marshall" or "Marsh"

- [ ] **Step 1: Run the sweep**

```bash
cd /Users/michaelatherton/viper-second-brain
grep -ri -E '\bmarshall\b|\bmarsh\b' --include="*.md" --include="*.json" --include="*.sh" --include="*.py" --include="*.txt" .
```

- [ ] **Step 2: Fix any stale references**

For each file found: replace "Marshall" / "Marsh" with "Enzo" where it refers to the agent's name. Leave historical references in `relationship.md` Notable Moments ("Dan renamed me from Marshall/Marsh to Enzo") as-is.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(installer): sweep stale Marshall/Marsh references to Enzo"
```

---

### Task 8: Windows VM smoke test

This is the validation gate. Nothing ships until this passes.

**Files:** None created — this is testing.

- [ ] **Step 1: Get a Windows 10/11 VM**

Options: Parallels, VirtualBox with a Windows 11 dev VM (free from Microsoft), or a cloud VM (Azure, AWS).

- [ ] **Step 2: Build the release zip**

```bash
cd /Users/michaelatherton/viper-second-brain
bash build-release.sh 1.0.0-rc1
```

- [ ] **Step 3: Transfer zip to the VM**

Copy `/tmp/viper-second-brain-v1.0.0-rc1.zip` to the VM's Desktop.

- [ ] **Step 4: Follow the README exactly**

On the VM:
1. Right-click zip → Properties → Unblock → OK
2. Right-click zip → Extract All → Extract
3. Open the extracted folder
4. Double-click `START-HERE`

- [ ] **Step 5: Complete the install**

Follow all prompts. Use real Viper WooCommerce credentials. Time the install — target is under 10 minutes.

- [ ] **Step 6: Double-click "Enzo" on the desktop**

First launch:
- Claude Code opens
- Browser opens for OAuth → sign in with a Claude Pro account
- Return to terminal
- Enzo should greet as "Enzo" (not Marshall)

- [ ] **Step 7: Test core workflow**

Paste a real customer email. Trigger `/draft-reply`. Verify:
- WooCommerce API is queried (check `.claude/logs/wc-queries.jsonl` exists after)
- Reply is drafted in Dan's voice
- Zero permission prompts throughout

- [ ] **Step 8: Test hooks**

- Close Claude (`/exit` or Ctrl+C). Reopen via desktop icon.
- Verify Enzo mentions prior session context (session-briefing works)
- Check `relationship.md` — `first_met` should be today's date (first-meeting-check works)
- Edit a file via Enzo → verify `git log` shows a local commit (auto-commit works)
- Verify NO push was attempted (check `.claude/hooks/error.log` for push errors — should be empty or absent)

- [ ] **Step 9: Test /teach**

Run `/teach` with a correction. Close Claude, reopen. Verify the correction persists.

- [ ] **Step 10: Test re-run safety**

Run `START-HERE.cmd` again. Verify:
- All scenes are idempotent (no errors on second run)
- `.env` prompts "Keep existing? (y/n)" — answer y
- Shortcut recreated without error

- [ ] **Step 11: Log any failures**

For each failure:
1. Note which scene/step failed
2. Copy the error from the terminal
3. Check `.install-log.txt` for the corresponding log line
4. Fix in install.ps1, rebuild, retest

---

### Task 9: Cut release and hand off to Dan

**Files:** None — this is release management.

- [ ] **Step 1: Merge feature branch**

```bash
cd /Users/michaelatherton/viper-second-brain
git checkout main
git merge feat/enzo-installer
git push origin main
```

- [ ] **Step 2: Build final release**

```bash
bash build-release.sh 1.0.0
```

- [ ] **Step 3: Create GitHub release**

```bash
gh release create v1.0.0 /tmp/viper-second-brain-v1.0.0.zip \
  --title "Enzo v1.0.0" \
  --notes "First release of the Enzo AI assistant for Viper Scale Racing. See README.md inside the zip for setup instructions."
```

- [ ] **Step 4: Send release URL to Dan**

Email Dan with:
- The GitHub release download link
- A note: "Download the zip, follow the 3-step README inside. Takes about 10 minutes. I'm available for a screen-share if you want."

- [ ] **Step 5: Screen-share walkthrough (optional)**

Walk Dan through the install over Zoom/Teams if he prefers. Watch for any UX friction points and note them for v1.1.
