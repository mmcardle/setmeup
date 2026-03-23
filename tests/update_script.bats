#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

@test "update.sh exists" {
    assert_file_exists "$HOME/setmeup/update.sh"
}

@test "update.sh is executable" {
    [ -x "$HOME/setmeup/update.sh" ]
}

@test "agent-skills.list exists" {
    assert_file_exists "$HOME/.config/setmeup/agent-skills.list"
}

@test "agent-skills.list contains expected skills" {
    assert_file_contains "$HOME/.config/setmeup/agent-skills.list" "obra/superpowers claude-code"
    assert_file_contains "$HOME/.config/setmeup/agent-skills.list" "obra/superpowers codex"
    assert_file_contains "$HOME/.config/setmeup/agent-skills.list" "gianchub/claude-plugins claude-code"
}

@test "update.sh contains mise upgrade" {
    assert_file_contains "$HOME/setmeup/update.sh" "mise upgrade"
}
