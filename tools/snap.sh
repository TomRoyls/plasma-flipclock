#!/usr/bin/env bash
# Render a component from package/contents/ui to a PNG.
#   tools/snap.sh FlipClock.qml 996 566 tools/out/scene.png
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT/package/contents/ui"

export QT_SCALE_FACTOR=1
export QT_ENABLE_HIGHDPI_SCALING=0
export QT_SCREEN_SCALE_FACTORS=

mkdir -p "$(dirname "${4:-$ROOT/tools/out/x.png}")"

# Loader.source resolves relative to Snap.qml's own directory, not to -I (which
# only affects module imports), so hand it an absolute path.
COMPONENT="$1"
[[ "$COMPONENT" = /* ]] || COMPONENT="$ROOT/tools/probes/$COMPONENT"; [ -f "$COMPONENT" ] || COMPONENT="$UI/$1"
shift

# Render on the live session by default.
#
# QT_QPA_PLATFORM=offscreen is NOT usable here: it runs, exits 0 and writes a
# PNG, but every ShaderEffect silently renders nothing -- so the gradient-filled
# digits and the card glows just vanish and the diff looks catastrophically
# wrong for the wrong reason. Verified with tools/Snap.qml on Probe3: identical
# scene, digits present under wayland, absent under offscreen.
# The software backend is worse still (no ShaderEffect implementation at all).
PLATFORM="${FLIPCLOCK_QPA:-${XDG_SESSION_TYPE:-wayland}}"

exec env QT_QPA_PLATFORM="$PLATFORM" \
    qml6 -I "$UI" "$ROOT/tools/Snap.qml" -- "$COMPONENT" "$@"
