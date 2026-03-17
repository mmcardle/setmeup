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

@test "update.sh contains skills refresh" {
    assert_file_contains "$HOME/setmeup/update.sh" "skills"
}

@test "update.sh contains mise upgrade" {
    assert_file_contains "$HOME/setmeup/update.sh" "mise upgrade"
}
