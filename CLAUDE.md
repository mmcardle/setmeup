# setmeup

A tool for setting up a new development machine.

## Project Structure

```
setmeup/
├── bootstrap.sh                    # Curl-able entry point: detects OS, installs chezmoi+mise, applies dotfiles
├── update.sh                       # Manual update script (installed to ~/.local/bin/setmeup-update.sh)
├── Makefile                        # make test, make test-full, make shell
├── .chezmoiroot                    # Marks "home/" as chezmoi source root
│
├── home/                           # Chezmoi source directory → maps to ~/
│   ├── .chezmoi.toml.tmpl          # Chezmoi config (prompts for git name/email)
│   ├── .chezmoiignore              # OS-conditional ignore rules
│   ├── .chezmoiexternal.toml       # External downloads (oh-my-zsh, powerlevel10k)
│   ├── dot_chezmoiignore           # Never-manage list (.secrets)
│   │
│   ├── dot_aliases                 # Shared shell aliases (git, docker, utilities)
│   ├── dot_tmux.conf               # Tmux configuration (plugins, keybindings, vim-navigator)
│   ├── dot_vimrc                   # Vim config (syntax highlighting, filetype detection)
│   │
│   ├── dot_claude/
│   │   └── statusline-command.sh    # Claude Code statusline display script
│   │
│   ├── dot_config/
│   │   ├── git/config.tmpl         # Git config (templated user, aliases, defaults)
│   │   ├── mise/config.toml        # Mise tool definitions (python, node, rust, jq, rg, fd, fzf, uv, claude-code, codex)
│   │   ├── nvim/init.vim           # Neovim entry point (sources ~/.vimrc)
│   │   └── setmeup/
│   │       ├── bashrc.tmpl         # Shell config sourced from ~/.bashrc (mise, history, prompt, auto-update)
│   │       └── zshrc.tmpl          # Shell config sourced from ~/.zshrc (p10k, oh-my-zsh, mise, auto-update)
│   │
│   │
│   └── .chezmoiscripts/            # Chezmoi lifecycle scripts (numbered for execution order)
│       ├── run_onchange_000-inject-shell-source.sh.tmpl   # Injects source lines into ~/.bashrc and ~/.zshrc
│       ├── run_onchange_001-install-packages.sh.tmpl      # System packages (apt/brew)
│       ├── run_onchange_002-macos-defaults.sh.tmpl        # macOS defaults
│       ├── run_onchange_003-install-mise-tools.sh.tmpl    # Mise tools (runs when config changes)
│       ├── run_onchange_004-install-agent-skills.sh.tmpl  # Superpowers skills (re-runs when mise config changes)
│       ├── run_always_005-configure-claude-code.sh.tmpl # Claude Code settings (statusLine merge)
│       └── run_always_006-rebuild-font-cache.sh.tmpl    # Rebuild fontconfig cache after font install
│
└── tests/
    ├── run_tests.sh                # Test runner (fast prepared image + full clean rebuild mode)
    ├── Dockerfile                  # Multi-stage test container for prepared and full test paths
    ├── chezmoi-test-config.toml    # Pre-seeded config for non-interactive tests
    ├── setup_environment.sh        # Phases 1-3: verify tools, backup dotfiles, chezmoi apply
    ├── test_helper.bash            # Shared BATS assertion helpers
    ├── backup.bats                 # Backup verification tests
    ├── dotfiles.bats               # Dotfile existence and content tests
    ├── shell_clean.bats            # Interactive shell cleanliness test
    ├── mise_tools.bats             # Mise tool installation tests
    ├── ai_agents.bats              # AI coding agent and skills tests
    ├── claude_code.bats            # Claude Code statusline and settings tests
    └── update_script.bats          # Update script tests
```

### Chezmoi naming conventions

- `dot_` prefix → becomes `.` in home (e.g. `dot_aliases` → `~/.aliases`)
- `.tmpl` suffix → templated file (chezmoi variables interpolated)
- `run_onchange_NNN-*` scripts → execute when content hash changes; numeric prefix controls order

### Key paths at runtime

- Fonts: `~/.local/share/fonts/JetBrainsMonoNerdFont/`
- Backups: `~/.local/state/setmeup/backups/[timestamp]/`
- State: `~/.local/state/setmeup/`
- Update script: `~/.local/bin/setmeup-update.sh`

## Tests

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System) and run in Docker.

```sh
# Fast local smoke suite
make test

# Clean full integration suite
make test-full

# Single file
make test-file FILE=dotfiles.bats

# Filter by test name
make test-filter FILTER="aliases"

# Alias for the fast local smoke suite
make test

# Rebuild the prepared fast image after setup-affecting changes
make test-rebuild

# Remove this worktree's scoped test images and cache
make test-clean

# Remove all scoped setmeup test images on this host
make test-clean-all

# Interactive TDD loop in the prepared container
make shell
# Then:
bats ~/tests/dotfiles.bats
```

Docker test images are isolated per worktree. `make test` and `make shell` reuse the prepared image only within the current worktree, and the first run in a new worktree builds a new scoped image.

## Development

Always use TDD (test-driven development) when adding features. Write the failing test first, then implement.

See [docs/adding-features.md](docs/adding-features.md) for a step-by-step guide.

Always update the tests when making changes to the code.

Run the tests before completing the users requests.
