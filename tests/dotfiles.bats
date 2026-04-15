#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

# --- File existence ---

@test "managed dotfile exists: .config/setmeup/bashrc" {
    assert_file_exists "$HOME/.config/setmeup/bashrc"
}

@test "managed dotfile exists: .config/setmeup/zshrc" {
    assert_file_exists "$HOME/.config/setmeup/zshrc"
}

@test "managed dotfile exists: .aliases" {
    assert_file_exists "$HOME/.aliases"
}

@test "managed dotfile exists: .config/git/config" {
    assert_file_exists "$HOME/.config/git/config"
}

@test "managed dotfile exists: .config/mise/config.toml" {
    assert_file_exists "$HOME/.config/mise/config.toml"
}

@test "managed dotfile exists: .tmux.conf" {
    assert_file_exists "$HOME/.tmux.conf"
}

@test "tmux.conf enables mouse mode" {
    assert_file_contains "$HOME/.tmux.conf" "setw -g mouse on"
}

@test "tmux.conf sets prefix to C-a" {
    assert_file_contains "$HOME/.tmux.conf" "set -g prefix C-a"
}

@test "tmux.conf uses vi mode keys" {
    assert_file_contains "$HOME/.tmux.conf" "setw -g mode-keys vi"
}

@test "tmux.conf loads tpm" {
    assert_file_contains "$HOME/.tmux.conf" "run '~/.tmux/plugins/tpm/tpm'"
}

@test "tmux.conf includes vim-tmux-navigator plugin" {
    assert_file_contains "$HOME/.tmux.conf" "christoomey/vim-tmux-navigator"
}

@test "tmux.conf includes tmux-sensible plugin" {
    assert_file_contains "$HOME/.tmux.conf" "tmux-plugins/tmux-sensible"
}

@test "tmux.conf includes tmux-yank plugin" {
    assert_file_contains "$HOME/.tmux.conf" "tmux-plugins/tmux-yank"
}

@test "tmux.conf includes tmux-pain-control plugin" {
    assert_file_contains "$HOME/.tmux.conf" "tmux-plugins/tmux-pain-control"
}

@test "tmux.conf includes tmux-fzf plugin" {
    assert_file_contains "$HOME/.tmux.conf" "sainnhe/tmux-fzf"
}

@test "tmux.conf includes tmux-sessionx plugin" {
    assert_file_contains "$HOME/.tmux.conf" "omerxx/tmux-sessionx"
}

# --- Sesh popup launcher ---

@test "managed dotfile exists: .config/setmeup/sesh-popup.sh" {
    assert_file_exists "$HOME/.config/setmeup/sesh-popup.sh"
}

@test "sesh-popup.sh is executable" {
    [ -x "$HOME/.config/setmeup/sesh-popup.sh" ]
}

@test "sesh-popup.sh prepends mise shims to PATH" {
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" '.local/share/mise/shims'
}

@test "sesh-popup.sh invokes sesh connect" {
    assert_file_contains "$HOME/.config/setmeup/sesh-popup.sh" "sesh connect"
}

@test "tmux.conf binds s to sesh-popup.sh" {
    assert_file_contains "$HOME/.tmux.conf" "bind-key \"s\" run-shell '~/.config/setmeup/sesh-popup.sh'"
}

@test "tmux.conf no longer binds t to sesh" {
    run grep -E '^bind-key "t".*sesh' "$HOME/.tmux.conf"
    [ "$status" -ne 0 ]
}

@test "tpm is installed via chezmoi externals" {
    assert_dir_exists "$HOME/.tmux/plugins/tpm"
}

# --- Vim / Neovim ---

@test "managed dotfile exists: .vimrc" {
    assert_file_exists "$HOME/.vimrc"
}

@test "vimrc enables syntax highlighting" {
    assert_file_contains "$HOME/.vimrc" "syntax on"
}

@test "vimrc enables filetype plugin indent" {
    assert_file_contains "$HOME/.vimrc" "filetype plugin indent on"
}

@test "managed dotfile exists: .config/nvim/init.vim" {
    assert_file_exists "$HOME/.config/nvim/init.vim"
}

@test "nvim init.vim sources vimrc" {
    assert_file_contains "$HOME/.config/nvim/init.vim" "source ~/.vimrc"
}

# --- Nerd Font ---

@test "nerd font directory exists" {
    assert_dir_exists "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
}

@test "nerd font ttf files are installed" {
    local count
    count=$(find "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" -name "*.ttf" 2>/dev/null | wc -l)
    [ "$count" -gt 0 ]
}

@test "fontconfig finds JetBrainsMono nerd font" {
    run fc-list : family
    [[ "$output" == *"JetBrainsMono"* ]]
}

