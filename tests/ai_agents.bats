#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
    CLAUDE_EXEC=(mise exec node@lts 'npm:@anthropic-ai/claude-code' --)
}

@test "claude code is installed" {
    assert_mise_tool claude
}

@test "codex is installed" {
    mise which codex
}

@test "codex config enables Playwright MCP" {
    assert_file_exists "$HOME/.codex/config.toml"
    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright]'
    assert_file_contains "$HOME/.codex/config.toml" 'command = "npx"'
    assert_file_contains "$HOME/.codex/config.toml" 'args = ["-y", "@playwright/mcp@latest"]'
}

# --- Codex owns its own config too: setmeup must merge, not clobber ---
#
# Codex rewrites ~/.codex/config.toml itself (model, reasoning effort,
# per-project trust) and chmods it to 0600. setmeup must layer its managed
# MCP settings on top without reverting Codex's own writes.

codex_config_backup() {
    CODEX_CONFIG_BACKUP="$(mktemp)"
    CODEX_CONFIG_MODE="$(stat -c '%a' "$HOME/.codex/config.toml")"
    cp "$HOME/.codex/config.toml" "$CODEX_CONFIG_BACKUP"
}

teardown() {
    if [[ -n "${CODEX_CONFIG_BACKUP:-}" ]] && [[ -f "$CODEX_CONFIG_BACKUP" ]]; then
        cp "$CODEX_CONFIG_BACKUP" "$HOME/.codex/config.toml"
        chmod "$CODEX_CONFIG_MODE" "$HOME/.codex/config.toml"
        rm -f "$CODEX_CONFIG_BACKUP"
    fi
}

# Mimic Codex writing back to its own config: top-level keys hoisted to the
# head of the file, a project trust table appended at the tail, mode 0600.
simulate_codex_write() {
    local config="$HOME/.codex/config.toml"
    local tmp
    tmp="$(mktemp)"
    {
        printf 'model = "gpt-5.6-terra"\n'
        printf 'model_reasoning_effort = "high"\n'
        cat "$config"
        printf '\n[projects."/home/testuser/devel/setmeup"]\n'
        printf 'trust_level = "trusted"\n'
    } > "$tmp"
    mv "$tmp" "$config"
    chmod 600 "$config"
}

@test "codex config keeps settings codex wrote itself" {
    codex_config_backup
    simulate_codex_write

    run chezmoi apply "$HOME/.codex/config.toml"
    [ "$status" -eq 0 ]

    assert_file_contains "$HOME/.codex/config.toml" 'model = "gpt-5.6-terra"'
    assert_file_contains "$HOME/.codex/config.toml" 'model_reasoning_effort = "high"'
    assert_file_contains "$HOME/.codex/config.toml" '[projects."/home/testuser/devel/setmeup"]'
    assert_file_contains "$HOME/.codex/config.toml" 'trust_level = "trusted"'
}

@test "codex config still enables Playwright MCP after codex rewrites it" {
    codex_config_backup
    simulate_codex_write

    run chezmoi apply "$HOME/.codex/config.toml"
    [ "$status" -eq 0 ]

    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright]'
    assert_file_contains "$HOME/.codex/config.toml" 'command = "npx"'
    assert_file_contains "$HOME/.codex/config.toml" 'args = ["-y", "@playwright/mcp@latest"]'
}

@test "codex config restores the Playwright MCP block if it goes missing" {
    codex_config_backup
    printf 'model = "gpt-5.6-terra"\n' > "$HOME/.codex/config.toml"
    chmod 600 "$HOME/.codex/config.toml"

    run chezmoi apply "$HOME/.codex/config.toml"
    [ "$status" -eq 0 ]

    assert_file_contains "$HOME/.codex/config.toml" '[mcp_servers.playwright]'
    assert_file_contains "$HOME/.codex/config.toml" 'command = "npx"'
    assert_file_contains "$HOME/.codex/config.toml" 'args = ["-y", "@playwright/mcp@latest"]'
    assert_file_contains "$HOME/.codex/config.toml" 'model = "gpt-5.6-terra"'
}

@test "codex config merge is stable across repeated applies" {
    codex_config_backup
    simulate_codex_write

    chezmoi apply "$HOME/.codex/config.toml"
    local first
    first="$(mktemp)"
    cp "$HOME/.codex/config.toml" "$first"

    chezmoi apply "$HOME/.codex/config.toml"

    run diff "$first" "$HOME/.codex/config.toml"
    rm -f "$first"
    [ "$status" -eq 0 ]
}

@test "codex config does not duplicate the Playwright MCP block" {
    codex_config_backup
    simulate_codex_write

    chezmoi apply "$HOME/.codex/config.toml"
    chezmoi apply "$HOME/.codex/config.toml"

    run grep -cF '[mcp_servers.playwright]' "$HOME/.codex/config.toml"
    [ "$output" = "1" ]
}

