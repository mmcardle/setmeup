#!/usr/bin/env bats
# Tests for the Claude-waiting tmux/sesh indicator stack:
#   - flag writer hook script
#   - status-bar renderer
#   - sesh-list annotator
#   - tmux.conf wiring
#   - sesh-popup.sh wiring
#   - settings.json hook merge

setup() {
    load test_helper
    require_setup

    STATE_DIR="$HOME/.local/state/claude-waiting"
    FLAG_SCRIPT="$HOME/.local/bin/claude-waiting-flag.sh"
    STATUS_SCRIPT="$HOME/.local/bin/claude-waiting-status.sh"
    ANNOTATE_SCRIPT="$HOME/.local/bin/claude-waiting-sesh-annotate.sh"

    rm -rf "$STATE_DIR"
    mkdir -p "$STATE_DIR"
}

# --- Scripts are installed and executable ---

@test "claude-waiting-flag.sh exists" {
    assert_file_exists "$FLAG_SCRIPT"
}

@test "claude-waiting-flag.sh is executable" {
    [ -x "$FLAG_SCRIPT" ]
}

@test "claude-waiting-status.sh exists" {
    assert_file_exists "$STATUS_SCRIPT"
}

@test "claude-waiting-status.sh is executable" {
    [ -x "$STATUS_SCRIPT" ]
}

@test "claude-waiting-sesh-annotate.sh exists" {
    assert_file_exists "$ANNOTATE_SCRIPT"
}

@test "claude-waiting-sesh-annotate.sh is executable" {
    [ -x "$ANNOTATE_SCRIPT" ]
}

# --- Flag writer behaviour ---

@test "flag writer creates JSON flag file with state and session_id" {
    echo '{"session_id":"unit-test-1","cwd":"/tmp"}' | "$FLAG_SCRIPT" running
    [ -f "$STATE_DIR/unit-test-1.json" ]
    run jq -r '.state' "$STATE_DIR/unit-test-1.json"
    [ "$output" = "running" ]
    run jq -r '.session_id' "$STATE_DIR/unit-test-1.json"
    [ "$output" = "unit-test-1" ]
}

@test "flag writer overwrites previous state for same session" {
    echo '{"session_id":"unit-test-2"}' | "$FLAG_SCRIPT" running
    echo '{"session_id":"unit-test-2"}' | "$FLAG_SCRIPT" idle
    run jq -r '.state' "$STATE_DIR/unit-test-2.json"
    [ "$output" = "idle" ]
}

@test "flag writer 'clear' removes the flag file" {
    echo '{"session_id":"unit-test-3"}' | "$FLAG_SCRIPT" idle
    [ -f "$STATE_DIR/unit-test-3.json" ]
    echo '{"session_id":"unit-test-3"}' | "$FLAG_SCRIPT" clear
    [ ! -f "$STATE_DIR/unit-test-3.json" ]
}

# --- Status-bar renderer ---

@test "status renderer is silent when no flags exist" {
    run "$STATUS_SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "status renderer surfaces attention count" {
    cat >"$STATE_DIR/att.json" <<'JSON'
{"state":"attention","tmux_session":"work","tmux_window":"1","tmux_pane_id":""}
JSON
    run "$STATUS_SCRIPT"
    [[ "$output" == *"WAIT 1"* ]]
    [[ "$output" == *"work:1"* ]]
}

@test "status renderer surfaces idle count" {
    cat >"$STATE_DIR/idle.json" <<'JSON'
{"state":"idle","tmux_session":"prj","tmux_window":"2","tmux_pane_id":""}
JSON
    run "$STATUS_SCRIPT"
    [[ "$output" == *"IDLE 1"* ]]
    [[ "$output" == *"prj:2"* ]]
}

