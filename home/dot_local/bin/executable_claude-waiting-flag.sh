#!/usr/bin/env bash
# Hook callback that records a Claude session's state in ~/.local/state/claude-waiting/.
# Used by tmux status-right and the sesh popup to surface which Claudes are
# waiting on the user.
#
# Usage:  claude-waiting-flag.sh <running|attention|idle|clear>
# Stdin:  JSON payload from Claude Code hook (session_id, cwd, ...).
set -euo pipefail

STATE_DIR="${HOME}/.local/state/claude-waiting"
mkdir -p "$STATE_DIR"

state="${1:-clear}"

input=""
if [ ! -t 0 ]; then
    input="$(cat)"
fi

session_id=""
cwd=""
if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
    cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null || true)
fi
[ -n "$session_id" ] || session_id="${TMUX_PANE:-unknown}-$$"

flag="${STATE_DIR}/${session_id}.json"

if [ "$state" = "clear" ]; then
    rm -f "$flag"
    exit 0
fi

tmux_session=""
tmux_window=""
tmux_pane_id="${TMUX_PANE:-}"
if [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
    info=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}|#{window_index}|#{pane_id}' 2>/dev/null || true)
    if [ -n "$info" ]; then
        IFS='|' read -r tmux_session tmux_window tmux_pane_id <<<"$info"
    fi
fi

tmp="${flag}.tmp.$$"
jq -n \
    --arg session_id "$session_id" \
    --arg state "$state" \
    --arg cwd "$cwd" \
    --arg tmux_session "$tmux_session" \
    --arg tmux_window "$tmux_window" \
    --arg tmux_pane_id "$tmux_pane_id" \
    --arg since "$(date -Is)" \
    '{session_id:$session_id, state:$state, cwd:$cwd, tmux_session:$tmux_session, tmux_window:$tmux_window, tmux_pane_id:$tmux_pane_id, since:$since}' \
    >"$tmp"
mv -f "$tmp" "$flag"
