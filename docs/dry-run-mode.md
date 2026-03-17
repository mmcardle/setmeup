# Dry-Run Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full dry-run mode to setmeup that previews every change (dotfiles, packages, tools, agents) without modifying the system.

**Architecture:** The `--dry-run` flag on `bootstrap.sh` sets `export SETMEUP_DRY_RUN=1`. Bootstrap uses `chezmoi diff` instead of `chezmoi init --apply` and skips all installs. Each chezmoi script also checks `SETMEUP_DRY_RUN` independently — this protects against the standalone `SETMEUP_DRY_RUN=1 chezmoi apply` use case (where scripts DO run, unlike bootstrap dry-run where they're never triggered).

**Tech Stack:** Shell (sh/bash), chezmoi CLI, mise CLI, apt/brew, BATS tests

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Modify | `bootstrap.sh` | Parse `--dry-run` flag, set env var, guard all destructive steps, use `chezmoi diff` |
| Modify | `home/.chezmoiscripts/run_onchange_001-install-packages.sh.tmpl` | Check env var, report missing packages instead of installing |
| Modify | `home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl` | Check env var, report what defaults would be set |
| Modify | `home/.chezmoiscripts/run_onchange_003-install-mise-tools.sh.tmpl` | Check env var, report missing mise tools instead of installing |
| Modify | `home/.chezmoiscripts/run_onchange_004-install-ai-agents.sh.tmpl` | Check env var, report which agents would be installed |
| Modify | `home/.chezmoiscripts/run_onchange_005-install-agent-skills.sh.tmpl` | Check env var, report which skills would be installed |
| Create | `tests/dry_run.bats` | BATS tests for dry-run mode |
| Modify | `tests/test_helper.bash` | Add `render_chezmoi_script` helper |
| Modify | `docs/adding-features.md` | Document dry-run mode |

---

## Chunk 1: bootstrap.sh dry-run flag

### Task 1: Dry-run in backup_dotfiles

**Files:**
- Create: `tests/dry_run.bats`
- Modify: `bootstrap.sh`

- [ ] **Step 1: Write the failing tests**

Create `tests/dry_run.bats`:

```bash
#!/usr/bin/env bats
load test_helper

@test "dry-run backup does not create a new backup directory" {
    require_setup
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        before=$(ls -d "$HOME/.local/state/setmeup/backups"/*/ 2>/dev/null | wc -l)
        SETMEUP_DRY_RUN=1 backup_dotfiles
        after=$(ls -d "$HOME/.local/state/setmeup/backups"/*/ 2>/dev/null | wc -l)
        echo "before=$before after=$after"
        [ "$before" -eq "$after" ]
    '
    [[ "$status" -eq 0 ]]
}

@test "dry-run backup lists files that would be backed up" {
    require_setup
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        SETMEUP_DRY_RUN=1 backup_dotfiles
    '
    [[ "$output" == *"Would back up"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL — `backup_dotfiles` doesn't check `SETMEUP_DRY_RUN`

- [ ] **Step 3: Implement dry-run in backup_dotfiles**

In `bootstrap.sh`, add a dry-run check inside `backup_dotfiles()` after the `has_files` check, before the real backup logic:

```bash
    # Dry-run: report what would be backed up, skip actual copy
    if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
        info "[dry-run] Would back up the following files:"
        for f in $BACKUP_FILES; do
            if [ -f "$HOME/$f" ]; then
                info "  Would back up: ~/$f"
            fi
        done
        return
    fi
```

Insert this block between the `has_files=false` early return and the `backup_dir=...` line.

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 2: Extract parse_args with --dry-run support

**Files:**
- Modify: `bootstrap.sh`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "parse_args sets SETMEUP_DRY_RUN=1 for --dry-run" {
    require_setup
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        parse_args --dry-run
        echo "DRY_RUN=$SETMEUP_DRY_RUN"
    '
    [[ "$output" == *"DRY_RUN=1"* ]]
}

@test "parse_args sets USE_LOCAL for --local" {
    require_setup
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        parse_args --local
        echo "USE_LOCAL=$USE_LOCAL"
    '
    [[ "$output" == *"USE_LOCAL=true"* ]]
}

@test "parse_args handles --dry-run --local together" {
    require_setup
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        parse_args --dry-run --local
        echo "DRY_RUN=$SETMEUP_DRY_RUN USE_LOCAL=$USE_LOCAL"
    '
    [[ "$output" == *"DRY_RUN=1"* ]]
    [[ "$output" == *"USE_LOCAL=true"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL — `parse_args` doesn't exist

- [ ] **Step 3: Implement parse_args**

Add a new function to `bootstrap.sh` before `main()`:

```bash
# ---------------------------------------------------------------------------
# Parse command-line arguments
# ---------------------------------------------------------------------------
parse_args() {
    USE_LOCAL=false
    export SETMEUP_DRY_RUN="${SETMEUP_DRY_RUN:-0}"
    while [ $# -gt 0 ]; do
        case "$1" in
            --local)    USE_LOCAL=true ;;
            --dry-run)  export SETMEUP_DRY_RUN=1 ;;
            *)          warn "Unknown argument: $1" ;;
        esac
        shift
    done
}
```

Replace the first two lines of `main()`:

```bash
main() {
    parse_args "$@"
```

Remove the old `USE_LOCAL=false` and `if [ "${1:-}" = "--local" ]` block from `main()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 3: Guard destructive operations in bootstrap main()

**Files:**
- Modify: `bootstrap.sh`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run bootstrap does not call chezmoi init --apply" {
    require_setup
    # Verify that the main function in dry-run mode uses chezmoi diff, not --apply
    # We test this by checking the script source for the conditional logic
    run bash -c '
        grep -A2 "SETMEUP_DRY_RUN.*=.*1" "$HOME/setmeup/bootstrap.sh" | head -20
    '
    # The script should contain dry-run conditional around chezmoi
    run bash -c '
        SETMEUP_SOURCED=true
        source "$HOME/setmeup/bootstrap.sh"
        parse_args --dry-run
        # Verify the variable is set
        [ "$SETMEUP_DRY_RUN" = "1" ]
    '
    [[ "$status" -eq 0 ]]
}
```

- [ ] **Step 2: Run test to verify current state**

Run: `make test-file FILE=dry_run.bats`

- [ ] **Step 3: Add dry-run guards to main()**

In `bootstrap.sh` `main()`, make these changes:

**a) Add dry-run banner after `parse_args`:**
```bash
    parse_args "$@"

    if [ "$SETMEUP_DRY_RUN" = "1" ]; then
        info "=== DRY-RUN MODE — no changes will be made ==="
    fi
