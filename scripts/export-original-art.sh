#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
repository_dir="$(cd "$(dirname "$0")/.." && pwd)"
art_temp_dir="$(mktemp -d /private/tmp/jipin-art.XXXXXX)"
trap 'rm -rf -- "$art_temp_dir"' EXIT
source_dir="$repository_dir/Packages/JiPinCore/Sources/JiPinCore"
xcrun --sdk macosx swiftc -swift-version 5 -o "$art_temp_dir/export" \
  "$source_dir/Models.swift" "$source_dir/Constants.swift" "$source_dir/AssetCatalogs.swift" \
  "$source_dir/OriginalStickerArt.swift" "$source_dir/DecorationFrames.swift" \
  "$repository_dir/scripts/export-original-art.swift"
"$art_temp_dir/export" "$repository_dir/docs/design-source/originals"
