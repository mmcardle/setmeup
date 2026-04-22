#!/usr/bin/env bash
# Start a new ticket worktree session. Takes a ticket name from $1
# (passed by tmux command-prompt) and opens fzf to pick the source repo.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$PATH"

ticket="${1:-}"
[ -z "$ticket" ] && exit 0

# Enumerate main repos under ~/devel (dirs with a real .git directory;
# worktrees have .git as a file pointing back to the parent, so they're skipped).
list_devel_repos() {
  local d
  for d in "$HOME"/devel/*/.git; do
    [ -d "$d" ] || continue
    basename "$(dirname "$d")"
  done
}

repo=$(
  list_devel_repos | fzf --tmux 80%,50% \
    --prompt 'repo> ' \
    --border-label " new ticket: $ticket " \
    --header '  pick the source repo'
) || exit 0
[ -z "$repo" ] && exit 0

exec tmuxinator start default "$repo" "$ticket"
