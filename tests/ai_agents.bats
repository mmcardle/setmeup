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

@test "opencode is installed" {
    mise which opencode
}

@test "pi coding agent uses current npm package" {
    assert_file_contains "$HOME/.config/mise/config.toml" '"npm:@earendil-works/pi-coding-agent" = "latest"'
}

@test "pi coding agent is installed" {
    mise which pi
}

@test "npx skills CLI is available" {
    mise exec node@lts -- npx -y skills --version
}

@test "gianchub/claude-plugins skills are installed" {
    local skills_output
    skills_output="$(mise exec node@lts -- npx -y skills list -g 2>&1)"
    echo "$skills_output" | grep -qi "blueprint"
    echo "$skills_output" | grep -qi "audit"
}

@test "mmcardle/ai-skills skills are installed" {
    local skills_output
    skills_output="$(mise exec node@lts -- npx -y skills list -g 2>&1)"
    echo "$skills_output" | grep -qi "review-pr-changes"
}
