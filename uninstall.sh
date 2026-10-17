#!/usr/bin/env bash
# Restore the most recent pre-glass desktop build.
# Usage:  ./uninstall.sh [path-to-hermes-agent]     (default: ~/.hermes/hermes-agent)
set -euo pipefail

HERMES_SRC="${1:-$HOME/.hermes/hermes-agent}"
RELEASE="$HERMES_SRC/apps/desktop/release"

BACKUP="$(ls -d "$RELEASE"/linux-unpacked.orig-* 2>/dev/null | sort | tail -1 || true)"
[ -n "$BACKUP" ] || { echo "No backup build found in $RELEASE" >&2; exit 1; }

rm -rf "$RELEASE/linux-unpacked"
mv "$BACKUP" "$RELEASE/linux-unpacked"
rm -f "$RELEASE/.linux-glass-installed"

echo "Restored $(basename "$BACKUP"). Quit and reopen Hermes."
echo "The patch commit stays on its git branch; 'git switch -' in $HERMES_SRC to leave it."
