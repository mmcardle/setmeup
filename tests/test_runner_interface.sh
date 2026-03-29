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

require_not_tracked() {
    path="$1"
    if git -C "$REPO_ROOT" ls-files --error-unmatch "$path" >/dev/null 2>&1; then
        echo "path should not be tracked: $path" >&2
        exit 1
    fi
}

require_line "$REPO_ROOT/Makefile" "test-full:"
require_line "$REPO_ROOT/Makefile" "test-rebuild:"
require_line "$REPO_ROOT/Makefile" "test-clean:"
require_line "$REPO_ROOT/Makefile" "test-clean-all:"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh fast"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh full"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh clean"
require_line "$REPO_ROOT/Makefile" "./tests/run_tests.sh clean-all"
require_line "$REPO_ROOT/tests/run_tests.sh" 'local mode="${1:-fast}"'
require_line "$REPO_ROOT/tests/run_tests.sh" 'FAST_BATS_FILES='
require_line "$REPO_ROOT/tests/run_tests.sh" 'FULL_BATS_FILES='
require_line "$REPO_ROOT/tests/run_tests.sh" 'prepare_fast_image'
require_line "$REPO_ROOT/tests/run_tests.sh" 'run_full_suite'
require_line "$REPO_ROOT/tests/run_tests.sh" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then'
require_line "$REPO_ROOT/tests/run_tests.sh" 'scope_for_path'
require_line "$REPO_ROOT/tests/run_tests.sh" 'worktree_scope'
require_line "$REPO_ROOT/tests/run_tests.sh" 'fast_image_ref'
require_line "$REPO_ROOT/tests/run_tests.sh" 'full_image_ref'
require_line "$REPO_ROOT/tests/run_tests.sh" 'clean)'
require_line "$REPO_ROOT/tests/run_tests.sh" 'clean-all)'
require_file "$REPO_ROOT/.dockerignore"
require_not_tracked ".cache/setmeup/fast-image.hash"
