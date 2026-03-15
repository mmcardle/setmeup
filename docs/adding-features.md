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
# Full test suite (Docker-based, clean environment)
make test

# Single test file
make test-file FILE=dotfiles.bats

# Tests matching a pattern
make test-filter FILTER="aliases"

# Fast tests only (skip slow mise_tools and shell_clean)
make test-quick

# Interactive shell for fastest TDD loop
make shell
# Inside container (run once):
~/tests/setup_environment.sh
# Then iterate:
bats ~/tests/dotfiles.bats                     # run one file
bats --filter "aliases" ~/tests/*.bats          # run one test
# After editing a dotfile on host:
chezmoi apply --source=~/setmeup/home && bats ~/tests/dotfiles.bats
```

Tests run inside a Docker container (Ubuntu 24.04) with a clean `testuser`, so they always start from a known state.

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

### Adding a new shell alias

1. Test: `assert_file_contains "$HOME/.aliases" "alias myalias="` in `tests/dotfiles.bats`
2. Implement: add the alias to `home/dot_aliases`

### Adding a new mise tool

1. Test: `assert_mise_tool <tool>` in `tests/mise_tools.bats`
2. Implement: add `<tool> = "latest"` to `home/dot_config/mise/config.toml`

### Adding a new system package

1. Test: `assert_command_exists <package>` in the appropriate `.bats` file
2. Implement: add the package to the appropriate list in `home/.chezmoiscripts/run_onchange_001-install-packages.sh.tmpl`

### Adding a new chezmoi script

Scripts live in `home/.chezmoiscripts/` and use a **numeric prefix** for execution order:

```
run_onchange_001-install-packages.sh.tmpl      # system packages (apt/brew)
run_onchange_002-macos-defaults.sh.tmpl        # macOS defaults
run_onchange_003-install-mise-tools.sh.tmpl    # mise tool installs
run_onchange_004-install-ai-agents.sh.tmpl     # AI coding agents
run_onchange_005-install-agent-skills.sh.tmpl  # agent skills
```

When adding a new script, pick the next number (e.g. `006`). To insert between existing scripts, use a number in the gap (e.g. `003` and `004` have room for `0035` if needed, but generally append).

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
if command -v mise >/dev/null 2>&1; then
    mise exec node@lts -- npm i -g some-package
else
    echo "[setmeup] Warning: mise not found, skipping install"
fi
```

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
| `idempotency.bats` | Chezmoi re-apply succeeds without errors |
| `ai_agents.bats` | AI coding agent and skills installation |
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
