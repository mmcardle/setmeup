#!/bin/sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require_line() {
    file="$1"
    pattern="$2"
    if ! grep -qF "$pattern" "$file"; then
        echo "missing pattern in $file: $pattern" >&2
        exit 1
    fi
}

require_file() {
    path="$1"
    if [ ! -f "$path" ]; then
        echo "missing file: $path" >&2
        exit 1
    fi
}

require_line "$REPO_ROOT/Makefile" "test-full:"
require_line "$REPO_ROOT/Makefile" "test-rebuild:"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh fast"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh full"
require_line "$REPO_ROOT/tests/run_tests.sh" 'MODE="${1:-fast}"'
require_line "$REPO_ROOT/tests/run_tests.sh" 'FAST_BATS_FILES='
require_line "$REPO_ROOT/tests/run_tests.sh" 'FULL_BATS_FILES='
require_line "$REPO_ROOT/tests/run_tests.sh" 'prepare_fast_image'
require_line "$REPO_ROOT/tests/run_tests.sh" 'run_full_suite'
require_file "$REPO_ROOT/.dockerignore"
