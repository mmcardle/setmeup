# Adding Features to setmeup

This guide walks through adding a new feature using test-driven development (TDD).

## TDD Workflow

Every feature follows this cycle:

1. **Write a failing test** in the appropriate `.bats` file under `tests/`
2. **Run the test** to confirm it fails
3. **Implement the feature** in the appropriate file
4. **Run the test** to confirm it passes

Never write implementation code before the test exists.

## Running Tests

```sh
# Fast local smoke suite
make test

# Clean full integration suite (fresh rebuild)
make test-full

# Single test file
make test-file FILE=dotfiles.bats

# Tests matching a pattern
make test-filter FILTER="aliases"

# Alias for the fast local smoke suite
make test

# Rebuild the prepared fast image after setup-affecting changes
make test-rebuild

# Remove this worktree's scoped test images and cache
make test-clean

# Remove all scoped setmeup test images on this host
make test-clean-all

# Interactive shell for fastest TDD loop
make shell
# Inside container:
bats ~/tests/dotfiles.bats                     # run one file
bats --filter "aliases" ~/tests/*.bats          # run one test
```

Docker test images are isolated per worktree. `make test` and `make shell` reuse a prepared Docker image with setup already baked in only within the current worktree. Use `make test-full` when you need the clean-machine rebuild path, `make test-rebuild` after changing `bootstrap.sh`, `home/`, or other setup inputs that should invalidate the prepared image, and the cleanup targets when you want to remove stale scoped images. The first run in a worktree will build a new scoped image.

## Step-by-Step Example: Adding a New Dotfile

Suppose you want to manage `~/.editorconfig`.

### 1. Write the failing test

Add assertions to `tests/dotfiles.bats`:

```bash
@test "managed dotfile exists: .editorconfig" {
    assert_file_exists "$HOME/.editorconfig"
}

@test ".editorconfig has root = true" {
    assert_file_contains "$HOME/.editorconfig" "root = true"
}
```

### 2. Run the test, see the failure

```sh
make test-file FILE=dotfiles.bats
```

You should see:

```
not ok - managed dotfile exists: .editorconfig
```

### 3. Implement

Create the dotfile in `home/` using chezmoi naming conventions:

- `home/dot_editorconfig` -- plain file, becomes `~/.editorconfig`
- `home/dot_editorconfig.tmpl` -- if you need OS-conditional logic or chezmoi variables

```ini
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
insert_final_newline = true
```

### 4. Run the test, see it pass

```sh
make test-file FILE=dotfiles.bats
```

## Common Feature Types

### Adding a new managed dotfile

1. Test: add `@test` blocks using `assert_file_exists` and `assert_file_contains` in `tests/dotfiles.bats`
2. Implement: create `home/dot_<name>` (or `home/dot_<name>.tmpl` for templates)

### Adding a tmux plugin

