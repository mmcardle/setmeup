#!/bin/sh
# Build and run the setmeup test suite in Docker
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[setmeup] Building test image..."
# Try to get GITHUB_TOKEN from gh CLI if not already set
export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}"
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "[setmeup] ERROR: GITHUB_TOKEN is required (run 'gh auth login' or export GITHUB_TOKEN)"
    exit 1
fi
SECRET_ARGS="--secret id=GITHUB_TOKEN,env=GITHUB_TOKEN"
echo "[setmeup] GITHUB_TOKEN detected, passing to build"
DOCKER_BUILDKIT=1 docker build $SECRET_ARGS -t setmeup-test -f "$REPO_ROOT/tests/Dockerfile" "$REPO_ROOT"

echo "[setmeup] Running tests..."
# Pass GITHUB_TOKEN to avoid GitHub API rate limits during mise installs
DOCKER_RUN_ARGS=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
    DOCKER_RUN_ARGS="-e GITHUB_TOKEN"
    echo "[setmeup] GITHUB_TOKEN detected, passing to container"
fi

# Support argument passthrough for file/filter selection
# Usage: ./tests/run_tests.sh                          # run all tests
#        ./tests/run_tests.sh ~/tests/dotfiles.bats    # run one file
#        ./tests/run_tests.sh --filter "aliases"       # filter tests
BATS_ARGS="${*:-\$HOME/tests/*.bats}"
docker run --rm $DOCKER_RUN_ARGS setmeup-test \
    bash -c "bats $BATS_ARGS"

echo "[setmeup] Tests complete."
