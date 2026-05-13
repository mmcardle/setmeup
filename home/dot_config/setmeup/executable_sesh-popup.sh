#!/usr/bin/env bash
# Tmux server caches the PATH at start, so mise upgrades that move tool
# install dirs leave bindings pointing at deleted paths. The shims dir is
# stable across upgrades — prepend it so sesh and fzf always resolve.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$PATH"

ANNOTATE="$HOME/.local/bin/claude-waiting-sesh-annotate.sh"
# Wrap fd output in the same 3-field layout so preview/kill binds stay uniform.
FD_FMT='awk -v OFS="\t" "{print \$0, \$0, \"\"}"'

choice=$(
  sesh list --icons | "$ANNOTATE" | fzf --tmux 80%,70% \
    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --delimiter $'\t' --with-nth='1,3' --accept-nth='1' \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
    --bind 'tab:down,btab:up' \
    --bind "ctrl-a:change-prompt(⚡  )+reload(sesh list --icons | \"$ANNOTATE\")" \
    --bind "ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons | \"$ANNOTATE\")" \
    --bind "ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons | \"$ANNOTATE\")" \
    --bind "ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons | \"$ANNOTATE\")" \
    --bind "ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~ | $FD_FMT)" \
    --bind "ctrl-d:execute(tmux kill-session -t {2})+change-prompt(⚡  )+reload(sesh list --icons | \"$ANNOTATE\")" \
    --preview-window 'right:55%' \
    --preview 'sesh preview {2}'
) || exit 0

[ -n "$choice" ] && exec sesh connect "$choice"
