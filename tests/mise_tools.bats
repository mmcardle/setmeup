#!/usr/bin/env bats

setup_file() {
    # Pass GITHUB_TOKEN to mise to avoid API rate limits
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
    fi
    mise install --yes
}

setup() {
    load test_helper
    require_setup
}

@test "mise tool installed: node" {
    assert_mise_tool node
}

@test "mise tool installed: python" {
    assert_mise_tool python
}

@test "mise tool installed: jq" {
    assert_mise_tool jq
}

@test "mise tool installed: rg" {
    assert_mise_tool rg
}

@test "mise tool installed: fd" {
    assert_mise_tool fd
}

@test "mise tool installed: fzf" {
    assert_mise_tool fzf
}

@test "mise tool installed: uv" {
    assert_mise_tool uv
}

@test "mise tool installed: bat" {
    assert_mise_tool bat
}

@test "mise tool installed: eza" {
    assert_mise_tool eza
}

@test "mise tool installed: lazygit" {
    assert_mise_tool lazygit
}

@test "mise tool installed: gh" {
    assert_mise_tool gh
}

@test "mise tool installed: direnv" {
    assert_mise_tool direnv
}

@test "mise tool installed: claude" {
    assert_mise_tool claude
}

@test "mise tool installed: sesh" {
    assert_mise_tool sesh
}

@test "mise tool installed: zoxide" {
    assert_mise_tool zoxide
}

@test "mise tool installed: delta" {
    assert_mise_tool delta
}
