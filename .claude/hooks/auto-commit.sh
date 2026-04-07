#!/bin/bash
# Auto-commit vault changes after Write/Edit operations
# Cross-platform: works on macOS (native bash) and Windows (Git Bash)
# No Python dependency — pure bash JSON extraction

LOG_FILE="$CLAUDE_PROJECT_DIR/.claude/hooks/error.log"
log_error() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" >> "$LOG_FILE" 2>/dev/null
}

INPUT=$(cat)

# Extract file_path from tool input JSON using pure bash
# Handles both "file_path" and "filePath" keys
FILE_PATH=""
for key in file_path filePath; do
  # Match "key": "value" — handles paths with spaces and backslashes
  match=$(echo "$INPUT" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1)
  if [ -n "$match" ]; then
    # Extract the value between the last pair of quotes
    FILE_PATH=$(echo "$match" | sed 's/.*:.*"\(.*\)"/\1/')
    break
  fi
done

# Exit if no file path extracted
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Get relative path from vault root
VAULT_ROOT="$CLAUDE_PROJECT_DIR"
REL_PATH="${FILE_PATH#$VAULT_ROOT/}"

# Handle Windows-style paths (backslashes → forward slashes)
REL_PATH=$(echo "$REL_PATH" | tr '\\' '/')

# Only auto-commit vault content directories
case "$REL_PATH" in
  context/*|knowledge/*|outputs/*)
    ;;
  *)
    exit 0
    ;;
esac

# Extract type and filename for commit message
FOLDER=$(echo "$REL_PATH" | cut -d'/' -f1)
FILENAME=$(basename "$REL_PATH" .md)

case "$FOLDER" in
  context) TYPE="context" ;;
  knowledge) TYPE="knowledge" ;;
  outputs) TYPE="output" ;;
  *) TYPE="$FOLDER" ;;
esac

cd "$VAULT_ROOT" || exit 0

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
  log_error "git not found in PATH — auto-commit skipped for $REL_PATH"
  exit 0
fi

# Check if this is a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  log_error "not a git repo — auto-commit skipped for $REL_PATH"
  exit 0
fi

# Recover from detached HEAD before committing
if ! git symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  log_error "HEAD is detached, recovering to origin/main"
  git fetch origin main 2>/dev/null
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git reset --hard origin/main
fi

# Pull-then-push helper: rebase if possible, merge if not
sync_and_push() {
  if ! git pull --rebase origin main 2>>"$LOG_FILE"; then
    log_error "rebase failed, falling back to merge"
    git rebase --abort 2>/dev/null
    if ! git pull --no-rebase origin main 2>>"$LOG_FILE"; then
      log_error "merge also failed for $REL_PATH — local commit saved but not pushed"
      return 1
    fi
  fi
  if ! git push -u origin main 2>>"$LOG_FILE"; then
    log_error "push failed for $REL_PATH — local commit saved but not pushed (check credentials/network)"
    return 1
  fi
}

# Check if file has changes
if git diff --quiet "$FILE_PATH" 2>/dev/null && git diff --cached --quiet "$FILE_PATH" 2>/dev/null; then
  # Check if it's a new untracked file
  if ! git ls-files --error-unmatch "$FILE_PATH" >/dev/null 2>&1; then
    git add "$FILE_PATH"
    git commit -m "vsr: new $TYPE - $FILENAME"
    sync_and_push
  fi
else
  git add "$FILE_PATH"
  git commit -m "vsr: update $TYPE - $FILENAME"
  sync_and_push
fi

exit 0
