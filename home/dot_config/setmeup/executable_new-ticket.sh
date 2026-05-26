#!/usr/bin/env bash
# Start a new ticket worktree session. With no arguments, prompts for
# ticket and base branch inside the tmux popup, then opens fzf to pick
# the source repo. With arguments, takes ticket from $1 and base from $2.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$PATH"

if [ "$#" -eq 0 ]; then
  read -r -p "ticket> " ticket || exit 0
  [ -z "$ticket" ] && exit 0

  read -r -p "base [staging]> " base || exit 0
  [ -z "$base" ] && base="staging"
else
  ticket="${1:-}"
  [ -z "$ticket" ] && exit 0
  base="${2:-staging}"
  [ -z "$base" ] && base="staging"
fi

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
  list_devel_repos | fzf \
    --prompt 'repo> ' \
    --border-label " new ticket: $ticket " \
    --header '  pick the source repo'
) || exit 0
[ -z "$repo" ] && exit 0

exec tmuxinator start default "$repo" "$ticket" "$base"
