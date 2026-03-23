#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
    load_backup_dir
}

@test "backup directory was created" {
    assert_dir_exists "$BACKUP_DIR"
}

@test "backup contains .config/git/config" {
    assert_file_exists "${BACKUP_DIR}.config/git/config"
}

@test "backup .config/git/config has original content" {
    assert_file_contains "${BACKUP_DIR}.config/git/config" "user's original gitconfig"
}

@test "bashrc preserves user content after chezmoi apply" {
    # We no longer overwrite bashrc — it should still have original content
    # plus the injected source line
    assert_file_contains "$HOME/.bashrc" "user's original bashrc"
}

@test "zshrc preserves user content after chezmoi apply" {
    # We no longer overwrite zshrc — it should still have original content
    # plus the injected source line
    assert_file_contains "$HOME/.zshrc" "user's original zshrc"
}
