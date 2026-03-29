#!/bin/sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/home/.chezmoiscripts/run_always_005-configure-claude-code.sh.tmpl"

if ! grep -qF "'Bash(make *)'" "$SCRIPT"; then
    echo "missing Claude permission in template: Bash(make *)" >&2
    exit 1
fi
