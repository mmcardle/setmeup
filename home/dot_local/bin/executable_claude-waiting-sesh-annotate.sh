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

# macOS ships bash 3.2, which has no associative arrays, so sets are kept as
# newline-delimited strings. in_lines <value> <lines> succeeds if value is one
# of the lines.
in_lines() {
    case $'\n'"$2"$'\n' in
        *$'\n'"$1"$'\n'*) return 0 ;;
    esac
    return 1
}

# Session names per state. A session with several flag files shows its most
# urgent state: attention beats idle, idle beats running.
attention_names=""
idle_names=""
running_names=""

if [ -d "$STATE_DIR" ]; then
    shopt -s nullglob
    files=("$STATE_DIR"/*.json)
    shopt -u nullglob
    if [ "${#files[@]}" -gt 0 ]; then
        # Unit separator (\x1f) — bash's `read` with whitespace IFS (\t)
        # collapses adjacent delimiters and drops empty fields, which shifts
        # everything left when tmux_pane_id is blank. Use a non-whitespace
        # delimiter so empty fields survive. Not \x01: bash 3.2 (macOS
        # /bin/bash) uses that byte internally and won't split on it.
        while IFS=$'\x1f' read -r fname pane state name; do
            [ -z "$fname" ] && continue
            if [ -n "$live_panes" ] && [ -n "$pane" ] && ! in_lines "$pane" "$live_panes"; then
                rm -f "$fname"
                continue
            fi
            [ -z "$name" ] && continue
            case "$state" in
                attention) attention_names+="$name"$'\n' ;;
                idle) idle_names+="$name"$'\n' ;;
                running) running_names+="$name"$'\n' ;;
            esac
        done < <(jq -r 'input_filename as $f | [$f, .tmux_pane_id // "", .state // "", .tmux_session // ""] | join("\u001f")' "${files[@]}" 2>/dev/null || true)
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

    if in_lines "$name" "$attention_names"; then
        state=attention
    elif in_lines "$name" "$idle_names"; then
        state=idle
    elif in_lines "$name" "$running_names"; then
        state=running
    else
        state=""
    fi

    field1="$line"
    symbol=""
    case "$state" in
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