@test "status renderer ignores 'running' state (no badge in bar)" {
    cat >"$STATE_DIR/run.json" <<'JSON'
{"state":"running","tmux_session":"work","tmux_window":"1","tmux_pane_id":""}
JSON
    run "$STATUS_SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Sesh annotator ---

@test "annotator emits 3 tab-separated fields per row" {
    printf '\033[34m\033[39m work\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    run awk -F'\t' 'NF != 3 {exit 1}' "$BATS_TEST_TMPDIR/out"
    [ "$status" -eq 0 ]
}

@test "annotator field 2 is the bare session name" {
    printf '\033[34m\033[39m hub_sohonet_com\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    field2=$(awk -F'\t' '{print $2; exit}' "$BATS_TEST_TMPDIR/out")
    [ "$field2" = "hub_sohonet_com" ]
}

@test "annotator marks running with green bullet and green bg" {
    cat >"$STATE_DIR/run.json" <<'JSON'
{"state":"running","tmux_session":"work","tmux_pane_id":""}
JSON
    printf '\033[34m\033[39m work\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[38;5;46m' "$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[48;5;22m' "$BATS_TEST_TMPDIR/out"
}

@test "annotator marks attention with red bullet and red bg" {
    cat >"$STATE_DIR/att.json" <<'JSON'
{"state":"attention","tmux_session":"work","tmux_pane_id":""}
JSON
    printf '\033[34m\033[39m work\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[38;5;196m' "$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[48;5;52m' "$BATS_TEST_TMPDIR/out"
}

@test "annotator marks idle with yellow bullet and olive bg" {
    cat >"$STATE_DIR/idle.json" <<'JSON'
{"state":"idle","tmux_session":"work","tmux_pane_id":""}
JSON
    printf '\033[34m\033[39m work\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[38;5;226m' "$BATS_TEST_TMPDIR/out"
    grep -q $'\033\\[48;5;58m' "$BATS_TEST_TMPDIR/out"
}

@test "annotator leaves non-flagged rows untouched" {
    printf '\033[34m\033[39m work\n' | "$ANNOTATE_SCRIPT" >"$BATS_TEST_TMPDIR/out"
    field3=$(awk -F'\t' '{print $3; exit}' "$BATS_TEST_TMPDIR/out")
    [ -z "$field3" ]
}

# --- Stale-flag pruning ---

@test "reader scripts prune flag whose tmux_pane_id is no longer live" {
    if ! command -v tmux >/dev/null 2>&1; then
        skip "tmux not installed"
    fi
    # Start a fresh tmux server with one known pane.
    tmux -L waiting_test new-session -d -s waiting_test -x 80 -y 24
    real_pane=$(tmux -L waiting_test display-message -t waiting_test -p '#{pane_id}')

    cat >"$STATE_DIR/stale.json" <<'JSON'
{"state":"attention","tmux_session":"ghost","tmux_window":"1","tmux_pane_id":"%999999"}
JSON
    cat >"$STATE_DIR/live.json" <<JSON
{"state":"attention","tmux_session":"waiting_test","tmux_window":"1","tmux_pane_id":"$real_pane"}
JSON

    TMUX_TMPDIR= run env TMUX_SOCKET=waiting_test "$STATUS_SCRIPT"
    tmux -L waiting_test kill-server 2>/dev/null || true

    [[ "$output" != *"ghost"* ]]
    [[ "$output" == *"waiting_test"* ]]
    [ ! -f "$STATE_DIR/stale.json" ]
    [ -f "$STATE_DIR/live.json" ]
}

# --- Tmux config wires status-right ---

@test "tmux.conf references claude-waiting-status.sh" {
    assert_file_contains "$HOME/.tmux.conf" "claude-waiting-status.sh"
}

# --- Sesh popup wires the annotator ---

@test "sesh-popup.sh pipes sesh list through the annotator" {
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "claude-waiting-sesh-annotate.sh"
}

@test "sesh-popup.sh uses tab delimiter and accept-nth=1" {
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "delimiter"
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "accept-nth"
}

@test "sesh-popup.sh preview and kill binds use bare-name field {2}" {
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "sesh preview {2}"
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "kill-session -t {2}"
}

# --- Settings.json hook merge ---

@test "settings.json registers Notification hook" {
    run jq -r '.hooks.Notification[0].hooks[0].command' "$HOME/.claude/settings.json"
    [[ "$output" == *"claude-waiting-flag.sh attention"* ]]
}

@test "settings.json registers Stop hook" {
    run jq -r '.hooks.Stop[0].hooks[0].command' "$HOME/.claude/settings.json"
    [[ "$output" == *"claude-waiting-flag.sh idle"* ]]
}

@test "settings.json registers UserPromptSubmit hook" {
    run jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$HOME/.claude/settings.json"
    [[ "$output" == *"claude-waiting-flag.sh running"* ]]
}

@test "settings.json registers SessionEnd hook" {
    run jq -r '.hooks.SessionEnd[0].hooks[0].command' "$HOME/.claude/settings.json"
    [[ "$output" == *"claude-waiting-flag.sh clear"* ]]
}

@test "configure script does not clobber existing user hooks" {
    # The merge logic must preserve pre-existing hooks the user has set up.
    # setup_environment.sh pre-seeds settings.json with setmeup_test_marker; this
    # asserts our hook keys are added alongside that marker.
    assert_file_contains "$HOME/.claude/settings.json" "setmeup_test_marker"
}
