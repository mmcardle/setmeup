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
mise exec node@lts -- npx -y skills update -a claude-code -g -y || warn "Skills refresh failed (non-fatal)"
mise exec node@lts -- npx -y skills update -a codex -g -y || warn "Skills refresh failed (non-fatal)"

# Update the check timestamp
mkdir -p "$HOME/.local/state/setmeup"
date +%s > "$HOME/.local/state/setmeup/last-check"

info "Update complete!"
