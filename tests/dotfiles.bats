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
