#!/usr/bin/env bash
# Build and run the setmeup test suite in Docker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$REPO_ROOT/.cache/setmeup"
FAST_STATE_FILE="$STATE_DIR/fast-image.hash"

FAST_IMAGE="setmeup-test-fast"
FULL_IMAGE="setmeup-test-full"

FAST_BATS_FILES='$HOME/tests/banner.bats $HOME/tests/backup.bats $HOME/tests/claude_code.bats $HOME/tests/dotfiles.bats $HOME/tests/update_script.bats'
FULL_BATS_FILES='$HOME/tests/*.bats'

MODE="${1:-fast}"
if [[ $# -gt 0 ]]; then
    shift
fi

sha_file() {
    local path="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    else
        shasum -a 256 "$path" | awk '{print $1}'
    fi
}

composite_hash() {
    local file

    for file in "$@"; do
        printf '%s  %s\n' "$(sha_file "$file")" "${file#$REPO_ROOT/}"
    done | (
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum
        else
            shasum -a 256
        fi
    ) | awk '{print $1}'
}

ensure_github_token() {
    export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}"
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "[setmeup] ERROR: GITHUB_TOKEN is required (run 'gh auth login' or export GITHUB_TOKEN)"
        exit 1
    fi
    export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
}

docker_run_env_args() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        printf '%s\n' "-e" "GITHUB_TOKEN" "-e" "MISE_GITHUB_TOKEN=$GITHUB_TOKEN"
    fi
}

fast_image_hash() {
    local files=(
        "$REPO_ROOT/bootstrap.sh"
        "$REPO_ROOT/update.sh"
        "$REPO_ROOT/tests/Dockerfile"
        "$REPO_ROOT/tests/setup_environment.sh"
        "$REPO_ROOT/tests/chezmoi-test-config.toml"
        "$REPO_ROOT/tests/test_helper.bash"
        "$REPO_ROOT/tests/backup.bats"
        "$REPO_ROOT/tests/banner.bats"
        "$REPO_ROOT/tests/claude_code.bats"
        "$REPO_ROOT/tests/dotfiles.bats"
        "$REPO_ROOT/tests/update_script.bats"
    )

    while IFS= read -r file; do
        files+=("$file")
    done < <(find "$REPO_ROOT/home" -type f | sort)

    composite_hash "${files[@]}"
}

run_docker_bats() {
    local image="$1"
    local bats_args="$2"
    local -a env_args=()

    while IFS= read -r arg; do
        env_args+=("$arg")
    done < <(docker_run_env_args)

    docker run --rm "${env_args[@]}" "$image" \
        bash -lc "bats $bats_args"
}

prepare_fast_image() {
    local force="${1:-false}"
    local current_hash

    ensure_github_token
    mkdir -p "$STATE_DIR"
    current_hash="$(fast_image_hash)"

    if [[ "$force" != "true" ]] && docker image inspect "$FAST_IMAGE" >/dev/null 2>&1 && \
        [[ -f "$FAST_STATE_FILE" ]] && [[ "$(cat "$FAST_STATE_FILE")" = "$current_hash" ]]; then
        echo "[setmeup] Reusing prepared fast test image"
        return
    fi

    echo "[setmeup] Building prepared fast test image..."
    DOCKER_BUILDKIT=1 docker build \
        --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN \
        --target prepared \
        -t "$FAST_IMAGE" \
        -f "$REPO_ROOT/tests/Dockerfile" \
        "$REPO_ROOT"

    printf '%s\n' "$current_hash" > "$FAST_STATE_FILE"
}

run_full_suite() {
    local bats_args="${*:-$FULL_BATS_FILES}"

    ensure_github_token

    echo "[setmeup] Building clean full test image..."
    DOCKER_BUILDKIT=1 docker build \
        --no-cache \
        --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN \
        --target full \
        -t "$FULL_IMAGE" \
        -f "$REPO_ROOT/tests/Dockerfile" \
        "$REPO_ROOT"

    echo "[setmeup] Running full test suite..."
    run_docker_bats "$FULL_IMAGE" "$bats_args"
}

run_fast_suite() {
    local bats_args="${*:-$FAST_BATS_FILES}"

    prepare_fast_image false

    echo "[setmeup] Running fast smoke suite..."
    run_docker_bats "$FAST_IMAGE" "$bats_args"
}

open_shell() {
    local -a env_args=()

    prepare_fast_image false

    while IFS= read -r arg; do
        env_args+=("$arg")
    done < <(docker_run_env_args)

    docker run --rm -it "${env_args[@]}" "$FAST_IMAGE" bash -lc '
        echo "";
        echo "  Setup is already baked into the prepared image.";
        echo "  Run fast tests directly:";
        echo "    bats ~/tests/dotfiles.bats";
        echo "    bats --filter \"aliases\" ~/tests/dotfiles.bats";
        echo "";
        exec bash -i'
}

case "$MODE" in
    fast)
        run_fast_suite "$@"
        ;;
    full)
        run_full_suite "$@"
        ;;
    rebuild)
        prepare_fast_image true
        ;;
    shell)
        open_shell
        ;;
    *)
        echo "Usage: $0 [fast|full|rebuild|shell] [bats args...]" >&2
        exit 1
        ;;
esac

echo "[setmeup] Tests complete."
