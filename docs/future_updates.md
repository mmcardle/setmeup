# Future Updates — Analysis of RawGuide.txt

Analysis of a colleague's Mac setup guide against what setmeup already covers.
Items are grouped by priority and effort.

---

## Already Covered

These items from the guide are already handled by setmeup:

| Guide Item | setmeup Implementation |
|---|---|
| Git config (user, aliases, defaults) | `home/dot_config/git/config.tmpl` |
| SSH config | `home/dot_ssh/config.tmpl` (1Password on mac, ed25519 on linux) |
| Oh My Zsh + Powerlevel10k | `.chezmoiexternal.toml` |
| Zsh plugins (git, autosuggestions*) | `dot_zshrc.tmpl` (git, z, command-not-found) |
| Shell aliases (git, ls) | `dot_aliases` |
| mise for version management | `dot_config/mise/config.toml` (python, node, rust, jq, rg, fd, fzf, uv) |
| Core CLI tools (curl, wget, git, gnupg) | `run_once_install-packages.sh.tmpl` |
| History config, shared history | `dot_zshrc.tmpl`, `dot_bashrc.tmpl` |

*zsh-autosuggestions and zsh-syntax-highlighting are not yet pulled in as externals — see below.

---

## Recommended Additions

### High Value, Low Effort

#### 1. Zsh plugins: autosuggestions + syntax-highlighting
The guide installs `zsh-autosuggestions` and `zsh-syntax-highlighting`. We already use Oh My Zsh but only enable `git, z, command-not-found`. These two plugins are nearly universal recommendations.

**What to do:** Add them to `.chezmoiexternal.toml` and enable in `dot_zshrc.tmpl` plugins list.

#### 2. More CLI tools via mise or system packages
The guide installs several tools we don't yet manage:

| Tool | What it does | Suggested via |
|---|---|---|
| `bat` | Better `cat` with syntax highlighting | mise or brew/apt |
| `eza` | Modern `ls` replacement with icons | mise or brew/apt |
| `htop` | Interactive process viewer | brew/apt |
| `tree` | Directory tree display | brew/apt |
| `ncdu` | Disk usage analyzer | brew/apt |
| `lazygit` | Terminal Git UI | mise or brew/apt |
| `gh` | GitHub CLI | mise or brew/apt |
| `tmux` | Terminal multiplexer | brew/apt |
| `httpie` | User-friendly HTTP client | mise or brew/apt |
| `direnv` | Per-directory env variables | mise or brew/apt |
| `neovim` | Modern vim | brew/apt |

**What to do:** Add to `mise/config.toml` where supported, otherwise to `run_once_install-packages.sh.tmpl`.

#### 3. Modern tool aliases
The guide aliases `cat→bat`, `ls→eza`, `find→fd`, `grep→rg`. We already install `fd`, `rg`, and `fzf` but don't alias them.

**What to do:** Add conditional aliases to `dot_aliases` (only alias if the tool is available):
```sh
command -v bat  &>/dev/null && alias cat="bat"
command -v eza  &>/dev/null && alias ls="eza --icons" && alias ll="eza -l --icons" && alias la="eza -la --icons"
```

#### 4. Global gitignore
The guide creates `~/.gitignore_global` with common ignores (`.DS_Store`, `.env`, `node_modules/`, IDE files). We don't manage this yet.

**What to do:** Add `home/dot_config/git/ignore` (Git reads `core.excludesFile` which we can set in `config.tmpl`).

### Medium Value, Medium Effort

#### 5. macOS defaults configuration
The guide sets many `defaults write` preferences:
- Show hidden files in Finder
- Fast key repeat (KeyRepeat=2, InitialKeyRepeat=15)
- Disable auto-correct/capitalize/period-substitution
- Show all file extensions

**What to do:** Add a `run_once_macos-defaults.sh.tmpl` chezmoi script (guarded with `{{ if eq .chezmoi.os "darwin" }}`).

#### 6. Firewall and security hardening (macOS)
The guide enables FileVault, firewall, stealth mode, and sets hostname.

**What to do:** Add an optional `run_once_macos-security.sh.tmpl` script. Consider making this opt-in via a chezmoi prompt since it requires `sudo`.

#### 7. Docker / container tooling
The guide recommends OrbStack (mac) or Colima, plus utilities like `dive`, `lazydocker`, `hadolint`.

**What to do:** Add container tools to system packages (platform-conditional). Consider a chezmoi data prompt like `install_docker = true/false` to make it opt-in.

#### 8. Database tooling
The guide installs PostgreSQL, Redis, SQLite, pgcli, mycli, mongosh, and GUI clients.

**What to do:** This is very user-specific. Consider an opt-in `install_databases` prompt, then install `postgresql`, `redis`, `sqlite` via brew/apt and `pgcli` via pipx/mise.

### Lower Priority / Nice to Have

#### 9. Project directory structure
The guide creates `~/Development/{projects,sandbox,learning,tools,archived}`.

**What to do:** Could add as a `run_once_` script but this is very opinionated. Skip or make opt-in.

#### 10. Maintenance / update scripts
The guide creates a weekly maintenance script (brew update, npm update, cache cleanup, docker prune).

**What to do:** We already have `setmeup-update.sh` for dotfile updates. Could extend it or create a separate `setmeup-maintain.sh`. Low priority since users have different preferences.

#### 11. Backup tooling (restic, rclone, Time Machine exclusions)
Very user-specific. Not a good fit for a general-purpose setup tool.

#### 12. Performance tuning (sysctl, nvram boot-args)
The guide sets `kern.maxfiles`, `kern.maxfilesperproc`, and `serverperfmode=1`. These are aggressive system changes.

**What to do:** Skip for default installs. Could document as optional post-setup steps.

#### 13. Additional language tooling
The guide installs Ruby, CocoaPods, SwiftLint, SwiftFormat, LLVM, Boost, Eigen. These are very stack-specific.

**What to do:** Not suitable for the default config. Users can add to their own `mise/config.toml` as needed.

#### 14. AI tool integrations
The guide installs Copilot CLI, Ollama, aicommits, Sourcegraph CLI. Fast-moving space with frequent changes.

**What to do:** Skip. These are better installed ad-hoc.

---

## Summary — Suggested Roadmap

| Priority | Item | Effort |
|---|---|---|
| P1 | Zsh autosuggestions + syntax-highlighting | Small |
| P1 | More CLI tools (bat, eza, gh, htop, lazygit, etc.) | Small |
| P1 | Modern tool aliases (cat→bat, ls→eza) | Small |
| P1 | Global gitignore | Small |
| P2 | macOS defaults script | Medium |
| P2 | macOS security hardening | Medium |
| P2 | Docker/container tooling (opt-in) | Medium |
| P2 | Database tooling (opt-in) | Medium |
| P3 | Project directory structure | Small |
| P3 | Extended maintenance script | Small |
| P3 | Backup tooling | Medium |
| P3 | Performance tuning docs | Small |
