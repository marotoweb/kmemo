#!/usr/bin/env bash
# Builds a portable AppImage of the Linux desktop app.
#
# The Flutter bundle keeps lib/ and data/ next to the executable (RPATH
# $ORIGIN/lib), so the AppDir stores it untouched under usr/bin and AppRun only
# has to start it from there.
#
# Usage: linux/package-appimage.sh [--no-build]
# Output: build/appimage/kMemo-<version>-x86_64.AppImage
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$BUILD" = 1 ]; then
  flutter build linux --release
fi

BUNDLE="build/linux/x64/release/bundle"
if [ ! -x "$BUNDLE/kmemo" ]; then
  echo "missing $BUNDLE/kmemo: run 'flutter build linux --release'" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*\([^+ ]*\).*/\1/p' pubspec.yaml | head -1)"
if [ -z "$VERSION" ]; then
  echo "could not read the version from pubspec.yaml" >&2
  exit 1
fi

APPIMAGETOOL="${APPIMAGETOOL:-$HOME/.cache/kmemo/appimagetool}"
if [ ! -x "$APPIMAGETOOL" ]; then
  mkdir -p "$(dirname "$APPIMAGETOOL")"
  echo "downloading appimagetool to $APPIMAGETOOL"
  curl -sSL -o "$APPIMAGETOOL" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$APPIMAGETOOL"
fi

# appimagetool is itself an AppImage: without FUSE (containers, some CI
# images) it has to unpack itself before it can run.
appimagetool() {
  if [ -e /dev/fuse ] && command -v fusermount >/dev/null 2>&1; then
    "$APPIMAGETOOL" "$@"
  else
    "$APPIMAGETOOL" --appimage-extract-and-run "$@"
  fi
}

APPDIR="build/appimage/kMemo.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/672x672/apps"

# The bundle as Flutter produced it: kmemo + lib/ + data/.
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"

# libsecret backs the secure storage plugin and is not installed on every
# desktop (a bare window manager often has no keyring). Without it the plugin's
# .so fails to load and the dynamic loader aborts the app before main(), so it
# travels with the AppImage, together with its two small dependencies. GTK and
# GLib are left to the system: they are what the window itself needs.
for name in libsecret-1.so.0 libgcrypt.so.20 libgpg-error.so.0; do
  path="$(ldconfig -p | awk -v n="$name" '$1 == n {print $NF; exit}')"
  if [ -n "$path" ]; then
    cp -L "$path" "$APPDIR/usr/bin/lib/"
    echo "bundled $(basename "$path")"
  else
    echo "warning: $name not found; the AppImage will need it on the host" >&2
  fi
done

cp assets/icon/icon.png "$APPDIR/kmemo.png"
cp assets/icon/icon.png "$APPDIR/usr/share/icons/hicolor/672x672/apps/kmemo.png"

cat > "$APPDIR/kmemo.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=kMemo
Comment=Offline-first, block-based notes with kDrive and WebDAV sync
Exec=kmemo
Icon=kmemo
Terminal=false
Categories=Office;
StartupWMClass=com.marotoweb.kmemo
DESKTOP
cp "$APPDIR/kmemo.desktop" "$APPDIR/usr/share/applications/kmemo.desktop"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
# lib/ and data/ must stay next to the executable, which is how the Flutter
# bundle is laid out and what its RPATH ($ORIGIN/lib) expects.
#
# LD_LIBRARY_PATH also covers the libraries a bundled library loads itself
# (libsecret needs libgcrypt, and libsecret's own RUNPATH is the host's).
HERE="$(dirname "$(readlink -f "$0")")"
LD_LIBRARY_PATH="$HERE/usr/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
exec "$HERE/usr/bin/kmemo" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

OUT="build/appimage/kMemo-$VERSION-x86_64.AppImage"
# Write next to the final name and rename at the end: overwriting an AppImage
# that is currently running fails with "Text file busy", while replacing the
# directory entry is fine.
STAGED="$OUT.tmp"
rm -f "$STAGED"
ARCH=x86_64 appimagetool --no-appstream "$APPDIR" "$STAGED"
mv -f "$STAGED" "$OUT"

echo
echo "built $OUT"