```

**b) Guard install_prerequisites, install_chezmoi, install_mise:**
```bash
    if [ "$SETMEUP_DRY_RUN" = "1" ]; then
        info "[dry-run] Checking prerequisites (read-only)..."
        command_exists curl && info "  [installed] curl" || info "  [missing — would install] curl"
        command_exists git && info "  [installed] git" || info "  [missing — would install] git"
        command_exists chezmoi && info "  [installed] chezmoi" || info "  [missing — would install] chezmoi"
        command_exists mise && info "  [installed] mise" || info "  [missing — would install] mise"
    else
        install_prerequisites
        install_chezmoi
        install_mise
    fi
```

**c) Replace chezmoi init/apply block:**
```bash
    if [ "$USE_LOCAL" = true ]; then
        local script_dir
        script_dir="$(cd "$(dirname "$0")" && pwd)"
        if [ "$SETMEUP_DRY_RUN" = "1" ]; then
            info "[dry-run] Dotfile changes (chezmoi diff):"
            chezmoi init --source="$script_dir/home" 2>/dev/null || true
            chezmoi diff --source="$script_dir/home" || true
        else
            info "Initializing chezmoi from local source ($script_dir/home)..."
            chezmoi init --source="$script_dir/home" --apply
        fi
    else
        if [ "$SETMEUP_DRY_RUN" = "1" ]; then
            info "[dry-run] Dotfile changes (chezmoi diff):"
            chezmoi init "$SETMEUP_REPO" 2>/dev/null || true
            chezmoi diff || true
        else
            info "Initializing chezmoi with $SETMEUP_REPO..."
            chezmoi init --apply "$SETMEUP_REPO"
        fi
    fi
