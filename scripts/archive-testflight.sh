#!/bin/zsh
set -euo pipefail
umask 077

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
repository_dir="$(cd "$(dirname "$0")/.." && pwd)"
export_root="${JIPIN_EXPORT_ROOT:-$repository_dir/build/TestFlight/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$export_root"

xcodegen generate --spec "$repository_dir/project.yml" --project "$repository_dir"
xcodebuild -project "$repository_dir/JiPin.xcodeproj" -scheme JiPin \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$export_root/JiPin.xcarchive" \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath "$export_root/JiPin.xcarchive" \
  -exportPath "$export_root/Export" \
  -exportOptionsPlist "$repository_dir/scripts/ExportOptions-TestFlight.plist" \
  -allowProvisioningUpdates

print "已导出分发包：$export_root/Export/JiPin.ipa"
print "归档文件：$export_root/JiPin.xcarchive"
