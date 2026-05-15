#!/usr/bin/env bash
# Renders a tmux status snippet listing Claude sessions awaiting input.
# - Counts 'attention' (needs response) and 'idle' (finished) flags.
# - 'running' flags are tracked elsewhere but intentionally hidden from the
#   status bar; surfacing every active session would be noise.
# - Prunes flag files whose tmux pane no longer exists when a tmux server
#   is reachable (use TMUX_SOCKET to point at a non-default socket; tests
#   rely on this to scope state to a test-only server).
#
# Perf: a single jq invocation reads every flag file at once. The status
# bar redraws every 2s, so per-tick fork count matters.
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

declare -A live_set=()
if [ -n "$live_panes" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] && live_set["$p"]=1
    done <<<"$live_panes"
fi

attention=0
idle=0
attention_targets=()
idle_targets=()

# SOH (\x01) separator — bash's `read` with whitespace IFS (\t) collapses
# adjacent delimiters and drops empty fields, which shifts everything left
# when tmux_pane_id is blank. Use a non-whitespace delimiter.
while IFS=$'\x01' read -r fname pane state session window; do
    [ -z "$fname" ] && continue
    if [ -n "$live_panes" ] && [ -n "$pane" ] && [ -z "${live_set[$pane]:-}" ]; then
        rm -f "$fname"
        continue
    fi
    label="${session:-?}:${window:-?}"
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
done < <(jq -r 'input_filename as $f | [$f, .tmux_pane_id // "", .state // "", .tmux_session // "", .tmux_window // ""] | join("\u0001")' "${files[@]}" 2>/dev/null || true)

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
