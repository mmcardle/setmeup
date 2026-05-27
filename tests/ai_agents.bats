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
