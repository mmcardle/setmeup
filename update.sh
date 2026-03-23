#!/bin/sh
# setmeup update — pull latest configs and update tools
set -e

info()  { printf '\033[1;34m[setmeup]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[setmeup]\033[0m %s\n' "$1"; }

export PATH="$HOME/.local/bin:$PATH"

info "Updating dotfiles..."
chezmoi update

info "Installing mise tools..."
mise install --yes

info "Upgrading mise tools..."
mise upgrade --yes

info "Refreshing agent skills..."
SKILLS_LIST="$HOME/.config/setmeup/agent-skills.list"
if [ -f "$SKILLS_LIST" ]; then
    grep -v '^\s*#' "$SKILLS_LIST" | grep -v '^\s*$' | while read -r package agent; do
        info "Installing $package for $agent..."
        mise exec node@lts -- npx -y skills add "$package" -a "$agent" -g -y || warn "Skills install failed for $package (non-fatal)"
    done
else
    warn "Skills list not found at $SKILLS_LIST"
fi

# Update the check timestamp
mkdir -p "$HOME/.local/state/setmeup"
date +%s > "$HOME/.local/state/setmeup/last-check"

info "Update complete!"
