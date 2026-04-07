#!/bin/bash
# Pull remote changes on session start (catches Michael's updates)
# Cross-platform: works on macOS (native bash) and Windows (Git Bash)

LOG_FILE="$CLAUDE_PROJECT_DIR/.claude/hooks/error.log"
log_error() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" >> "$LOG_FILE" 2>/dev/null
}

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
  log_error "git not found in PATH — session-sync skipped"
  exit 0
fi

# Check if this is a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Abort any in-progress rebase from a prior crashed session
git rebase --abort 2>/dev/null

# Recover from detached HEAD — origin/main is always source of truth
if ! git symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  log_error "HEAD is detached, recovering to origin/main"
  git fetch origin main
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git reset --hard origin/main
  exit 0
fi

# Ensure we're on main, not some other branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ "$BRANCH" != "main" ]; then
  log_error "on branch '$BRANCH', switching to main"
  git checkout main 2>/dev/null
fi

# Pull with rebase
if ! git pull --rebase --autostash 2>>"$LOG_FILE"; then
  log_error "pull --rebase failed, falling back to merge"
  git rebase --abort 2>/dev/null
  if ! git pull --no-rebase 2>>"$LOG_FILE"; then
    log_error "pull --no-rebase also failed — manual intervention needed"
  fi
fi

exit 0
