#!/bin/sh
# Build and run the setmeup test suite in Docker
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[setmeup] Building test image..."
docker build -t setmeup-test -f "$REPO_ROOT/tests/Dockerfile" "$REPO_ROOT"

echo "[setmeup] Running tests..."
# Pass GITHUB_TOKEN to avoid GitHub API rate limits during mise installs
DOCKER_RUN_ARGS=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
    DOCKER_RUN_ARGS="-e GITHUB_TOKEN"
    echo "[setmeup] GITHUB_TOKEN detected, passing to container"
fi
docker run --rm $DOCKER_RUN_ARGS setmeup-test

echo "[setmeup] Tests complete."
