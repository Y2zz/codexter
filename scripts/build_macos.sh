#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_ANALYZE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-analyze) SKIP_ANALYZE=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

VERSION="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml | head -n1 | tr -d '\r')"
if [[ -z "$VERSION" ]]; then
  echo "Failed to read version from pubspec.yaml" >&2
  exit 1
fi

echo "==> Building Codexter $VERSION for macOS"
flutter pub get
if [[ "$SKIP_ANALYZE" -eq 0 ]]; then
  dart format --output=none --set-exit-if-changed .
  flutter analyze
  flutter test
fi

flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/Codexter.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing build product: $APP_PATH" >&2
  exit 1
fi

DIST_DIR="dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="Codexter-$VERSION-macos-arm64.zip"
# Prefer arm64 name on Apple Silicon runners; fall back to generic if needed.
ARCH="$(uname -m)"
if [[ "$ARCH" == "x86_64" ]]; then
  ZIP_NAME="Codexter-$VERSION-macos-x64.zip"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/$ZIP_NAME"
echo "==> Wrote $DIST_DIR/$ZIP_NAME"
