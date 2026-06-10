#!/bin/sh
# setmeup update — pull latest configs and update tools
set -e

info()  { printf '\033[1;34m[setmeup]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[setmeup]\033[0m %s\n' "$1"; }

export PATH="$HOME/.local/bin:$PATH"

cleanup_legacy_pi() {
    info "Removing legacy Pi package if present..."
    mise uninstall --yes npm:@mariozechner/pi-coding-agent >/dev/null 2>&1 || true
    mise exec node@lts -- npm uninstall -g @mariozechner/pi-coding-agent >/dev/null 2>&1 || true
    mise reshim >/dev/null 2>&1 || true
}

ensure_claude_native_binary() {
    claude_bin="$(mise which claude)"
    claude_real="$(mise exec node@lts -- node -e 'console.log(require("fs").realpathSync(process.argv[1]))' "$claude_bin")"
    claude_pkg_dir="$(dirname "$(dirname "$claude_real")")"

    if [ ! -f "$claude_pkg_dir/install.cjs" ]; then
        warn "Claude Code postinstall script not found at $claude_pkg_dir/install.cjs"
        return 1
    fi

    info "Repairing Claude Code native binary..."
    mise exec node@lts -- node "$claude_pkg_dir/install.cjs"
    mise exec node@lts npm:@anthropic-ai/claude-code -- claude --version >/dev/null
}

bootstrap_script=""
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$script_dir/bootstrap.sh" ]; then
    bootstrap_script="$script_dir/bootstrap.sh"
elif command -v chezmoi >/dev/null 2>&1; then
    chezmoi_source_path="$(chezmoi source-path 2>/dev/null || true)"
    if [ -n "$chezmoi_source_path" ] && [ -f "$chezmoi_source_path/../bootstrap.sh" ]; then
        bootstrap_script="$chezmoi_source_path/../bootstrap.sh"
    fi
fi

if [ -n "$bootstrap_script" ]; then
    SETMEUP_SOURCED=true . "$bootstrap_script"
    print_banner
fi

info "Updating dotfiles..."
if ! chezmoi update 2>/dev/null; then
    warn "chezmoi update unavailable (no git remote), applying local changes"
    chezmoi apply
fi

cleanup_legacy_pi

info "Installing mise tools..."
mise install --yes

info "Upgrading mise tools..."
mise upgrade --yes

cleanup_legacy_pi

info "Installing and refreshing Claude Code plugins..."
CLAUDE_PLUGINS_LIST="$HOME/.config/setmeup/claude-plugins.list"
if [ -f "$CLAUDE_PLUGINS_LIST" ]; then
    ensure_claude_native_binary || warn "Claude Code native binary repair failed; plugin install may fail"

    plugin_lines="$(grep -vE '^\s*(#|$)' "$CLAUDE_PLUGINS_LIST" || true)"

    # Register marketplaces (deduped). marketplace add is idempotent.
    printf '%s\n' "$plugin_lines" | awk '{print $2}' | sort -u | while read -r source; do
        [ -n "$source" ] || continue
        info "marketplace add: $source"
        mise exec node@lts npm:@anthropic-ai/claude-code -- claude plugin marketplace add "$source" </dev/null \
            || warn "marketplace add failed for $source (non-fatal)"
    done

    # Install plugins. install errors when plugin is already installed; tolerate.
    printf '%s\n' "$plugin_lines" | while read -r plugin _source; do
        [ -n "$plugin" ] || continue
        info "plugin install: $plugin"
        mise exec node@lts npm:@anthropic-ai/claude-code -- claude plugin install "$plugin" -s user </dev/null \
            || warn "plugin install failed for $plugin (non-fatal — may already be installed)"
    done
else
    warn "claude-plugins.list not found at $CLAUDE_PLUGINS_LIST, skipping plugin install"
fi

info "Installing and refreshing Codex skills..."
CODEX_SKILLS_LIST="$HOME/.config/setmeup/codex-skills.list"
if [ -f "$CODEX_SKILLS_LIST" ]; then
    grep -vE '^\s*(#|$)' "$CODEX_SKILLS_LIST" | while read -r package; do
        [ -n "$package" ] || continue
        info "codex skills add: $package"
        # `skills` CLI has no --quiet flag; capture output and only surface it
        # on failure. `npx --silent` suppresses npm's own chatter.
        skill_log=$(mktemp)
        if mise exec node@lts -- npx --silent -y skills add "$package" -a codex -g -y </dev/null >"$skill_log" 2>&1; then
            rm -f "$skill_log"
        else
            cat "$skill_log" >&2
            rm -f "$skill_log"
            warn "Failed to install $package for codex (non-fatal)"
        fi
    done
else
    warn "codex-skills.list not found at $CODEX_SKILLS_LIST, skipping codex skill install"
fi

# Update the check timestamp
mkdir -p "$HOME/.local/state/setmeup"
date +%s > "$HOME/.local/state/setmeup/last-check"

info "Update complete!"
