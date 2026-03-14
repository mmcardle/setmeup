# setmeup

Automated development machine setup using [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

A single command bootstraps a fully configured environment with dotfiles, shell configs, git settings, and development tools.

## Quick Start

```sh
curl -fsLS https://raw.githubusercontent.com/mmcardle/setmeup/main/bootstrap.sh | sh
```

This will:
1. Install chezmoi and mise
2. Apply all dotfiles and shell configurations
3. Install development tools (Python, Node, Rust, jq, ripgrep, fd, fzf, uv)

## What's Managed

| Component | Details |
|-----------|---------|
| **Shell configs** | `.bashrc`, `.zshrc` with mise activation, auto-update checks |
| **Aliases** | Git, Docker, and utility aliases shared across shells |
| **Git config** | User name/email (prompted on first run), sensible defaults |
| **SSH config** | Platform-aware SSH settings |
| **Dev tools** | Python, Node (LTS), Rust, jq, ripgrep, fd, fzf, uv via mise |
| **System packages** | build-essential, curl, git, zsh, etc. via apt/brew |

## Updating

```sh
setmeup update
```

Or manually:
```sh
chezmoi update && mise install
```

A daily auto-check runs on shell start and notifies you when updates are available.

## Supported Platforms

- Linux (including WSL2)
- macOS

Both bash and zsh are supported.

## Repository Structure

```
setmeup/
├── bootstrap.sh                    # curl-able entry point
├── update.sh                       # manual update script
└── home/                           # chezmoi source directory
    ├── .chezmoi.toml.tmpl          # chezmoi config with prompts
    ├── .chezmoiignore              # OS-specific ignore rules
    ├── dot_bashrc.tmpl             # managed .bashrc
    ├── dot_zshrc.tmpl              # managed .zshrc
    ├── dot_aliases                 # shared shell aliases
    ├── dot_config/
    │   ├── mise/config.toml        # mise tool definitions
    │   └── git/config.tmpl         # git config (templated)
    ├── dot_ssh/config.tmpl         # SSH config (templated)
    └── .chezmoiscripts/
        ├── run_once_install-packages.sh.tmpl
        └── run_onchange_install-mise-tools.sh.tmpl
```
