#!/usr/bin/env bash
# Reads `sesh list --icons` output on stdin and re-emits each line as a
# tab-delimited record consumable by the sesh-popup fzf invocation:
#
#   <icon+name>\t<bare-name>\t<symbol>
#
# Field 1 — displayed by fzf (--with-nth=1,3) and returned on Enter
#           (--accept-nth=1). For flagged sessions, wrapped with a darker
#           tint of the state colour as background so the row reads as a badge.
# Field 2 — bare session name; used by preview / kill binds via {2}.
# Field 3 — solid coloured ● for the state; blank for non-flagged.
#
# State -> colours
#   running   : symbol bright green (46), name bg dark forest (22)
#   attention : symbol bright red   (196), name bg dark wine   (52)
#   idle      : symbol bright yellow (226), name bg dark olive  (58)
#
# Also prunes flag files whose tmux pane no longer exists when a tmux
# server is reachable. --ansi is required on the fzf side.
set -euo pipefail

STATE_DIR="${HOME}/.local/state/claude-waiting"

tmux_cmd=()
if command -v tmux >/dev/null 2>&1; then
    if [ -n "${TMUX_SOCKET:-}" ]; then
        tmux_cmd=(tmux -L "$TMUX_SOCKET")
    else
        tmux_cmd=(tmux)
    fi
fi

live_panes=""
if [ "${#tmux_cmd[@]}" -gt 0 ]; then
    live_panes=$("${tmux_cmd[@]}" list-panes -a -F '#{pane_id}' 2>/dev/null || true)
fi

is_stale() {
    local pane="$1"
    [ -z "$pane" ] && return 1
    [ -z "$live_panes" ] && return 1
    if printf '%s\n' "$live_panes" | grep -qFx "$pane"; then
        return 1
    fi
    return 0
}

declare -A flag_state=()
if [ -d "$STATE_DIR" ]; then
    shopt -s nullglob
    for f in "$STATE_DIR"/*.json; do
        pane=$(jq -r '.tmux_pane_id // empty' "$f" 2>/dev/null || echo "")
        if is_stale "$pane"; then
            rm -f "$f"
            continue
        fi
        state=$(jq -r '.state // empty' "$f" 2>/dev/null || echo "")
        name=$(jq -r '.tmux_session // empty' "$f" 2>/dev/null || echo "")
        if [ -n "$state" ] && [ -n "$name" ]; then
            cur="${flag_state[$name]:-}"
            case "$cur:$state" in
                attention:*) ;;
                *:attention) flag_state["$name"]="$state" ;;
                idle:running) ;;
                *) flag_state["$name"]="$state" ;;
            esac
        fi
    done
fi

strip_ansi() {
    printf '%s' "$1" | sed -E $'s/\x1B\\[[0-9;]*m//g'
}

SYM_RUNNING=$'\033[38;5;46m●\033[0m'
SYM_ATTENTION=$'\033[38;5;196m●\033[0m'
SYM_IDLE=$'\033[38;5;226m●\033[0m'
BG_RUNNING=$'\033[48;5;22m'
BG_ATTENTION=$'\033[48;5;52m'
BG_IDLE=$'\033[48;5;58m'
BG_RESET=$'\033[0m'

while IFS= read -r line; do
    stripped=$(strip_ansi "$line")
    name="${stripped#* }"

    field1="$line"
    symbol=""
    case "${flag_state[$name]:-}" in
        running)
            field1="${BG_RUNNING}${line}${BG_RESET}"
            symbol="$SYM_RUNNING"
            ;;
        attention)
            field1="${BG_ATTENTION}${line}${BG_RESET}"
            symbol="$SYM_ATTENTION"
            ;;
        idle)
            field1="${BG_IDLE}${line}${BG_RESET}"
            symbol="$SYM_IDLE"
            ;;
    esac
    printf '%s\t%s\t%s\n' "$field1" "$name" "$symbol"
done
