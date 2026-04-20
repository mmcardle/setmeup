# Sesh Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a managed `~/.config/sesh/sesh.toml` file to `setmeup` with the shared sesh sessions and preview settings.

**Architecture:** Keep the change static and minimal by adding a plain chezmoi-managed file at `home/dot_config/sesh/sesh.toml`. Extend `tests/dotfiles.bats` to verify the file is installed and contains the shared preview/session entries.

**Tech Stack:** Chezmoi, TOML, BATS, Make

---

### Task 1: Add Failing Dotfile Tests

**Files:**
- Modify: `tests/dotfiles.bats`
- Test: `tests/dotfiles.bats`

- [ ] **Step 1: Write the failing test**

```bash
@test "managed dotfile exists: .config/sesh/sesh.toml" {
    assert_file_exists "$HOME/.config/sesh/sesh.toml"
}

@test "sesh.toml configures default preview command" {
    assert_file_contains "$HOME/.config/sesh/sesh.toml" 'preview_command = "eza --all --git --icons --color=always {}"'
}

@test "sesh.toml includes shared config sessions" {
    assert_file_contains "$HOME/.config/sesh/sesh.toml" 'name = "zsh config"'
    assert_file_contains "$HOME/.config/sesh/sesh.toml" 'name = "tmux config"'
    assert_file_contains "$HOME/.config/sesh/sesh.toml" 'name = "sesh config"'
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-file FILE=dotfiles.bats`
Expected: FAIL because `~/.config/sesh/sesh.toml` is not yet managed.

- [ ] **Step 3: Write minimal implementation**

```toml
#:schema https://github.com/joshmedeski/sesh/raw/main/sesh.schema.json

[default_session]
#startup_command = "Echo Hello Mark"
preview_command = "eza --all --git --icons --color=always {}"

[[session]]
name = "zsh config"
path = "~"
startup_command = "nvim .zshrc"
preview_command = "bat --color=always ~/.zshrc"

[[session]]
name = "tmux config"
path = "~"
startup_command = "nvim .tmux.conf"
preview_command = "bat --color=always ~/.tmux.conf"

[[session]]
name = "sesh config"
path = "~/.config/sesh/"
startup_command = "nvim sesh.toml"
preview_command = "bat --color=always ~/.config/sesh/sesh.toml"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-file FILE=dotfiles.bats`
Expected: PASS for the new sesh config assertions.

- [ ] **Step 5: Commit**

```bash
git add tests/dotfiles.bats home/dot_config/sesh/sesh.toml docs/superpowers/specs/2026-04-20-sesh-config-design.md docs/superpowers/plans/2026-04-20-sesh-config.md
git commit -m "add managed sesh config"
```
