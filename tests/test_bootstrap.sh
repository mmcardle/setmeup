#!/bin/bash
# Test suite for setmeup bootstrap
set -euo pipefail

# Pass GITHUB_TOKEN to mise to avoid API rate limits
if [ -n "${GITHUB_TOKEN:-}" ]; then
    export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
fi

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '\033[1;32m  PASS\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '\033[1;31m  FAIL\033[0m %s\n' "$1"; }

assert_command() {
    if command -v "$1" >/dev/null 2>&1; then
        pass "command exists: $1"
    else
        fail "command missing: $1"
    fi
}

assert_file() {
    if [ -f "$1" ]; then
        pass "file exists: $1"
    else
        fail "file missing: $1"
    fi
}

assert_file_contains() {
    if [ -f "$1" ] && grep -q "$2" "$1"; then
        pass "file $1 contains '$2'"
    else
        fail "file $1 does not contain '$2'"
    fi
}

assert_mise_tool() {
    if mise which "$1" >/dev/null 2>&1; then
        pass "mise tool installed: $1"
    else
        fail "mise tool missing: $1"
    fi
}

# =========================================================================
echo ""
echo "========================================"
echo " Phase 1: Install chezmoi and mise"
echo "========================================"
echo ""

# Install chezmoi
echo "[test] Installing chezmoi..."
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Install mise
echo "[test] Installing mise..."
curl -fsLS https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

assert_command chezmoi
assert_command mise

# =========================================================================
echo ""
echo "========================================"
echo " Phase 2: Verify dotfile backup"
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

# Find the backup directory (there should be exactly one)
backup_root="$HOME/.local/state/setmeup/backups"
backup_dir=$(ls -d "$backup_root"/*/ 2>/dev/null | head -1)

if [ -n "$backup_dir" ]; then
    pass "backup directory created: $backup_dir"
else
    fail "no backup directory found in $backup_root"
fi

# Verify backed-up files exist with correct content
assert_file "${backup_dir}.bashrc"
assert_file "${backup_dir}.zshrc"
assert_file "${backup_dir}.config/git/config"
assert_file_contains "${backup_dir}.bashrc" "user's original bashrc"
assert_file_contains "${backup_dir}.zshrc" "user's original zshrc"
assert_file_contains "${backup_dir}.config/git/config" "user's original gitconfig"

# Verify file permissions were preserved (cp -p)
if [ "$(stat -c '%a' "${backup_dir}.bashrc")" = "600" ]; then
    pass "backup preserved file permissions"
else
    fail "backup did not preserve file permissions"
fi

# =========================================================================
echo ""
echo "========================================"
echo " Phase 3: Apply chezmoi from local source"
echo "========================================"
echo ""

# Initialize chezmoi using local source directory
chezmoi init --source="$HOME/setmeup/home" --apply

# Verify chezmoi overwrote the fake pre-existing files
if ! grep -q "user's original bashrc" "$HOME/.bashrc"; then
    pass "chezmoi overwrote original .bashrc"
else
    fail "chezmoi did not overwrite original .bashrc"
fi

# =========================================================================
echo ""
echo "========================================"
echo " Phase 4: Verify dotfiles"
echo "========================================"
echo ""

assert_file "$HOME/.bashrc"
assert_file "$HOME/.zshrc"
assert_file "$HOME/.aliases"
assert_file "$HOME/.config/git/config"
assert_file "$HOME/.config/mise/config.toml"
assert_file "$HOME/.ssh/config"

# Check templated values were applied
assert_file_contains "$HOME/.config/git/config" "Test User"
assert_file_contains "$HOME/.config/git/config" "test@example.com"

# Check aliases file content
assert_file_contains "$HOME/.aliases" "alias gs="
assert_file_contains "$HOME/.aliases" "alias dc="
assert_file_contains "$HOME/.aliases" "alias ll="

# Check shell configs source aliases
assert_file_contains "$HOME/.bashrc" ". ~/.aliases"
assert_file_contains "$HOME/.zshrc" "source ~/.aliases"

# Check mise activation
assert_file_contains "$HOME/.bashrc" "mise activate bash"
assert_file_contains "$HOME/.zshrc" "mise activate zsh"

# Check SSH config is OS-appropriate (should be Linux path, not macOS)
assert_file_contains "$HOME/.ssh/config" "IdentityFile ~/.ssh/id_ed25519"

# =========================================================================
echo ""
echo "========================================"
echo " Phase 5: Verify mise tools install"
echo "========================================"
echo ""

# Install mise tools
mise install --yes

assert_mise_tool node
assert_mise_tool python
assert_mise_tool jq
assert_mise_tool rg
assert_mise_tool fd
assert_mise_tool fzf
assert_mise_tool uv

# =========================================================================
echo ""
echo "========================================"
echo " Phase 6: Verify idempotency"
echo "========================================"
echo ""

# Run chezmoi apply again — should succeed without errors
if chezmoi apply --source="$HOME/setmeup/home"; then
    pass "chezmoi apply is idempotent"
else
    fail "chezmoi apply failed on second run"
fi

# =========================================================================
echo ""
echo "========================================"
echo " Phase 7: Verify update script"
echo "========================================"
echo ""

assert_file "$HOME/setmeup/update.sh"
if [ -x "$HOME/setmeup/update.sh" ]; then
    pass "update.sh is executable"
else
    fail "update.sh is not executable"
fi

# =========================================================================
echo ""
echo "========================================"
printf ' Results: \033[1;32m%d passed\033[0m, \033[1;31m%d failed\033[0m\n' "$PASS" "$FAIL"
echo "========================================"
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
