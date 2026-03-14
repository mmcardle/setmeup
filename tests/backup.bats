#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
    load_backup_dir
}

@test "backup directory was created" {
    assert_dir_exists "$BACKUP_DIR"
}

@test "backup contains .bashrc" {
    assert_file_exists "${BACKUP_DIR}.bashrc"
}

@test "backup contains .zshrc" {
    assert_file_exists "${BACKUP_DIR}.zshrc"
}

@test "backup contains .config/git/config" {
    assert_file_exists "${BACKUP_DIR}.config/git/config"
}

@test "backup .bashrc has original content" {
    assert_file_contains "${BACKUP_DIR}.bashrc" "user's original bashrc"
}

@test "backup .zshrc has original content" {
    assert_file_contains "${BACKUP_DIR}.zshrc" "user's original zshrc"
}

@test "backup .config/git/config has original content" {
    assert_file_contains "${BACKUP_DIR}.config/git/config" "user's original gitconfig"
}

@test "backup preserved file permissions" {
    local perms
    perms="$(stat -c '%a' "${BACKUP_DIR}.bashrc")"
    [ "$perms" = "600" ]
}

@test "chezmoi overwrote original .bashrc" {
    ! grep -q "user's original bashrc" "$HOME/.bashrc"
}
