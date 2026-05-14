#!/usr/bin/env bash
# Renders a tmux status snippet listing Claude sessions awaiting input.
# - Counts 'attention' (needs response) and 'idle' (finished) flags.
# - 'running' flags are tracked elsewhere but intentionally hidden from the
#   status bar; surfacing every active session would be noise.
# - Prunes flag files whose tmux pane no longer exists when a tmux server
#   is reachable (use TMUX_SOCKET to point at a non-default socket; tests
#   rely on this to scope state to a test-only server).
set -euo pipefail

STATE_DIR="${HOME}/.local/state/claude-waiting"
[ -d "$STATE_DIR" ] || exit 0

shopt -s nullglob
files=("$STATE_DIR"/*.json)
[ "${#files[@]}" -gt 0 ] || exit 0

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

attention=0
idle=0
attention_targets=()
idle_targets=()

for f in "${files[@]}"; do
    pane=$(jq -r '.tmux_pane_id // empty' "$f" 2>/dev/null || echo "")
    if is_stale "$pane"; then
        rm -f "$f"
        continue
    fi
    state=$(jq -r '.state // empty' "$f" 2>/dev/null || echo "")
    label=$(jq -r '(.tmux_session // "?") + ":" + (.tmux_window // "?")' "$f" 2>/dev/null || echo "?")
    case "$state" in
        attention)
            attention=$((attention + 1))
            attention_targets+=("$label")
            ;;
        idle)
            idle=$((idle + 1))
            idle_targets+=("$label")
            ;;
    esac
done

[ "$attention" -eq 0 ] && [ "$idle" -eq 0 ] && exit 0

out=""
if [ "$attention" -gt 0 ]; then
    targets=$(IFS=','; echo "${attention_targets[*]}")
    out+="#[fg=colour231,bg=colour160,bold] WAIT ${attention} (${targets}) #[default] "
fi
if [ "$idle" -gt 0 ]; then
    targets=$(IFS=','; echo "${idle_targets[*]}")
    out+="#[fg=colour16,bg=colour220] IDLE ${idle} (${targets}) #[default] "
fi

printf '%s' "$out"
