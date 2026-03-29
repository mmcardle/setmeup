#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Source the runner so helper functions can be tested without executing Docker.
. "$REPO_ROOT/tests/run_tests.sh"

path_a="$REPO_ROOT"
path_b="$REPO_ROOT-alt"

scope_a_1="$(scope_for_path "$path_a")"
scope_a_2="$(scope_for_path "$path_a")"
scope_b="$(scope_for_path "$path_b")"

[ "$scope_a_1" = "$scope_a_2" ] || {
    echo "expected same path to produce stable scope" >&2
    exit 1
}

[ "$scope_a_1" != "$scope_b" ] || {
    echo "expected different paths to produce different scopes" >&2
    exit 1
}

case "$scope_a_1" in
    ??????* )
        :
        ;;
    * )
        echo "expected non-empty scope" >&2
        exit 1
        ;;
esac

fast_ref="$(fast_image_ref)"
full_ref="$(full_image_ref)"
expected_suffix="$(worktree_scope)"

case "$fast_ref" in
    "setmeup-test-fast:$expected_suffix" )
        :
        ;;
    * )
        echo "unexpected fast image ref: $fast_ref" >&2
        exit 1
        ;;
esac

case "$full_ref" in
    "setmeup-test-full:$expected_suffix" )
        :
        ;;
    * )
        echo "unexpected full image ref: $full_ref" >&2
        exit 1
        ;;
esac
