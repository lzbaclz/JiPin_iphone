#!/bin/zsh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
repository_dir="$(cd "$(dirname "$0")/.." && pwd)"
catalog_tmp_dir="$(mktemp -d /private/tmp/jipin-design-export.XXXXXX)"
trap 'rm -rf -- "$catalog_tmp_dir"' EXIT
source_dir="$repository_dir/Packages/JiPinCore/Sources/JiPinCore"

xcrun --sdk macosx swiftc -swift-version 5 -o "$catalog_tmp_dir/export" \
  "$source_dir/Models.swift" "$source_dir/Constants.swift" \
  "$source_dir/LayoutEngine.swift" "$source_dir/LayoutIntelligence.swift" "$source_dir/PosterTemplates.swift" \
  "$source_dir/AssetCatalogs.swift" "$source_dir/StyleRecipes.swift" "$source_dir/OriginalStickerArt.swift" "$source_dir/DecorationFrames.swift" "$repository_dir/scripts/export-design-assets.swift"
"$catalog_tmp_dir/export" "$repository_dir/docs/design-source/catalog.json"