```

**d) Guard mise install and update script copy:**
```bash
    if [ "$SETMEUP_DRY_RUN" != "1" ]; then
        info "Installing mise tools..."
        mise install --yes || warn "Some mise tools failed to install (retry with: mise install)"

        local chezmoi_source
        chezmoi_source="$(chezmoi source-path)/.."
        cp "$chezmoi_source/update.sh" "$HOME/.local/bin/setmeup-update.sh"
        chmod +x "$HOME/.local/bin/setmeup-update.sh"
    fi
```

**e) Replace completion message:**
```bash
    if [ "$SETMEUP_DRY_RUN" = "1" ]; then
        info "=== DRY-RUN COMPLETE — no changes were made ==="
    else
        info "Bootstrap complete!"
        echo ""
        echo "  Your development environment is ready."
        echo "  Open a new shell to activate all settings."
        echo ""
        echo "  To update later, run:  setmeup update"
        echo "  Or manually:           chezmoi update && mise install"
        echo ""
    fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

---

## Chunk 2: Dry-run mode in chezmoi scripts

### Design note: two dry-run paths

There are two ways dry-run happens:

1. **`./bootstrap.sh --dry-run`** — bootstrap never calls `chezmoi apply`, so scripts 001-005 never execute. Bootstrap handles all reporting itself via `chezmoi diff` and prerequisite checks.

2. **`SETMEUP_DRY_RUN=1 chezmoi apply`** — chezmoi DOES execute scripts, and the env var is inherited by child processes. The guards in each script handle this path.

Both paths need to work. The tests for scripts use `chezmoi execute-template` to render the `.tmpl` files, then execute the rendered output with `SETMEUP_DRY_RUN=1`.

### Task 4: Add render_chezmoi_script test helper

**Files:**
- Modify: `tests/test_helper.bash`

- [ ] **Step 1: Add the helper function**

Append to `tests/test_helper.bash`:

```bash
# Render a chezmoi .tmpl script and return the rendered shell script as a string.
# Usage: rendered=$(render_chezmoi_script "run_onchange_001-install-packages.sh.tmpl")
render_chezmoi_script() {
    local script_name="$1"
    local tmpl_path="$HOME/setmeup/home/.chezmoiscripts/$script_name"
    if [[ ! -f "$tmpl_path" ]]; then
        echo "template not found: $tmpl_path" >&2
        return 1
    fi
    chezmoi execute-template --source="$HOME/setmeup/home" < "$tmpl_path"
}
```

- [ ] **Step 2: Verify the helper works**

Run: `make shell`, then inside the container:
```bash
source ~/tests/test_helper.bash
render_chezmoi_script "run_onchange_001-install-packages.sh.tmpl" | head -5
```
Expected: Rendered shell script without `{{ }}` template directives

### Task 5: Dry-run for script 001 (system packages)

**Files:**
- Modify: `home/.chezmoiscripts/run_onchange_001-install-packages.sh.tmpl`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run: script 001 reports packages without installing" {
    require_setup
    local rendered_file
    rendered_file=$(mktemp)
    render_chezmoi_script "run_onchange_001-install-packages.sh.tmpl" > "$rendered_file"
    run env SETMEUP_DRY_RUN=1 bash "$rendered_file"
    rm -f "$rendered_file"
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" != *"apt-get install"* ]]
    [[ "$output" != *"brew install"* ]]
}

