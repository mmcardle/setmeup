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

@test "claude-plugins.list exists" {
    assert_file_exists "$HOME/.config/setmeup/claude-plugins.list"
}

@test "claude-plugins.list contains expected plugin@marketplace entries" {
    assert_file_contains "$HOME/.config/setmeup/claude-plugins.list" "blueprints@gianchub-plugins"
    assert_file_contains "$HOME/.config/setmeup/claude-plugins.list" "superpowers@superpowers-marketplace"
}

@test "codex-skills.list exists" {
    assert_file_exists "$HOME/.config/setmeup/codex-skills.list"
}

@test "codex-skills.list contains expected packages" {
    assert_file_contains "$HOME/.config/setmeup/codex-skills.list" "obra/superpowers"
    assert_file_contains "$HOME/.config/setmeup/codex-skills.list" "gianchub/claude-plugins"
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

@test "update.sh removes legacy Pi package before refreshing tools" {
    local fake_bin="$BATS_TEST_TMPDIR/fake-bin"
    local test_home="$BATS_TEST_TMPDIR/home"
    local mise_log="$BATS_TEST_TMPDIR/mise.log"

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
printf '%s\n' "$*" >> "$MISE_LOG"
exit 0
EOF
    chmod +x "$fake_bin/mise"

    cp "$HOME/setmeup/bootstrap.sh" "$test_home/setmeup/bootstrap.sh"
    cp "$HOME/setmeup/update.sh" "$test_home/setmeup/update.sh"

    run env HOME="$test_home" PATH="$fake_bin:$PATH" MISE_LOG="$mise_log" sh "$test_home/setmeup/update.sh"
    [ "$status" -eq 0 ]
    grep -qF "uninstall --yes npm:@mariozechner/pi-coding-agent" "$mise_log"
    grep -qF "exec node@lts -- npm uninstall -g @mariozechner/pi-coding-agent" "$mise_log"
    grep -qF "reshim" "$mise_log"
}

@test "update.sh installs Claude plugins via the shared installer helper" {
    assert_file_contains "$HOME/setmeup/update.sh" "claude-plugins.list"
    assert_file_contains "$HOME/setmeup/update.sh" "setmeup-install-claude-plugins.sh"
}

@test "installer helper drives the native plugin CLI" {
    assert_file_contains "$HOME/.local/bin/setmeup-install-claude-plugins.sh" "claude plugin install"
    assert_file_contains "$HOME/.local/bin/setmeup-install-claude-plugins.sh" "claude plugin marketplace add"
}

@test "installer helper skips already-installed plugins" {
    # The guard against re-enabling disabled plugins: query installed ids and skip them.
    assert_file_contains "$HOME/.local/bin/setmeup-install-claude-plugins.sh" "claude plugin list --json"
}

@test "update.sh repairs mise-installed Claude Code native binary before plugin install" {
    assert_file_contains "$HOME/setmeup/update.sh" "install.cjs"
    assert_file_contains "$HOME/setmeup/update.sh" "claude --version"
}

@test "update.sh locates Claude Code through mise, not PATH" {
    assert_file_contains "$HOME/setmeup/update.sh" "mise which claude"
    run grep -F "command -v claude" "$HOME/setmeup/update.sh"
    [ "$status" -ne 0 ]
}

@test "update.sh installs Codex skills via npx skills" {
    assert_file_contains "$HOME/setmeup/update.sh" "codex-skills.list"
    assert_file_contains "$HOME/setmeup/update.sh" "skills add"
}

@test "setmeup configures Playwright MCP for Claude and Codex" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_always_005-configure-claude-code.sh.tmpl" "@playwright/mcp@latest"
    assert_file_contains "$HOME/setmeup/home/dot_codex/config.toml" "@playwright/mcp@latest"
}