@test "codex config is left readable only by the user" {
    codex_config_backup
    simulate_codex_write

    run chezmoi apply "$HOME/.codex/config.toml"
    [ "$status" -eq 0 ]

    run stat -c '%a' "$HOME/.codex/config.toml"
    [ "$status" -eq 0 ]
    [ "$output" = "600" ]
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

# --- Claude Code plugin manifest (source of truth) ---

@test "claude-plugins.list exists in chezmoi source" {
    assert_file_exists "$HOME/.config/setmeup/claude-plugins.list"
}

@test "codex-skills.list exists in chezmoi source" {
    assert_file_exists "$HOME/.config/setmeup/codex-skills.list"
}

# --- Claude marketplaces are registered ---

@test "gianchub marketplace is registered" {
    "${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qi 'gianchub'
}

@test "superpowers marketplace is registered" {
    "${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qi 'superpowers'
}

@test "official anthropic marketplace is registered" {
    "${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qi 'claude-plugins-official'
}

@test "everything-claude-code marketplace is registered" {
    # The affaan-m/everything-claude-code repo registers its marketplace as `ecc`.
    "${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qiE '(ecc|everything-claude-code)'
}

@test "mmcardle-ai-skills marketplace is registered" {
    "${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qi 'mmcardle-ai-skills'
}

# --- Claude plugins are installed (full install, not just skills) ---

@test "blueprints plugin is installed" {
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi 'blueprints'
}

@test "superpowers plugin is installed" {
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi 'superpowers'
}

@test "ecc (everything-claude-code) plugin is installed" {
    # affaan-m renamed both marketplace and plugin from "everything-claude-code" to "ecc".
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qiE '(ecc|everything-claude-code)'
}

@test "code-simplifier plugin is installed" {
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi 'code-simplifier'
}

@test "review-pr-changes plugin is installed" {
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi 'review-pr-changes'
}

@test "visual-qna plugin is installed" {
    "${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi 'visual-qna'
}

# Plugins, unlike skills, also bring commands/agents/hooks. Spot-check
# that the installed plugin tree exposes the broader assets — this is
# precisely the part `npx skills add` was unable to install.

@test "blueprints plugin contributes commands or agents" {
    local plugin_root="$HOME/.claude/plugins/cache/gianchub-plugins/blueprints"
    [ -d "$plugin_root" ]
    # blueprints ships commands and/or agents in its plugin dir
    find "$plugin_root" \( -path '*/commands/*' -o -path '*/agents/*' \) -type f | head -1 | grep -q .
}

# --- Disabling a plugin survives a re-install pass ---
#
# `claude plugin install` re-enables a disabled plugin. Both setmeup-update and
# the onchange installer run an install pass on every update, so without a guard
# a user's decision to disable a plugin is silently undone each time. The shared
# installer helper must skip plugins that are already installed.

@test "claude plugin installer helper exists and is executable" {
    assert_file_exists "$HOME/.local/bin/setmeup-install-claude-plugins.sh"
    [ -x "$HOME/.local/bin/setmeup-install-claude-plugins.sh" ]
}

@test "re-running the plugin installer does not re-enable a disabled plugin" {
    local plugin="visual-qna@mmcardle-ai-skills"
    local list="$HOME/.config/setmeup/claude-plugins.list"

    # Start from a known-enabled state, then disable like a user would.
    "${CLAUDE_EXEC[@]}" claude plugin enable "$plugin" </dev/null >/dev/null 2>&1 || true
    "${CLAUDE_EXEC[@]}" claude plugin disable "$plugin" </dev/null

    # Run the installer the same way setmeup-update / chezmoi onchange do.
    "$HOME/.local/bin/setmeup-install-claude-plugins.sh" "$list"

    # The plugin must remain disabled.
    local json enabled
    json="$("${CLAUDE_EXEC[@]}" claude plugin list --json </dev/null)"
    enabled="$(printf '%s' "$json" | mise exec node@lts -- node -e \
        'const a=JSON.parse(require("fs").readFileSync(0,"utf8"));const p=a.find(x=>x.id==="'"$plugin"'");console.log(p?p.enabled:"missing")')"

    # Restore enabled state so later runs/tests are unaffected.
    "${CLAUDE_EXEC[@]}" claude plugin enable "$plugin" </dev/null >/dev/null 2>&1 || true

    [ "$enabled" = "false" ]
}

# --- Codex-only skills (npx skills) ---

@test "codex skills list does not list claude-code packages" {
    # codex-skills.list is for skills we want exposed to Codex only.
    # Anything intended for Claude Code now goes via claude-plugins.list.
    if [ -s "$HOME/.config/setmeup/codex-skills.list" ]; then
        ! grep -qE '\sclaude-code(\s|$)' "$HOME/.config/setmeup/codex-skills.list" || \
            { echo "codex-skills.list should not specify claude-code agent flag"; return 1; }
    fi
}

@test "codex skills installed for codex (when codex listed)" {
    if ! grep -vE '^\s*(#|$)' "$HOME/.config/setmeup/codex-skills.list" >/dev/null 2>&1; then
        skip "codex-skills.list is empty"
    fi
    local skills_output
    skills_output="$(mise exec node@lts -- npx -y skills list -g 2>&1)"
    # When the list contains gianchub/claude-plugins, blueprints skills should be available.
    if grep -qE '^\s*gianchub/claude-plugins' "$HOME/.config/setmeup/codex-skills.list"; then
        echo "$skills_output" | grep -qi "blueprint"
    fi
}
