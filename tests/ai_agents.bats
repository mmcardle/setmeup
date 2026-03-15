#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

@test "claude code is installed" {
    assert_command_exists claude
}

@test "codex is installed" {
    # codex is installed as npm global under mise's node
    mise exec node@lts -- codex --version
}

@test "npx skills CLI is available" {
    mise exec node@lts -- npx -y skills --version
}
