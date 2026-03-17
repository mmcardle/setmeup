#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

@test "claude code is installed" {
    assert_mise_tool claude
}

@test "codex is installed" {
    mise which codex
}

@test "npx skills CLI is available" {
    mise exec node@lts -- npx -y skills --version
}