1. Test: add `assert_file_contains "$HOME/.tmux.conf" "<author>/<plugin>"` and `assert_dir_exists "$HOME/.tmux/plugins/<plugin>"` in `tests/dotfiles.bats`
2. Implement:
   - Add `set -g @plugin '<author>/<plugin>'` to `home/dot_tmux.conf` (before the TPM `run` line)
   - Add the plugin as a chezmoi external in `home/.chezmoiexternal.toml` (plugins are installed declaratively via chezmoi, not via TPM's runtime installer, because chezmoi scripts run before externals are downloaded)

### Adding a Claude Code plugin

1. Test: in `tests/ai_agents.bats`, add a `<marketplace> marketplace is registered` test (`"${CLAUDE_EXEC[@]}" claude plugin marketplace list 2>&1 | grep -qi '<marketplace>'`) and a `<plugin> plugin is installed` test (`"${CLAUDE_EXEC[@]}" claude plugin list 2>&1 | grep -qi '<plugin>'`)
2. Implement: add a line `<plugin>@<marketplace>  <marketplace_source>` to `home/dot_config/setmeup/claude-plugins.list`. Find `<marketplace>` (the registered name) and `<plugin>` in the source repo's `.claude-plugin/marketplace.json`; `<marketplace_source>` is the GitHub `owner/name`, URL, or path handed to `claude plugin marketplace add`.
3. Re-run requires rebuilding the prepared test image (`make test-rebuild`) because `run_after_onchange_004-install-agent-skills.sh.tmpl` only re-runs the installer when the list's hash changes.

> **Installation is delegated to a shared helper.** Both the onchange script and `update.sh` call `~/.local/bin/setmeup-install-claude-plugins.sh <plugins-list>` (source: `home/dot_local/bin/executable_setmeup-install-claude-plugins.sh`). The helper registers each marketplace, then installs **only plugins that are not already installed** — it queries `claude plugin list --json` and skips ids it finds there. This is deliberate: `claude plugin install` re-enables a disabled plugin, so a plain re-install pass would silently undo a user's choice to disable a plugin. Skipping already-installed plugins preserves enabled/disabled state across every update. If you change the helper, the onchange script re-runs because the script includes the helper's hash in its trigger comments. The behavior is covered by the `re-running the plugin installer does not re-enable a disabled plugin` test in `tests/ai_agents.bats`.
4. Codex-only skills go in `codex-skills.list` instead (installed via `npx skills add -a codex`). A repo can appear in both lists — `claude-plugins.list` gives Claude the full plugin (commands/agents/hooks/MCP + skills), `codex-skills.list` gives Codex the skill files.

### Adding a tmux key binding

1. Test: add `assert_file_contains "$HOME/.tmux.conf" "bind-key \"<key>\" <command>"` in `tests/dotfiles.bats` near the other `tmux.conf binds <k>` tests
2. Implement: add the binding to `home/dot_tmux.conf` under an appropriate `# --- <section> ---` heading. If the key has a default tmux binding you want to displace, precede it with `unbind-key -T prefix <key>`. For a self-dismissing shell popup the idiom is `bind-key "o" display-popup -E -w 80% -h 80%` — the `-E` flag closes the popup when the command (default `$SHELL`) exits.

### Adding a new shell alias

1. Test: `assert_file_contains "$HOME/.aliases" "alias myalias="` in `tests/dotfiles.bats`
2. Implement: add the alias to `home/dot_aliases`

### Adding a section to shell configs (bashrc/zshrc)

1. Test: add `@test` blocks using `assert_file_contains` for both `$HOME/.config/setmeup/bashrc` and `$HOME/.config/setmeup/zshrc` in `tests/dotfiles.bats`
2. Implement: add the section to both `home/dot_config/setmeup/bashrc.tmpl` and `home/dot_config/setmeup/zshrc.tmpl`, using the established `# ---` separator pattern. Place it in the correct position relative to other sections (e.g. SSH Agent goes before Mise so SSH is available for git-over-SSH operations).

### Adding a zsh directory-change (chpwd) hook

For behaviour that should run on every `cd` (e.g. auto-`ls`, auto-sourcing a
Python venv), use zsh's native `chpwd` hook mechanism — zsh-only, so it lives in
`zshrc.tmpl` and not `bashrc.tmpl`.

1. Test: add `assert_file_contains` blocks in `tests/dotfiles.bats` asserting the
   registration (`add-zsh-hook chpwd <fn>`) and the hook's key behaviour strings
2. Implement: in `home/dot_config/setmeup/zshrc.tmpl`, `autoload -Uz add-zsh-hook`
   once, define a `_setmeup_chpwd_<name>` function, then register it with
   `add-zsh-hook chpwd _setmeup_chpwd_<name>`
3. Keep hooks idempotent and non-destructive — e.g. the venv hook only
   deactivates venvs it activated (tracked via `_SETMEUP_VENV_ROOT`) and only
   activates when `$VIRTUAL_ENV` is empty, so manual venvs are never disturbed

### Adding a new mise tool

1. Test: `assert_mise_tool <tool>` in `tests/mise_tools.bats`
2. Implement: add `<tool> = "latest"` to `home/dot_config/mise/config.toml`
3. If mise doesn't find the tool in its default registry, use the aqua backend: `"aqua:<owner>/<repo>" = "latest"` (mise will suggest this in its error output)
4. If the tool isn't in the mise registry at all — e.g. a traditional C program with no prebuilt release like `socat` (`mise registry | grep <tool>` returns nothing) — it isn't mise-installable. Add it as a system package instead (see below).

### Adding a new system package

1. Test: `assert_command_exists <package>` in the appropriate `.bats` file
2. Implement: add the package to the appropriate list in `home/.chezmoiscripts/run_onchange_001-install-packages.sh.tmpl`

### Testing runtime behaviour of a config file

`assert_file_contains` only verifies the words in a config file, not that those words *work*. When a dotfile encodes a runtime contract with another tool (e.g. tmuxinator's `pre_window` calling `wt list`), also add a test that executes the contract in a scratch repo under `$BATS_TEST_TMPDIR` and asserts the real outcome. The `tmuxinator pre_window resolves to the worktree that wt actually created` test in `dotfiles.bats` is the reference pattern: it creates a git repo, lets `wt` materialise a worktree, then evals the `pre_window` expression and compares the resolved path to what `git worktree list` reports. Remember to `export PATH="$HOME/.local/share/mise/shims:$PATH"` in such tests — bats subshells don't inherit `mise activate`.

### Adding a new chezmoi script

Scripts live in `home/.chezmoiscripts/` and use a **numeric prefix** for execution order:

```
run_onchange_001-install-packages.sh.tmpl      # system packages (apt/brew)
run_onchange_002-macos-defaults.sh.tmpl        # macOS defaults
run_onchange_003-install-mise-tools.sh.tmpl    # mise tool installs
run_onchange_004-install-agent-skills.sh.tmpl  # Claude Code plugins (claude plugin install) + Codex skills (npx skills); re-runs when lists or mise config change
run_always_005-configure-claude-code.sh.tmpl   # Claude Code settings (statusLine + permissions + hooks merge)
run_always_006-rebuild-font-cache.sh.tmpl      # fontconfig rebuild after font install
```

When adding a new script, pick the next number (e.g. `007`). To insert between existing scripts, use a number in the gap (e.g. `003` and `004` have room for `0035` if needed, but generally append).

All scripts use `run_onchange_` with a self-referencing hash so they re-run when their content changes:

```bash
#!/bin/bash
# hash: {{ include ".chezmoiscripts/run_onchange_006-my-script.sh.tmpl" | sha256sum }}
set -e
# ... your script here
```

#### Scripts that need mise tools (node, python, etc.)

Chezmoi applies entries alphabetically by target path. `.chezmoiscripts/` sorts before `.config/`, so **all scripts run before `~/.config/mise/config.toml` is written**. This means:

- `mise install --yes` finds no config and installs nothing
- `mise exec -- npm ...` (without a version) fails because mise doesn't know which tool version to use

**Use `mise exec <tool>@<version> --` with an explicit version** — this auto-installs the tool if missing, no config file needed:

```bash
#!/bin/bash
# hash: {{ include ".chezmoiscripts/run_onchange_006-my-script.sh.tmpl" | sha256sum }}
set -e
export PATH="$HOME/.local/bin:$PATH"
mise exec node@lts -- npm i -g some-package
```

Mise is installed by `bootstrap.sh` before chezmoi runs, so it will always be available. Don't add defensive guards — let `set -e` catch failures loudly.

#### Other gotchas

- Use `#!/bin/bash` not `#!/bin/sh` if the script uses `mise activate bash` — its output contains bash-specific syntax (`[[`, `export -a`)
- In tests, use `mise exec node@lts -- <command>` instead of expecting npm globals on PATH directly

#### Debugging chezmoi scripts

If a script fails during `docker build`, don't repeatedly rebuild the full image. Build a debug image that stops before `chezmoi apply` and explore interactively:

```sh
# Build without running setup_environment.sh (copy Dockerfile up to COPY steps, skip RUN setup_environment.sh)
docker build -f - -t setmeup-debug . <<'DOCKERFILE'
FROM ubuntu:24.04
# ... (same as tests/Dockerfile up to the COPY steps, omit RUN setup_environment.sh and beyond)
DOCKERFILE

# Explore
docker run --rm setmeup-debug bash -c 'chezmoi managed --source=$HOME/setmeup/home'
docker run --rm setmeup-debug bash -c 'mise exec node@lts -- node --version'
```

### Adding a helper script under `~/.local/bin/`

For small executables Claude Code, tmux, or other tools call as commands (hook callbacks, status renderers, sesh annotators), drop them in `home/dot_local/bin/` using chezmoi's `executable_` prefix:

```
home/dot_local/bin/executable_my-helper.sh   →   ~/.local/bin/my-helper.sh   (chmod +x on apply)
```

The source file in the repo does **not** need its execute bit set — `executable_` handles that at apply time. Add tests that assert both existence and `-x`:

```bash
@test "my-helper.sh exists" {
    assert_file_exists "$HOME/.local/bin/my-helper.sh"
}

@test "my-helper.sh is executable" {
    [ -x "$HOME/.local/bin/my-helper.sh" ]
}
```

### Adding a Claude Code hook

Hooks in `~/.claude/settings.json` are merged by `home/.chezmoiscripts/run_always_005-configure-claude-code.sh.tmpl` so re-running `chezmoi apply` converges to the same state without clobbering user keys.

1. **Test**: assert the merged command in `tests/claude_waiting.bats` (or a sibling bats file):
   ```bash
   run jq -r '.hooks.<EventName>[0].hooks[0].command' "$HOME/.claude/settings.json"
   [[ "$output" == *"my-callback.sh"* ]]
   ```
2. **Implement**: add the event to the `for event in …` loop in the configure script and define the command in the `HOOKS_JSON` heredoc next to the existing entries. Keep callbacks under `~/.local/bin/` (see above).
3. **Idempotency**: the configure script uses `jq` to set exactly the setmeup-managed entries on each apply. If users want extra hooks alongside these, they can append to the array manually — but be aware that the setmeup entry is the source of truth on every apply.

### Adding a new BATS test file

When you create a brand-new `tests/<name>.bats` (rather than adding to an existing file), three places must be kept in sync or the prepared image will silently run stale content (or skip the file entirely):

1. **`tests/Dockerfile`**, `FROM prepared-setup AS prepared` block — add a `COPY` line for the new bats file and add it to the trailing `CMD` invocation.
2. **`tests/run_tests.sh`**, `FAST_BATS_FILES` — append `$HOME/tests/<name>.bats` so `make test` includes it.
3. **`tests/run_tests.sh`**, `fast_image_hash()` array — append the absolute path so edits to the file invalidate the prepared image cache.

`tests/test_fast_image_hash_covers_bats.sh` runs as part of `make test` and will fail loudly if you miss step 3. After the changes, run `make test-rebuild` once to refresh the prepared image.

### Adding OS-conditional behavior

Use chezmoi template syntax in `.tmpl` files:

```
{{ if eq .chezmoi.os "darwin" -}}
# macOS-specific content
{{ else if eq .chezmoi.os "linux" -}}
# Linux-specific content
{{ end -}}
```

If a file should only exist on one OS, add it to `home/.chezmoiignore`:

```
{{ if ne .chezmoi.os "darwin" }}
dot_some_macos_thing
{{ end }}
```

## Test Files Reference

| File | What it tests |
|---|---|
| `backup.bats` | Dotfile backup before chezmoi overwrites |
| `dotfiles.bats` | Managed dotfile existence, content, and templates |
| `shell_clean.bats` | Interactive shell has no background noise |
| `mise_tools.bats` | Mise tools are installed correctly |
| `ai_agents.bats` | AI coding agent and skills installation |
| `claude_code.bats` | Claude Code statusline and settings configuration |
| `claude_waiting.bats` | Claude-waiting tmux/sesh indicator: flag writer, status renderer, sesh annotator, settings.json hooks |
| `update_script.bats` | Update script exists and is executable |

## Test Helpers Reference

| Helper | Purpose | Example |
|---|---|---|
| `assert_command_exists` | Binary exists in PATH | `assert_command_exists rg` |
| `assert_file_exists` | File exists | `assert_file_exists "$HOME/.aliases"` |
| `assert_file_contains` | File contains string | `assert_file_contains "$HOME/.bashrc" "mise activate"` |
| `assert_dir_exists` | Directory exists | `assert_dir_exists "$HOME/.oh-my-zsh"` |
| `assert_mise_tool` | Mise tool is installed | `assert_mise_tool node` |
| `load_backup_dir` | Load backup dir path into `$BACKUP_DIR` | `load_backup_dir` |
| `require_setup` | Skip test if setup hasn't run | `require_setup` |

Add new helpers to `tests/test_helper.bash` when existing ones don't cover your case.
