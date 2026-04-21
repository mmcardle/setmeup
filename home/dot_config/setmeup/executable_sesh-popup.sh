#!/usr/bin/env bash
# Tmux server caches the PATH at start, so mise upgrades that move tool
# install dirs leave bindings pointing at deleted paths. The shims dir is
# stable across upgrades — prepend it so sesh and fzf always resolve.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$PATH"

# Enumerate main repos under ~/devel (dirs with a real .git directory;
# worktrees have .git as a file pointing back to the parent, so they're skipped).
list_devel_repos() {
  local d
  for d in "$HOME"/devel/*/.git; do
    [ -d "$d" ] || continue
    basename "$(dirname "$d")"
  done
}

result=$(
  sesh list --icons | fzf --tmux 80%,70% \
    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --print-query --expect=ctrl-n \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find ^n new-ticket' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
    --preview-window 'right:55%' \
    --preview 'sesh preview {}'
) || exit 0

query=$(printf '%s\n' "$result" | sed -n '1p')
key=$(printf   '%s\n' "$result" | sed -n '2p')
choice=$(printf '%s\n' "$result" | sed -n '3p')

if [ "$key" = "ctrl-n" ]; then
    ticket="$query"
    [ -z "$ticket" ] && exit 0

    repo=$(
      list_devel_repos | fzf --tmux 80%,50% \
        --prompt 'repo> ' \
        --border-label " new ticket: $ticket " \
        --header '  pick the source repo'
    ) || exit 0
    [ -z "$repo" ] && exit 0

    exec tmuxinator start default "$repo" "$ticket"
fi

[ -n "$choice" ] && exec sesh connect "$choice"
