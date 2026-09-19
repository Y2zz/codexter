#!/usr/bin/env bash
set -euo pipefail

# 将 macOS zip 信息合并进 dist/latest.json（若不存在则创建最小清单）。
# 用法: ./scripts/patch_update_manifest_macos.sh <version> <tag> [repository]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:?version required}"
TAG="${2:?tag required}"
REPOSITORY="${3:-meesii/codexter}"
DIST_DIR="${DIST_DIR:-dist}"
ASSET_BASE_URL="${ASSET_BASE_URL:-https://github.com/$REPOSITORY/releases/download/$TAG}"
ASSET_BASE_URL="${ASSET_BASE_URL%/}"

shopt -s nullglob
zips=("$DIST_DIR"/Codexter-"$VERSION"-macos-*.zip)
if [[ ${#zips[@]} -eq 0 ]]; then
  echo "No macOS zip found in $DIST_DIR" >&2
  exit 1
fi
ZIP_PATH="${zips[0]}"
ZIP_NAME="$(basename "$ZIP_PATH")"
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
URL="$ASSET_BASE_URL/$ZIP_NAME"
MANIFEST="$DIST_DIR/latest.json"
PUBLISHED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

python3 - "$MANIFEST" "$VERSION" "$TAG" "$REPOSITORY" "$URL" "$SHA" "$PUBLISHED_AT" <<'PY'
import json, sys
from pathlib import Path

manifest_path, version, tag, repo, url, sha, published_at = sys.argv[1:]
path = Path(manifest_path)
if path.exists():
    data = json.loads(path.read_text(encoding='utf-8'))
else:
    data = {
        "schema": 1,
        "version": version,
        "tag": tag,
        "published_at": published_at,
        "release_url": f"https://github.com/{repo}/releases/tag/{tag}",
    }

data["version"] = version
data["tag"] = tag
data.setdefault("release_url", f"https://github.com/{repo}/releases/tag/{tag}")
data["macos"] = {
    "installer_url": url,
    "installer_sha256": sha,
    "portable_url": url,
    "portable_sha256": sha,
}
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"==> Patched macOS update manifest: {path}")
PY
