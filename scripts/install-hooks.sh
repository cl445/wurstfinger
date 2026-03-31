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
        RESOLVED_GIT_DIR="$(cd "$REPO_ROOT/$GIT_DIR" 2>/dev/null && pwd)" || {
            echo "error: cannot resolve gitdir path: $REPO_ROOT/$GIT_DIR"
            exit 1
        }
        HOOKS_DIR="$RESOLVED_GIT_DIR/hooks"
    fi
fi

mkdir -p "$HOOKS_DIR"

if [ ! -f "$REPO_ROOT/scripts/pre-commit" ]; then
    echo "error: scripts/pre-commit not found"
    exit 1
fi

if [ -e "$HOOKS_DIR/pre-commit" ] && [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    echo "warning: overwriting existing pre-commit hook (was not a symlink)"
fi

ln -sf "$REPO_ROOT/scripts/pre-commit" "$HOOKS_DIR/pre-commit"
echo "Installed pre-commit hook to $HOOKS_DIR/pre-commit"
