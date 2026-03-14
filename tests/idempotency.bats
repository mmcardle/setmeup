#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

@test "chezmoi apply is idempotent" {
    run chezmoi apply --source="$HOME/setmeup/home"
    [ "$status" -eq 0 ]
}
