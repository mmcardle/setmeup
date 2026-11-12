#!/bin/sh
# Install only Matt Pocock's PR skill for both supported coding agents.
set -e

export PATH="$HOME/.local/bin:$PATH"

skill_log=$(mktemp)
trap 'rm -f "$skill_log"' EXIT
if mise exec node@lts -- npx --silent -y skills add mattpocock/skills \
    --skill pr -a codex claude-code -g -y </dev/null >"$skill_log" 2>&1; then
    echo "[setmeup] Matt Pocock's pr skill installed for Codex and Claude Code."
else
    cat "$skill_log" >&2
    exit 1
fi