@test "dry-run: script 001 shows installed vs missing packages" {
    require_setup
    local rendered_file
    rendered_file=$(mktemp)
    render_chezmoi_script "run_onchange_001-install-packages.sh.tmpl" > "$rendered_file"
    run env SETMEUP_DRY_RUN=1 bash "$rendered_file"
    rm -f "$rendered_file"
    # curl and git are definitely installed in the test container
    [[ "$output" == *"[installed] curl"* ]]
    [[ "$output" == *"[installed] git"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL — script doesn't check `SETMEUP_DRY_RUN`

- [ ] **Step 3: Implement dry-run in script 001**

Modify `home/.chezmoiscripts/run_onchange_001-install-packages.sh.tmpl`. Add the dry-run check after `set -e`, before the install commands, inside each OS conditional:

```bash
#!/bin/sh
# Install system-level packages (re-runs when this script changes)
# hash: {{ include ".chezmoiscripts/run_onchange_001-install-packages.sh.tmpl" | sha256sum }}
set -e

{{ if eq .chezmoi.os "linux" -}}
if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] System packages that would be installed via apt:"
    for pkg in build-essential curl git wget unzip zip software-properties-common apt-transport-https ca-certificates gnupg zsh htop tree ncdu tmux neovim httpie; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "  [installed] $pkg"
        else
            echo "  [missing — would install] $pkg"
        fi
    done
    exit 0
fi
echo "[setmeup] Installing system packages via apt..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential \
    curl \
    git \
    wget \
    unzip \
    zip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    zsh \
    htop \
    tree \
    ncdu \
    tmux \
    neovim \
    httpie
{{ else if eq .chezmoi.os "darwin" -}}
if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] System packages that would be installed via brew:"
    for pkg in curl git wget gnupg zsh htop tree ncdu tmux neovim httpie; do
        if brew list "$pkg" >/dev/null 2>&1; then
            echo "  [installed] $pkg"
        else
            echo "  [missing — would install] $pkg"
        fi
    done
    exit 0
fi
echo "[setmeup] Installing system packages via brew..."
brew install \
    curl \
    git \
    wget \
    gnupg \
    zsh \
    htop \
    tree \
    ncdu \
    tmux \
    neovim \
    httpie
{{ end -}}

echo "[setmeup] System packages installed."
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 6: Dry-run for script 002 (macOS defaults)

**Files:**
- Modify: `home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run: script 002 contains dry-run guard" {
    require_setup
    # On Linux, the rendered script is empty (darwin-only).
    # Verify the template source contains the dry-run guard.
    local tmpl="$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl"
    assert_file_contains "$tmpl" 'SETMEUP_DRY_RUN'
    assert_file_contains "$tmpl" '[dry-run]'
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL — template doesn't contain `SETMEUP_DRY_RUN`

- [ ] **Step 3: Implement dry-run in script 002**

Modify `home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl`. Add dry-run block inside the `{{ if eq .chezmoi.os "darwin" }}` section, after `set -e`:

```bash
#!/bin/sh
# Configure macOS defaults for development (re-runs when this script changes)
# hash: {{ include ".chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" | sha256sum }}
set -e

{{ if eq .chezmoi.os "darwin" -}}
if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] macOS defaults that would be configured:"
    echo "  Finder: show hidden files"
    echo "  Keyboard: enable key repeat (disable accent menu)"
    echo "  Keyboard: KeyRepeat=2, InitialKeyRepeat=15"
    echo "  Keyboard: disable auto-correct, auto-capitalize, period substitution"
    echo "  Finder: show all file extensions"
    echo "  Trackpad: enable tap to click"
    echo "  Would restart Finder to apply changes"
    exit 0
fi
echo "[setmeup] Configuring macOS defaults..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Enable key repeat (disable character accent menu)
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

# Disable automatic spelling corrections
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Enable tap to click on trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Apply Finder changes
killall Finder 2>/dev/null || true

echo "[setmeup] macOS defaults configured."
{{ end -}}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 7: Dry-run for script 003 (mise tools)

**Files:**
- Modify: `home/.chezmoiscripts/run_onchange_003-install-mise-tools.sh.tmpl`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run: script 003 reports mise tools without installing" {
    require_setup
    local rendered_file
    rendered_file=$(mktemp)
    render_chezmoi_script "run_onchange_003-install-mise-tools.sh.tmpl" > "$rendered_file"
    run env SETMEUP_DRY_RUN=1 PATH="$HOME/.local/bin:$PATH" bash "$rendered_file"
    rm -f "$rendered_file"
    [[ "$output" == *"[dry-run]"* ]]
    # Should NOT contain "Mise tools installed." (the non-dry-run success message)
    [[ "$output" != *"Mise tools installed."* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL

- [ ] **Step 3: Implement dry-run in script 003**

Modify `home/.chezmoiscripts/run_onchange_003-install-mise-tools.sh.tmpl`:

```bash
#!/bin/sh
# Install mise tools whenever the mise config changes
# mise config hash: {{ include "dot_config/mise/config.toml" | sha256sum }}
set -e

echo "[setmeup] Installing mise tools..."

export PATH="$HOME/.local/bin:$PATH"

if command -v mise >/dev/null 2>&1; then
    if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
        echo "[setmeup] [dry-run] Mise tools status:"
        mise ls 2>/dev/null || echo "  (no tools installed yet)"
        echo ""
        echo "[setmeup] [dry-run] Tools that would be installed/updated:"
        mise ls --missing 2>/dev/null || echo "  (unable to determine — mise install would resolve)"
        exit 0
    fi
    mise install --yes
    echo "[setmeup] Mise tools installed."
else
    echo "[setmeup] Warning: mise not found, skipping tool install"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 8: Dry-run for script 004 (AI agents)

**Files:**
- Modify: `home/.chezmoiscripts/run_onchange_004-install-ai-agents.sh.tmpl`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run: script 004 reports AI agents without installing" {
    require_setup
    local rendered_file
    rendered_file=$(mktemp)
    render_chezmoi_script "run_onchange_004-install-ai-agents.sh.tmpl" > "$rendered_file"
    run env SETMEUP_DRY_RUN=1 PATH="$HOME/.local/bin:$PATH" bash "$rendered_file"
    rm -f "$rendered_file"
    [[ "$output" == *"[dry-run]"* ]]
    # Should NOT invoke the curl installer
    [[ "$output" != *"curl -fsSL"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL

- [ ] **Step 3: Implement dry-run in script 004**

Modify `home/.chezmoiscripts/run_onchange_004-install-ai-agents.sh.tmpl`:

```bash
#!/bin/bash
# Install AI coding agents (re-runs when this script changes)
# hash: {{ include ".chezmoiscripts/run_onchange_004-install-ai-agents.sh.tmpl" | sha256sum }}
set -e

echo "[setmeup] Installing AI coding agents..."

export PATH="$HOME/.local/bin:$PATH"

if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] AI agent status:"
    if command -v claude >/dev/null 2>&1; then
        echo "  [installed] Claude Code ($(claude --version 2>/dev/null || echo 'version unknown'))"
    else
        echo "  [missing — would install] Claude Code"
    fi
    if command -v mise >/dev/null 2>&1 && mise exec node@lts -- npm ls -g @openai/codex >/dev/null 2>&1; then
        echo "  [installed] Codex"
    else
        echo "  [missing — would install] Codex (via npm)"
    fi
    exit 0
fi

# Claude Code — native installer
curl -fsSL https://claude.ai/install.sh | bash

# Codex — requires Node.js (mise exec auto-installs node@lts)
if command -v mise >/dev/null 2>&1; then
    mise exec node@lts -- npm i -g @openai/codex
else
    echo "[setmeup] Warning: mise not found, skipping Codex install"
fi

echo "[setmeup] AI coding agents installed."
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

### Task 9: Dry-run for script 005 (agent skills)

**Files:**
- Modify: `home/.chezmoiscripts/run_onchange_005-install-agent-skills.sh.tmpl`
- Modify: `tests/dry_run.bats`

- [ ] **Step 1: Write the failing test**

Append to `tests/dry_run.bats`:

```bash
@test "dry-run: script 005 reports agent skills without installing" {
    require_setup
    local rendered_file
    rendered_file=$(mktemp)
    render_chezmoi_script "run_onchange_005-install-agent-skills.sh.tmpl" > "$rendered_file"
    run env SETMEUP_DRY_RUN=1 PATH="$HOME/.local/bin:$PATH" bash "$rendered_file"
    rm -f "$rendered_file"
    [[ "$output" == *"[dry-run]"* ]]
    # Should NOT run npx
    [[ "$output" != *"npx"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dry_run.bats`
Expected: FAIL

- [ ] **Step 3: Implement dry-run in script 005**

Modify `home/.chezmoiscripts/run_onchange_005-install-agent-skills.sh.tmpl`:

```bash
#!/bin/bash
# Install agent skills (re-runs when this script changes)
# hash: {{ include ".chezmoiscripts/run_onchange_005-install-agent-skills.sh.tmpl" | sha256sum }}
set -e

echo "[setmeup] Installing agent skills..."

export PATH="$HOME/.local/bin:$PATH"

if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] Agent skills status:"
    if [ -d "$HOME/.claude/plugins" ]; then
        echo "  [installed] Claude Code superpowers skills"
    else
        echo "  [missing — would install] Claude Code superpowers skills (obra/superpowers)"
    fi
    if [ -d "$HOME/.codex/plugins" ] || [ -d "$HOME/.config/codex/plugins" ]; then
        echo "  [installed] Codex superpowers skills"
    else
        echo "  [missing — would install] Codex superpowers skills (obra/superpowers)"
    fi
    exit 0
fi

if command -v mise >/dev/null 2>&1; then
    mise exec node@lts -- npx -y skills add obra/superpowers -a claude-code -g -y
    mise exec node@lts -- npx -y skills add obra/superpowers -a codex -g -y
else
    echo "[setmeup] Warning: mise not found, skipping agent skills install"
fi

echo "[setmeup] Agent skills installed."
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dry_run.bats`
Expected: PASS

---

## Chunk 3: Documentation and final validation

### Task 10: Update documentation

**Files:**
- Modify: `docs/adding-features.md`

- [ ] **Step 1: Add dry-run section to adding-features.md**

Add a new section after "## Common Feature Types" heading:

```markdown
### Using dry-run mode

Preview what setmeup would do without making changes:

\`\`\`sh
# Full preview via bootstrap
./bootstrap.sh --dry-run --local

# Preview just chezmoi scripts (env var flows to child processes)
SETMEUP_DRY_RUN=1 chezmoi apply --source=./home
\`\`\`

Dry-run mode:
- Shows which dotfiles would change (via `chezmoi diff`)
- Reports which system packages are installed vs missing
- Reports which mise tools are installed vs missing
- Reports AI agent and skills installation status
- Does NOT create backups, install packages, or modify files

When adding a new chezmoi script, include a `SETMEUP_DRY_RUN` check at the top:

\`\`\`bash
if [ "${SETMEUP_DRY_RUN:-}" = "1" ]; then
    echo "[setmeup] [dry-run] What this script would do..."
    exit 0
fi
\`\`\`
```

### Task 11: Run full test suite

- [ ] **Step 1: Run the full test suite to confirm nothing is broken**

Run: `make test`
Expected: All existing tests pass + new dry_run.bats tests pass

- [ ] **Step 2: Fix any failures discovered**

---

## Implementation Notes

### How `SETMEUP_DRY_RUN` flows through the system

**Path A: `./bootstrap.sh --dry-run`**
1. `parse_args` sets `export SETMEUP_DRY_RUN=1`
2. Prerequisites are checked (read-only) instead of installed
3. `backup_dotfiles()` reports what would be backed up
4. `chezmoi init` sets up source (no `--apply`), then `chezmoi diff` shows changes
5. Scripts 001-005 never execute (chezmoi apply is never called)
6. `mise install` and update script copy are skipped

**Path B: `SETMEUP_DRY_RUN=1 chezmoi apply`**
1. Chezmoi applies dotfiles normally (this is the user's intent — they want files applied)
2. Scripts 001-005 DO execute, but each checks `SETMEUP_DRY_RUN` and switches to report mode
3. No packages installed, no tools built, no agents downloaded

### What dry-run does NOT do

- Does not prevent `chezmoi init` from writing its config (`.config/chezmoi/chezmoi.toml`) — needed for `chezmoi diff` to work
- Does not preview `oh-my-zsh` external downloads (`.chezmoiexternal.toml`) — these show in `chezmoi diff` output

### Edge cases on a dirty machine

- If chezmoi/mise already installed: `install_chezmoi`/`install_mise` skip (existing behavior); in dry-run they're reported as `[installed]`
- First-time chezmoi init: will prompt for git name/email even in dry-run mode (needed to compute diffs)
- Package checks: `dpkg -s` (Linux) and `brew list` (macOS) are read-only operations
