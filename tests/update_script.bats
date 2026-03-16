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
