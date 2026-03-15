#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

# --- File existence ---

@test "managed dotfile exists: .bashrc" {
    assert_file_exists "$HOME/.bashrc"
}

@test "managed dotfile exists: .zshrc" {
    assert_file_exists "$HOME/.zshrc"
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

@test "managed dotfile exists: .ssh/config" {
    assert_file_exists "$HOME/.ssh/config"
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

@test "bashrc sources aliases" {
    assert_file_contains "$HOME/.bashrc" ". ~/.aliases"
}

@test "zshrc sources aliases" {
    assert_file_contains "$HOME/.zshrc" "source ~/.aliases"
}

# --- Mise activation ---

@test "bashrc activates mise" {
    assert_file_contains "$HOME/.bashrc" "mise activate bash"
}

@test "zshrc activates mise" {
    assert_file_contains "$HOME/.zshrc" "mise activate zsh"
}

# --- SSH config ---

@test "SSH config uses Linux identity file" {
    assert_file_contains "$HOME/.ssh/config" "IdentityFile ~/.ssh/id_ed25519"
}

# --- Oh-my-zsh ---

@test "zshrc sets powerlevel10k theme" {
    assert_file_contains "$HOME/.zshrc" 'ZSH_THEME="powerlevel10k/powerlevel10k"'
}

@test "zshrc sources oh-my-zsh" {
    assert_file_contains "$HOME/.zshrc" 'source "$ZSH/oh-my-zsh.sh"'
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

@test "zshrc enables zsh-autosuggestions plugin" {
    assert_file_contains "$HOME/.zshrc" "zsh-autosuggestions"
}

@test "zshrc enables zsh-syntax-highlighting plugin" {
    assert_file_contains "$HOME/.zshrc" "zsh-syntax-highlighting"
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

@test "aliases file conditionally aliases find to fd" {
    assert_file_contains "$HOME/.aliases" 'alias find="fd'
}

@test "aliases file conditionally aliases grep to rg" {
    assert_file_contains "$HOME/.aliases" 'alias grep="rg'
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

# --- macOS defaults script ---

@test "macos-defaults script exists in chezmoi source" {
    assert_file_exists "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl"
}

@test "macos-defaults script sets Finder to show hidden files" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl" "AppleShowAllFiles"
}

@test "macos-defaults script sets fast key repeat" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl" "KeyRepeat"
}

@test "macos-defaults script disables auto-correct" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl" "NSAutomaticSpellingCorrectionEnabled"
}

@test "macos-defaults script shows all file extensions" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl" "AppleShowAllExtensions"
}

@test "macos-defaults script enables tap to click" {
    assert_file_contains "$HOME/setmeup/home/.chezmoiscripts/run_once_macos-defaults.sh.tmpl" "com.apple.driver.AppleBluetoothMultitouch.trackpad"
}
