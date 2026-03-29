#!/usr/bin/env bats

setup() {
    SETMEUP_SOURCED=true source "$HOME/setmeup/bootstrap.sh"
}

@test "startup banner includes setmeup branding" {
    run print_banner
    [ "$status" -eq 0 ]
    [[ "$output" == *"setmeup"* ]]
    [[ "$output" == *"SETMEUP"* ]]
    [[ "$output" == *"bootstrap your dev machine"* ]]
}

@test "main prints banner when bootstrap starts" {
    detect_os() { OS="linux"; }
    detect_package_manager() { PKG_MGR="apt"; }
    install_prerequisites() { :; }
    install_chezmoi() { :; }
    install_mise() { :; }
    backup_dotfiles() { :; }

    chezmoi() {
        if [ "$1" = "source-path" ]; then
            printf '%s\n' "$BATS_TEST_DIRNAME"
        fi
    }
    mise() { :; }
    cp() { :; }
    chmod() { :; }
    mkdir() { :; }
    ln() { :; }

    run main --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"setmeup: bootstrap your dev machine"* ]]
}
