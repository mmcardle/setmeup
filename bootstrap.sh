#!/bin/sh
# setmeup bootstrap — curl-able entry point for automated device setup
# Usage: curl -fsLS https://raw.githubusercontent.com/mmcardle/setmeup/main/bootstrap.sh | sh
set -e

SETMEUP_REPO="mmcardle/setmeup"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[1;34m[setmeup]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[setmeup]\033[0m %s\n' "$1"; }
error() { printf '\033[1;31m[setmeup]\033[0m %s\n' "$1" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Detect OS and package manager
# ---------------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="darwin" ;;
        *)       error "Unsupported operating system: $(uname -s)" ;;
    esac
}

detect_package_manager() {
    if [ "$OS" = "darwin" ]; then
        PKG_MGR="brew"
    elif command_exists apt-get; then
        PKG_MGR="apt"
    else
        error "No supported package manager found (need apt or brew)"
    fi
}

# ---------------------------------------------------------------------------
# Install prerequisites
# ---------------------------------------------------------------------------
install_prerequisites() {
    info "Checking prerequisites..."

    if [ "$PKG_MGR" = "brew" ]; then
        if ! command_exists brew; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if ! command_exists curl || ! command_exists git; then
            brew install curl git
        fi
    elif [ "$PKG_MGR" = "apt" ]; then
        if ! command_exists curl || ! command_exists git; then
            info "Installing curl and git via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl git
        fi
    fi
}

# ---------------------------------------------------------------------------
# Install chezmoi
# ---------------------------------------------------------------------------
install_chezmoi() {
    if command_exists chezmoi; then
        info "chezmoi is already installed"
        return
    fi
    info "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# Install mise
# ---------------------------------------------------------------------------
install_mise() {
    if command_exists mise; then
        info "mise is already installed"
        return
    fi
    info "Installing mise..."
    curl -fsLS https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    info "Starting setmeup bootstrap..."

    detect_os
    detect_package_manager

    info "Detected OS: $OS, package manager: $PKG_MGR"

    install_prerequisites
    install_chezmoi
    install_mise

    info "Initializing chezmoi with $SETMEUP_REPO..."
    chezmoi init --apply "$SETMEUP_REPO"

    info "Bootstrap complete!"
    echo ""
    echo "  Your development environment is ready."
    echo "  Open a new shell to activate all settings."
    echo ""
    echo "  To update later, run:  setmeup update"
    echo "  Or manually:           chezmoi update && mise install"
    echo ""
}

main "$@"
