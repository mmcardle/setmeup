#!/usr/bin/env bats

# chezmoi init only clones when the source has no git repo yet; it never
# pulls. These tests cover bootstrap updating an existing checkout so that
# re-running the curl one-liner applies the latest commits.

setup() {
    SETMEUP_SOURCED=true source "$HOME/setmeup/bootstrap.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.local/share"

    ORIGIN="$BATS_TEST_TMPDIR/origin.git"
    WORK="$BATS_TEST_TMPDIR/work"
    SOURCE="$HOME/.local/share/chezmoi"

    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$WORK" 2>/dev/null
    commit_in "$WORK" "first"
    git -C "$WORK" push -q origin main
}

commit_in() {
    git -C "$1" -c user.name=Test -c user.email=test@example.com \
        commit -q --allow-empty -m "$2"
}

@test "update_existing_source pulls new commits into an existing checkout" {
    git clone -q "$ORIGIN" "$SOURCE"
    commit_in "$WORK" "second"
    git -C "$WORK" push -q origin main

    run update_existing_source
    [ "$status" -eq 0 ]
    [ "$(git -C "$SOURCE" log -1 --format=%s)" = "second" ]
}

@test "update_existing_source does nothing on a fresh machine" {
    run update_existing_source
    [ "$status" -eq 0 ]
    [ ! -e "$SOURCE" ]
}

@test "update_existing_source fails loudly when the checkout has diverged" {
    git clone -q "$ORIGIN" "$SOURCE"
    commit_in "$SOURCE" "local edit"
    commit_in "$WORK" "second"
    git -C "$WORK" push -q origin main

    run update_existing_source
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not update"* ]]
    [ "$(git -C "$SOURCE" log -1 --format=%s)" = "local edit" ]
}

@test "main updates the existing checkout before chezmoi init" {
    detect_os() { OS="linux"; }
    detect_package_manager() { PKG_MGR="apt"; }
    install_prerequisites() { :; }
    install_chezmoi() { :; }
    install_mise() { :; }
    backup_dotfiles() { :; }
    update_existing_source() { echo "CALL update_existing_source"; }
    chezmoi() {
        echo "CALL chezmoi $*"
        if [ "$1" = "source-path" ]; then
            printf '%s\n' "$BATS_TEST_DIRNAME"
        fi
    }
    mise() { :; }
    cp() { :; }
    chmod() { :; }

    run main
    [ "$status" -eq 0 ]
    local calls
    calls="$(printf '%s\n' "$output" | grep '^CALL' | head -2)"
    [ "$calls" = "$(printf 'CALL update_existing_source\nCALL chezmoi init --apply mmcardle/setmeup')" ]
}