@test "system package installed: fontconfig" {
    assert_command_exists fc-cache
}

@test "tmux-tokyo-night theme plugin is installed" {
    assert_dir_exists "$HOME/.tmux/plugins/tmux-tokyo-night"
}

@test "tmux-resurrect plugin is installed" {
    assert_dir_exists "$HOME/.tmux/plugins/tmux-resurrect"
}

@test "tmux-yank plugin is installed" {
    assert_dir_exists "$HOME/.tmux/plugins/tmux-yank"
}


# --- Source injection ---

@test "bashrc sources setmeup config" {
    assert_file_contains "$HOME/.bashrc" '.config/setmeup/bashrc'
}

@test "zshrc sources setmeup config" {
    assert_file_contains "$HOME/.zshrc" '.config/setmeup/zshrc'
}

@test "source injection is idempotent" {
    # Count source lines — should be exactly 1 each
    local bash_count
    bash_count=$(grep -c '.config/setmeup/bashrc' "$HOME/.bashrc")
    [ "$bash_count" -eq 1 ]

    local zsh_count
    zsh_count=$(grep -c '.config/setmeup/zshrc' "$HOME/.zshrc")
    [ "$zsh_count" -eq 1 ]
}

# --- Templated values ---

@test "git config contains templated name" {
    assert_file_contains "$HOME/.config/git/config" "Test User"
}

@test "git config contains templated email" {
    assert_file_contains "$HOME/.config/git/config" "test@example.com"
}

# --- Aliases ---

@test "aliases file contains gs alias" {
    assert_file_contains "$HOME/.aliases" "alias gs="
}

@test "aliases file contains dc alias" {
    assert_file_contains "$HOME/.aliases" "alias dc="
}

@test "aliases file contains ll alias" {
    assert_file_contains "$HOME/.aliases" "alias ll="
}

# --- Shell config sources aliases ---

@test "setmeup bashrc sources aliases" {
    assert_file_contains "$HOME/.config/setmeup/bashrc" ". ~/.aliases"
}

@test "setmeup zshrc sources aliases" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" "source ~/.aliases"
}

# --- Mise activation ---

@test "setmeup bashrc activates mise" {
    assert_file_contains "$HOME/.config/setmeup/bashrc" "mise activate bash"
}

@test "setmeup zshrc activates mise" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" "mise activate zsh"
}

# --- SSH config ---

@test "setmeup bashrc configures SSH agent socket" {
    assert_file_contains "$HOME/.config/setmeup/bashrc" 'SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"'
}

@test "setmeup zshrc configures SSH agent socket" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" 'SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"'
}

@test "setmeup bashrc starts ssh-agent on stale socket" {
    assert_file_contains "$HOME/.config/setmeup/bashrc" 'ssh-agent -a "$SSH_AUTH_SOCK"'
}

@test "setmeup zshrc starts ssh-agent on stale socket" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" 'ssh-agent -a "$SSH_AUTH_SOCK"'
}

# --- Oh-my-zsh ---

@test "setmeup zshrc sets powerlevel10k theme" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" 'ZSH_THEME="powerlevel10k/powerlevel10k"'
}

@test "setmeup zshrc sources oh-my-zsh" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" 'source "$ZSH/oh-my-zsh.sh"'
}

@test "oh-my-zsh is installed" {
    assert_dir_exists "$HOME/.oh-my-zsh"
}

@test "powerlevel10k theme is installed" {
    assert_dir_exists "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
}

# --- Zsh plugins ---

@test "zsh-autosuggestions plugin is installed" {
    assert_dir_exists "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
}

@test "zsh-syntax-highlighting plugin is installed" {
    assert_dir_exists "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
}

@test "setmeup zshrc enables zsh-autosuggestions plugin" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" "zsh-autosuggestions"
}

@test "setmeup zshrc enables zsh-syntax-highlighting plugin" {
    assert_file_contains "$HOME/.config/setmeup/zshrc" "zsh-syntax-highlighting"
}

# --- System packages (CLI tools) ---

@test "system package installed: htop" {
    assert_command_exists htop
}

@test "system package installed: tree" {
    assert_command_exists tree
}

@test "system package installed: ncdu" {
    assert_command_exists ncdu
}

@test "system package installed: tmux" {
    assert_command_exists tmux
}

@test "system package installed: neovim" {
    assert_command_exists nvim
}

@test "system package installed: httpie" {
    assert_command_exists http
}

# --- Modern tool aliases ---

@test "aliases file conditionally aliases cat to bat" {
    assert_file_contains "$HOME/.aliases" 'alias cat="bat'
}

