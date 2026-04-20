#!/usr/bin/env bash
# Verify fast_image_hash in run_tests.sh covers every bats file COPY'd
# into the Dockerfile's prepared stage. If a bats file is baked into the
# prepared image but omitted from the hash, edits to it will not trigger
# a rebuild and tests will run against stale content.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKERFILE="$REPO_ROOT/tests/Dockerfile"
RUN_TESTS="$REPO_ROOT/tests/run_tests.sh"

copied=$(
    awk '
        /^FROM[[:space:]]+prepared-setup[[:space:]]+AS[[:space:]]+prepared/ { inside = 1; next }
        /^FROM[[:space:]]/ { inside = 0 }
        inside && /^COPY/ { print }
    ' "$DOCKERFILE" | grep -oE 'tests/[A-Za-z0-9_]+\.bats' | sort -u
)

listed=$(
    awk '
        /^fast_image_hash\(\)[[:space:]]*\{/ { inside = 1; next }
        inside && /^\}/ { inside = 0 }
        inside
    ' "$RUN_TESTS" | grep -oE 'tests/[A-Za-z0-9_]+\.bats' | sort -u
)

missing=$(comm -23 <(printf '%s\n' "$copied") <(printf '%s\n' "$listed"))

if [ -n "$missing" ]; then
    echo "ERROR: bats files COPY'd into prepared image but missing from fast_image_hash:" >&2
    echo "$missing" >&2
    exit 1
fi

echo "OK: fast_image_hash covers all prepared-stage bats files"
