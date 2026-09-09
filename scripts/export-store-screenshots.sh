#!/bin/zsh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/store-screenshots"
DERIVED="${TMPDIR:-/tmp}/jipin-store-screenshots"
BUNDLE="com.jipin.JiPin"

mkdir -p "$OUT"

device_udid() {
  local name="$1"
  xcrun simctl list devices available | grep "$name (" | head -n 1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

echo "Building Debug simulator app"
xcodebuild -project "$ROOT/JiPin.xcodeproj" -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED" build
APP="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -name 'JiPin.app' -maxdepth 2 | head -n 1)"

capture_device() {
  local dest_name="$1"
  local prefix="$2"
  local udid
  udid="$(device_udid "$dest_name")"
  if [[ -z "$udid" ]]; then
    echo "missing simulator: $dest_name" >&2
    return 1
  fi

  echo "Capturing $dest_name ($udid)"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$APP"

  capture() {
    local file="$1"
    shift
    xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE" "$@" >/dev/null
    sleep 3
    xcrun simctl io "$udid" screenshot "$OUT/${prefix}-${file}.png"
  }

  capture "01-create-home"
  capture "02-editor-template" -sampleEditor -sampleMode template
  capture "03-editor-freeform" -sampleEditor -sampleMode freeform
  capture "04-editor-poster" -sampleEditor -sampleMode poster
  capture "05-quick-collage" -quickCollage
  capture "06-settings" -showSettings
}

capture_device "iPhone 17 Pro Max" "6.9in"
capture_device "iPhone 17" "6.3in"

echo "Wrote screenshots to $OUT"
ls -lh "$OUT"
