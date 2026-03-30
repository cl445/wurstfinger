#!/bin/bash
# Installs git hooks for the Wurstfinger project

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Handle worktrees: .git may be a file pointing to the actual git dir
if [ -f "$REPO_ROOT/.git" ]; then
    GIT_DIR=$(sed -n 's/^gitdir: //p' "$REPO_ROOT/.git" | head -n 1 | tr -d '\r')
    # Handle both absolute and relative paths
    if [[ "$GIT_DIR" = /* ]]; then
        HOOKS_DIR="$GIT_DIR/hooks"
    else
        HOOKS_DIR="$(cd "$REPO_ROOT/$GIT_DIR" && pwd)/hooks"
    fi
fi

mkdir -p "$HOOKS_DIR"

if [ ! -f "$REPO_ROOT/scripts/pre-commit" ]; then
    echo "error: scripts/pre-commit not found"
    exit 1
fi

ln -sf "$REPO_ROOT/scripts/pre-commit" "$HOOKS_DIR/pre-commit"
echo "Installed pre-commit hook to $HOOKS_DIR/pre-commit"
