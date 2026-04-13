#!/bin/sh
# setmeup update — pull latest configs and update tools
set -e

info()  { printf '\033[1;34m[setmeup]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[setmeup]\033[0m %s\n' "$1"; }

export PATH="$HOME/.local/bin:$PATH"

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

info "Installing mise tools..."
mise install --yes

info "Upgrading mise tools..."
mise upgrade --yes

info "Installing and refreshing agent skills..."
SKILLS_LIST="$HOME/.config/setmeup/agent-skills.list"
if [ -f "$SKILLS_LIST" ]; then
    grep -v '^\s*#' "$SKILLS_LIST" | grep -v '^\s*$' | while read -r package agents; do
        agent_flags=""
        for agent in $agents; do
            agent_flags="$agent_flags -a $agent"
        done
        info "Installing $package for $agents..."
        mise exec node@lts -- npx -y skills add "$package" $agent_flags -g -y </dev/null || warn "Failed to install $package for $agents (non-fatal)"
    done
else
    warn "agent-skills.list not found at $SKILLS_LIST, skipping skill installation"
fi

# Update the check timestamp
mkdir -p "$HOME/.local/state/setmeup"
date +%s > "$HOME/.local/state/setmeup/last-check"

info "Update complete!"
