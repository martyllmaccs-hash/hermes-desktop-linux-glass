#!/usr/bin/env bash
# Hermes Desktop — Linux glass patch installer.
#
# Applies the patch to a source install of Hermes Agent, builds the desktop app
# into a separate folder, then swaps it in (keeping the old build as a backup).
#
# Usage:  ./install.sh [path-to-hermes-agent]     (default: ~/.hermes/hermes-agent)
set -euo pipefail

HERMES_SRC="${1:-$HOME/.hermes/hermes-agent}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/patches/linux-glass-v0.22.2.patch"
DESKTOP="$HERMES_SRC/apps/desktop"
BRANCH="linux-glass"
STAMP="$(date +%Y%m%dT%H%M%S)"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "This patch is for Linux only."
[ -d "$DESKTOP" ] || die "No desktop app source at $DESKTOP (is this a source install?)"
command -v git >/dev/null || die "git is required"
command -v npm >/dev/null || die "node + npm are required to build the desktop app"

cd "$HERMES_SRC"

if git log --oneline -20 2>/dev/null | grep -q "Linux compositor glass"; then
  say "Patch already applied on this checkout — rebuilding only."
else
  [ -z "$(git status --porcelain)" ] || die "Hermes checkout has local changes. Commit or stash them first."
  say "Checking the patch applies to $(git describe --tags --always 2>/dev/null || echo this checkout)…"
  git apply --check "$PATCH" || die "Patch does not apply cleanly. It was made for v0.22.2; open an issue with your version."
  git switch -c "$BRANCH-$STAMP" >/dev/null
  git apply "$PATCH"
  git -c user.name="linux-glass" -c user.email="linux-glass@localhost" \
      commit -q --no-verify -am "desktop: Linux compositor glass (Hyprland + True Glass)"
  say "Patch applied on branch $BRANCH-$STAMP"
fi

say "Building the desktop app (a few minutes)…"
cd "$DESKTOP"
npm run build
npm run builder -- --dir --publish never -c.directories.output=release-glass

NEW="$DESKTOP/release-glass/linux-unpacked"
[ -x "$NEW/Hermes" ] || die "Build finished but $NEW/Hermes is missing."

if [ -d "$DESKTOP/release/linux-unpacked" ]; then
  mv "$DESKTOP/release/linux-unpacked" "$DESKTOP/release/linux-unpacked.orig-$STAMP"
  say "Old build kept at release/linux-unpacked.orig-$STAMP"
fi
mkdir -p "$DESKTOP/release"
cp -a "$NEW" "$DESKTOP/release/linux-unpacked"
echo "$STAMP" > "$DESKTOP/release/.linux-glass-installed"

# Window-level opacity rules fade text too — warn if one targets Hermes.
HYPR_HITS="$(grep -rns --include='*.lua' --include='*.conf' -A3 "nousresearch" "$HOME/.config/hypr" 2>/dev/null | grep -i "opacity" || true)"
if [ -n "$HYPR_HITS" ]; then
  warn "A Hyprland opacity rule for Hermes looks active in ~/.config/hypr."
  warn "It fades the text as well — remove it, the patch does real per-pixel glass:"
  printf '%s\n' "$HYPR_HITS" | sed 's/^/     /'
fi

cat <<'EOF'

Done. Now:
  1. Quit Hermes fully (tray → Quit, or Ctrl+Q) and open it again.
  2. Settings → Appearance → Window & layout → Window Translucency
  3. Choose "Glass" and raise "Tint". (Fade does nothing on Linux.)

Undo any time with ./uninstall.sh
EOF
