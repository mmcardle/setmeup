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
#
# Perf: a single jq invocation reads every flag file, and ANSI stripping
# uses bash parameter expansion — avoids ~80 forks per popup open with a
# busy session list.
set -euo pipefail
shopt -s extglob

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

declare -A live_set=()
if [ -n "$live_panes" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] && live_set["$p"]=1
    done <<<"$live_panes"
fi

declare -A flag_state=()

if [ -d "$STATE_DIR" ]; then
    shopt -s nullglob
    files=("$STATE_DIR"/*.json)
    shopt -u nullglob
    if [ "${#files[@]}" -gt 0 ]; then
        # SOH (\x01) separator — bash's `read` with whitespace IFS (\t)
        # collapses adjacent delimiters and drops empty fields, which shifts
        # everything left when tmux_pane_id is blank. Use a non-whitespace
        # delimiter so empty fields survive.
        while IFS=$'\x01' read -r fname pane state name; do
            [ -z "$fname" ] && continue
            if [ -n "$live_panes" ] && [ -n "$pane" ] && [ -z "${live_set[$pane]:-}" ]; then
                rm -f "$fname"
                continue
            fi
            if [ -n "$state" ] && [ -n "$name" ]; then
                cur="${flag_state[$name]:-}"
                case "$cur:$state" in
                    attention:*) ;;
                    *:attention) flag_state["$name"]="$state" ;;
                    idle:running) ;;
                    *) flag_state["$name"]="$state" ;;
                esac
            fi
        done < <(jq -r 'input_filename as $f | [$f, .tmux_pane_id // "", .state // "", .tmux_session // ""] | join("\u0001")' "${files[@]}" 2>/dev/null || true)
    fi
fi

SYM_RUNNING=$'\033[38;5;46m●\033[0m'
SYM_ATTENTION=$'\033[38;5;196m●\033[0m'
SYM_IDLE=$'\033[38;5;226m●\033[0m'
BG_RUNNING=$'\033[48;5;22m'
BG_ATTENTION=$'\033[48;5;52m'
BG_IDLE=$'\033[48;5;58m'
BG_RESET=$'\033[0m'

while IFS= read -r line; do
    stripped="${line//$'\x1b['*([0-9;])m/}"
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
