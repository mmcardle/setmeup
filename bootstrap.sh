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
# Back up existing dotfiles before chezmoi overwrites them
# ---------------------------------------------------------------------------
backup_dotfiles() {
    local BACKUP_FILES=".aliases .config/git/config .config/mise/config.toml"
    local has_files=false
    local f
    local backup_dir

    # Check if any managed files exist
    for f in $BACKUP_FILES; do
        if [ -f "$HOME/$f" ]; then
            has_files=true
            break
        fi
    done

    if [ "$has_files" = false ]; then
        info "No existing dotfiles to back up (fresh machine)"
        return
    fi

    backup_dir="$HOME/.local/state/setmeup/backups/$(date +%Y-%m-%d-%H%M%S)"
    info "Backing up existing dotfiles to $backup_dir/"

    for f in $BACKUP_FILES; do
        if [ -f "$HOME/$f" ]; then
            mkdir -p "$backup_dir/$(dirname "$f")"
            cp -p "$HOME/$f" "$backup_dir/$f"
        fi
    done

    info "Backup complete — you can restore from there if needed"
}

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
    USE_LOCAL=false
    if [ "${1:-}" = "--local" ]; then
        USE_LOCAL=true
    fi

    info "Starting setmeup bootstrap..."

    detect_os
    detect_package_manager

    info "Detected OS: $OS, package manager: $PKG_MGR"

    install_prerequisites
    install_chezmoi
    install_mise

    backup_dotfiles

    if [ "$USE_LOCAL" = true ]; then
        local script_dir
        script_dir="$(cd "$(dirname "$0")" && pwd)"
        info "Initializing chezmoi from local source ($script_dir/home)..."
        # Symlink repo into chezmoi's default source so chezmoi update works
        local chezmoi_src="$HOME/.local/share/chezmoi"
        mkdir -p "$(dirname "$chezmoi_src")"
        ln -sfn "$script_dir/home" "$chezmoi_src"
        chezmoi init --apply
    else
        info "Initializing chezmoi with $SETMEUP_REPO..."
        chezmoi init --apply "$SETMEUP_REPO"
    fi

    info "Installing mise tools..."
    mise install --yes || warn "Some mise tools failed to install (retry with: mise install)"

    # Install the update script
    local repo_root
    if [ "$USE_LOCAL" = true ]; then
        repo_root="$script_dir"
    else
        repo_root="$(chezmoi source-path)/.."
    fi
    cp "$repo_root/update.sh" "$HOME/.local/bin/setmeup-update.sh"
    chmod +x "$HOME/.local/bin/setmeup-update.sh"

    info "Bootstrap complete!"
    echo ""
    echo "  Your development environment is ready."
    echo "  Open a new shell to activate all settings."
    echo ""
    echo "  To update later, run:  setmeup update"
    echo "  Or manually:           chezmoi update && mise install"
    echo ""
}

# Allow sourcing for tests: only run main when executed directly
if [ "${SETMEUP_SOURCED:-}" != "true" ]; then
    main "$@"
fi
