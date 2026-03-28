#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

# --- Statusline script ---

@test "claude statusline-command.sh exists" {
    assert_file_exists "$HOME/.claude/statusline-command.sh"
}

@test "claude statusline-command.sh contains model display" {
    assert_file_contains "$HOME/.claude/statusline-command.sh" "model"
}

@test "claude statusline-command.sh contains context window" {
    assert_file_contains "$HOME/.claude/statusline-command.sh" "context_window"
}

# --- Settings.json statusLine config ---

@test "claude settings.json exists" {
    assert_file_exists "$HOME/.claude/settings.json"
}

@test "claude settings.json contains statusLine type" {
    assert_file_contains "$HOME/.claude/settings.json" '"type": "command"'
}

@test "claude settings.json contains statusLine command" {
    assert_file_contains "$HOME/.claude/settings.json" 'statusline-command.sh'
}

@test "claude settings.json contains Read skills permission" {
    run jq -r '.permissions.allow[]' "$HOME/.claude/settings.json"
    [[ "$output" == *"Read(~/.claude/skills/*)"* ]]
}

@test "claude settings.json preserves existing keys" {
    # The configure-claude-code script should preserve keys that were already in settings.json
    # setup_environment.sh pre-seeds a test key before chezmoi apply
    assert_file_contains "$HOME/.claude/settings.json" '"setmeup_test_marker"'
}
