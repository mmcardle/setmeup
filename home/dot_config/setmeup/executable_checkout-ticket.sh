#!/usr/bin/env bash
# Check out an existing branch in a worktree session. With no arguments,
# picks the source repo via fzf, then picks an existing branch (local or
# from origin) via fzf. With arguments, takes branch from $1 and repo
# from $2; if $2 is omitted, the repo is still picked via fzf.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$PATH"

list_devel_repos() {
  local d
  for d in "$HOME"/devel/*/.git; do
    [ -d "$d" ] || continue
    basename "$(dirname "$d")"
  done
}

branch="${1:-}"
repo="${2:-}"

if [ -z "$repo" ]; then
  repo=$(
    list_devel_repos | fzf \
      --prompt 'repo> ' \
      --border-label ' checkout ticket ' \
      --header '  pick the source repo'
  ) || exit 0
  [ -z "$repo" ] && exit 0
fi

if [ -z "$branch" ]; then
  # Refresh remote refs so freshly-pushed branches are pickable.
  git -C "$HOME/devel/$repo" fetch origin >/dev/null 2>&1 || true

  branch=$(
    git -C "$HOME/devel/$repo" for-each-ref \
      --format='%(refname:short)' \
      refs/heads refs/remotes/origin \
    | sed 's|^origin/||' \
    | grep -vxF HEAD \
    | sort -u \
    | fzf \
      --prompt 'branch> ' \
      --border-label " checkout ticket: $repo " \
      --header '  pick the branch to check out'
  ) || exit 0
  [ -z "$branch" ] && exit 0
fi

exec tmuxinator start checkout "$repo" "$branch"
