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

@test "update.sh prints the bootstrap banner" {
    local fake_bin="$BATS_TEST_TMPDIR/fake-bin"
    local test_home="$BATS_TEST_TMPDIR/home"

    mkdir -p "$fake_bin" "$test_home/setmeup" "$test_home/.local/state/setmeup"

    cat > "$fake_bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "source-path" ]]; then
    printf '%s\n' "$HOME/setmeup/home"
    exit 0
fi
exit 0
EOF
    chmod +x "$fake_bin/chezmoi"

    cat > "$fake_bin/mise" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$fake_bin/mise"

    cp "$HOME/setmeup/bootstrap.sh" "$test_home/setmeup/bootstrap.sh"
    cp "$HOME/setmeup/update.sh" "$test_home/setmeup/update.sh"

    run env HOME="$test_home" PATH="$fake_bin:$PATH" sh "$test_home/setmeup/update.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"setmeup: bootstrap your dev machine"* ]]
}
