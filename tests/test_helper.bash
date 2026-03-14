#!/bin/bash
# Shared BATS test helpers for setmeup test suite

SETUP_SENTINEL="$HOME/.local/state/setmeup/test-setup-complete"
BACKUP_STATE_FILE="$HOME/.local/state/setmeup/test-backup-dir"

# Skip test if setup_environment.sh hasn't run
require_setup() {
    if [[ ! -f "$SETUP_SENTINEL" ]]; then
        skip "setup_environment.sh has not been run"
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "expected file to exist: $file" >&2
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "expected directory to exist: $dir" >&2
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if [[ ! -f "$file" ]]; then
        echo "file does not exist: $file" >&2
        return 1
    fi
    if ! grep -q "$pattern" "$file"; then
        echo "expected '$file' to contain '$pattern'" >&2
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "expected command to exist: $cmd" >&2
        return 1
    fi
}

assert_mise_tool() {
    local tool="$1"
    if ! mise which "$tool" >/dev/null 2>&1; then
        echo "expected mise tool to be installed: $tool" >&2
        return 1
    fi
}

# Load the backup directory path saved by setup_environment.sh
load_backup_dir() {
    if [[ ! -f "$BACKUP_STATE_FILE" ]]; then
        echo "backup state file not found: $BACKUP_STATE_FILE" >&2
        return 1
    fi
    BACKUP_DIR="$(cat "$BACKUP_STATE_FILE")"
}