@test "aliases file conditionally aliases ls to eza" {
    assert_file_contains "$HOME/.aliases" 'alias ls="eza'
}

@test "aliases file conditionally aliases ll to eza" {
    assert_file_contains "$HOME/.aliases" 'alias ll="eza -l'
}

@test "aliases file conditionally aliases la to eza" {
    assert_file_contains "$HOME/.aliases" 'alias la="eza -la'
}

@test "aliases file conditionally aliases grep to rg" {
    assert_file_contains "$HOME/.aliases" 'alias grep="rg'
}

# --- retry_until_fail function ---

@test "aliases file defines retry_until_fail function" {
    assert_file_contains "$HOME/.aliases" "retry_until_fail()"
}

@test "retry_until_fail passes when all attempts succeed" {
    source "$HOME/.aliases"
    run retry_until_fail 3 true
    [ "$status" -eq 0 ]
    [[ "$output" == *"All 3 attempts passed"* ]]
}

@test "retry_until_fail fails immediately on first failure" {
    source "$HOME/.aliases"
    run retry_until_fail 3 false
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed on attempt 1"* ]]
}

@test "retry_until_fail stops at the failing attempt" {
    source "$HOME/.aliases"
    # Script that succeeds once then fails
    local tmpscript
    tmpscript=$(mktemp)
    echo '#!/bin/bash
    if [ ! -f /tmp/retry_until_fail_test_ran ]; then
        touch /tmp/retry_until_fail_test_ran
        exit 0
    fi
    exit 1' > "$tmpscript"
    chmod +x "$tmpscript"
    rm -f /tmp/retry_until_fail_test_ran

    run retry_until_fail 3 "$tmpscript"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed on attempt 2"* ]]

    rm -f /tmp/retry_until_fail_test_ran "$tmpscript"
}

# --- Global gitignore ---

@test "managed dotfile exists: .config/git/ignore" {
    assert_file_exists "$HOME/.config/git/ignore"
}

@test "git config sets excludesFile" {
    assert_file_contains "$HOME/.config/git/config" "excludesFile"
}

@test "global gitignore contains .DS_Store" {
    assert_file_contains "$HOME/.config/git/ignore" ".DS_Store"
}

@test "global gitignore contains .env" {
    assert_file_contains "$HOME/.config/git/ignore" ".env"
}

@test "global gitignore contains node_modules" {
    assert_file_contains "$HOME/.config/git/ignore" "node_modules"
}

@test "global gitignore contains IDE files" {
    assert_file_contains "$HOME/.config/git/ignore" ".idea"
}

# --- git-delta ---

@test "git config sets delta as pager" {
    assert_file_contains "$HOME/.config/git/config" "pager = delta"
}

@test "git config sets delta as interactive diffFilter" {
    assert_file_contains "$HOME/.config/git/config" "diffFilter = delta --color-only"
}

@test "git config enables delta navigate" {
    assert_file_contains "$HOME/.config/git/config" "navigate = true"
}

@test "git config enables delta side-by-side" {
    assert_file_contains "$HOME/.config/git/config" "side-by-side = true"
}

@test "git config enables delta line-numbers" {
    assert_file_contains "$HOME/.config/git/config" "line-numbers = true"
}

@test "git config sets zdiff3 merge conflict style" {
    assert_file_contains "$HOME/.config/git/config" "conflictstyle = zdiff3"
}

# --- macOS defaults script ---

# --- Chezmoi scripts fail fast if mise is missing ---

@test "install-mise-tools script fails fast without mise guard" {
    run grep -c "skipping tool install" "$HOME/setmeup/home/.chezmoiscripts/run_onchange_003-install-mise-tools.sh.tmpl"
    [ "$output" = "0" ]
}

@test "install-agent-skills script fails fast without mise guard" {
    run grep -c "skipping agent skills install" "$HOME/setmeup/home/.chezmoiscripts/run_onchange_004-install-agent-skills.sh.tmpl"
    [ "$output" = "0" ]
}

@test "macos-defaults script exists in chezmoi source" {
    assert_file_exists "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl"
}

@test "macos-defaults script sets Finder to show hidden files" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" "AppleShowAllFiles"
}

@test "macos-defaults script sets fast key repeat" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" "KeyRepeat"
}

@test "macos-defaults script disables auto-correct" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" "NSAutomaticSpellingCorrectionEnabled"
}

@test "macos-defaults script shows all file extensions" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" "AppleShowAllExtensions"
}

@test "macos-defaults script enables tap to click" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_onchange_002-macos-defaults.sh.tmpl" "com.apple.driver.AppleBluetoothMultitouch.trackpad"
}
