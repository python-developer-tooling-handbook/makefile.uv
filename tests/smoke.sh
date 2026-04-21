#!/usr/bin/env bash
# Smoke test: copies each example into a temp dir and exercises every target.
# Usage: tests/smoke.sh [basic|with-matrix|all]  (default: all)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WHICH="${1:-all}"

log() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
die() { printf '\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }

run_example() {
    local name="$1"; shift
    local extra_targets=("$@")

    local work
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' RETURN

    log "copying examples/$name -> $work"
    cp -R "$ROOT/examples/$name/." "$work/"
    cp "$ROOT/Makefile.uv" "$work/Makefile.uv"
    # Point the example's Makefile at the local copy instead of ../../Makefile.uv.
    # macOS sed requires -i '' while GNU sed does not — use a tmpfile to stay portable.
    sed 's|\.\./\.\./Makefile\.uv|Makefile.uv|' "$work/Makefile" > "$work/Makefile.tmp"
    mv "$work/Makefile.tmp" "$work/Makefile"

    cd "$work"

    log "$name: make help"
    make help

    log "$name: make sync"
    make sync
    [ -d .venv ] || die "$name: .venv not created by make sync"

    log "$name: make test"
    make test

    log "$name: make test-py3.12"
    make test-py3.12
    [ -d .venv-3.12 ] || die "$name: .venv-3.12 not created"

    log "$name: make test-all"
    make test-all

    if [ "$name" = "basic" ]; then
        log "$name: make lint / format / typecheck"
        make lint
        make format
        make typecheck

        log "$name: LOG_DIR captures per-env output"
        make clean
        make LOG_DIR=.logs test-py3.12
        [ -f .logs/py3.12.log ] || die "$name: LOG_DIR not written"
        grep -q "passed" .logs/py3.12.log || die "$name: LOG_DIR has no test output"
    fi

    # Guard: bash 3.2 (macOS default) treats empty-array expansion as unbound
    # under `set -u`.
    if [ "${#extra_targets[@]}" -gt 0 ]; then
        for tgt in "${extra_targets[@]}"; do
            log "$name: make $tgt"
            make "$tgt"
        done
    fi

    if [ "$name" = "with-matrix" ]; then
        log "$name: assert matrix cells resolved to distinct packaging versions"
        v23=$(.venv-cell-3.12-p23/bin/python -c 'import packaging; print(packaging.__version__)')
        v24=$(.venv-cell-3.12-p24/bin/python -c 'import packaging; print(packaging.__version__)')
        echo "  p23 cell: packaging==$v23"
        echo "  p24 cell: packaging==$v24"
        [ "$v23" != "$v24" ] || die "matrix cells resolved to the same packaging version ($v23) — the conflict block is not working"
        maj23=$(echo "$v23" | cut -d. -f1)
        maj24=$(echo "$v24" | cut -d. -f1)
        [ "$maj23" -lt 24 ] || die "p23 major is $maj23, expected <24"
        [ "$maj24" -ge 24 ] || die "p24 major is $maj24, expected >=24"
    fi

    log "$name: make clean"
    make clean
    [ ! -d .venv ] || die "$name: .venv still present after clean"
    [ ! -d .venv-3.12 ] || die "$name: .venv-3.12 still present after clean"

    cd "$ROOT"
}

case "$WHICH" in
    basic)       run_example basic ;;
    with-matrix) run_example with-matrix matrix ;;
    all)
        run_example basic
        run_example with-matrix matrix
        ;;
    *) die "unknown target: $WHICH (expected: basic|with-matrix|all)" ;;
esac

log "all smoke checks passed"
