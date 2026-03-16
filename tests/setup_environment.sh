#!/bin/bash
# Setup environment for BATS tests — runs once before test files
# Phases: verify tools, backup existing dotfiles, apply chezmoi
set -euo pipefail

SETUP_SENTINEL="$HOME/.local/state/setmeup/test-setup-complete"
BACKUP_STATE_FILE="$HOME/.local/state/setmeup/test-backup-dir"

# Pass GITHUB_TOKEN to mise to avoid API rate limits
if [ -n "${GITHUB_TOKEN:-}" ]; then
    export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
fi

# Skip if already run (allows re-running bats without re-setup)
if [ -f "$SETUP_SENTINEL" ]; then
    echo "[setup] Already complete, skipping (remove $SETUP_SENTINEL to re-run)"
    exit 0
fi

# =========================================================================
echo ""
echo "========================================"
echo " Phase 1: Verify chezmoi and mise"
echo "========================================"
echo ""

command -v chezmoi >/dev/null 2>&1 || { echo "FAIL: chezmoi not found in PATH"; exit 1; }
command -v mise >/dev/null 2>&1 || { echo "FAIL: mise not found in PATH"; exit 1; }
echo "OK: chezmoi and mise are available"

# =========================================================================
echo ""
echo "========================================"
echo " Phase 2: Create fake dotfiles and backup"
echo "========================================"
echo ""

# Create fake pre-existing dotfiles with identifiable content
echo "# user's original bashrc with secrets" > "$HOME/.bashrc"
chmod 600 "$HOME/.bashrc"
echo "# user's original zshrc with secrets" > "$HOME/.zshrc"
mkdir -p "$HOME/.config/git"
echo "# user's original gitconfig" > "$HOME/.config/git/config"

# Source bootstrap.sh to get the real backup_dotfiles function
SETMEUP_SOURCED=true
. "$HOME/setmeup/bootstrap.sh"

# Call the real backup function
backup_dotfiles

# Find the backup directory and save its path for tests
backup_root="$HOME/.local/state/setmeup/backups"
backup_dir=$(ls -d "$backup_root"/*/ 2>/dev/null | head -1)

if [ -z "$backup_dir" ]; then
    echo "FAIL: no backup directory found in $backup_root"
    exit 1
fi

mkdir -p "$(dirname "$BACKUP_STATE_FILE")"
echo "$backup_dir" > "$BACKUP_STATE_FILE"
echo "OK: backup directory saved to $BACKUP_STATE_FILE"

# =========================================================================
echo ""
echo "========================================"
echo " Phase 3: Apply chezmoi from local source"
echo "========================================"
echo ""

chezmoi init --source="$HOME/setmeup/home" --apply
echo "OK: chezmoi applied"

# Write sentinel
mkdir -p "$(dirname "$SETUP_SENTINEL")"
echo "$(date)" > "$SETUP_SENTINEL"
echo ""
echo "========================================"
echo " Setup complete"
echo "========================================"
echo ""
