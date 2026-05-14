#!/usr/bin/env bash
set -euo pipefail

PROJECT="pulse.xcodeproj"
SCHEME="pulse"
CONFIGURATION="Release"
TEAM_ID="MC3B24FK47"
DEVELOPER_ID_NAME="Developer ID Application: Yinshi (Chengdu) Technology Co., Ltd ($TEAM_ID)"
PRODUCT_APP_NAME="pulse.app"
INSTALL_APP_NAME="Pulse.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-pulse-notary}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-com.timelikesilver.pulse}"

BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/pulse-distribution}"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
ARCHIVE_PATH="$BUILD_ROOT/pulse.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
DMG_ROOT="$BUILD_ROOT/dmg-root"
APPCAST_INPUT_PATH="$BUILD_ROOT/appcast-input"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"

log() {
  printf '==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_command codesign
require_command ditto
require_command hdiutil
require_command shasum
require_command spctl
require_command xcodebuild
require_command xcrun

[[ -d "$PROJECT" ]] || fail "Run this script from the repository root."
export COPYFILE_DISABLE=1

BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null)"
MARKETING_VERSION="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F'= ' '/MARKETING_VERSION = / { print $2; exit }')"
BUILD_NUMBER="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F'= ' '/CURRENT_PROJECT_VERSION = / { print $2; exit }')"
[[ -n "$MARKETING_VERSION" ]] || fail "Could not read MARKETING_VERSION"
[[ -n "$BUILD_NUMBER" ]] || fail "Could not read CURRENT_PROJECT_VERSION"

DMG_NAME="Pulse-$MARKETING_VERSION.dmg"
DMG_PATH="$APPCAST_INPUT_PATH/$DMG_NAME"
SIGNATURE_OUTPUT="$APPCAST_INPUT_PATH/Pulse-$MARKETING_VERSION.signature.txt"
SHA_OUTPUT="$APPCAST_INPUT_PATH/Pulse-$MARKETING_VERSION.sha256.txt"

log "Checking Developer ID identity"
security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID_NAME" \
  || fail "No Developer ID Application certificate found for team $TEAM_ID"

log "Checking notarization profile $NOTARY_PROFILE"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --team-id "$TEAM_ID" >/dev/null

log "Removing source metadata that cannot be code signed"
xattr -cr pulse

log "Preparing export options"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_ROOT" "$APPCAST_INPUT_PATH" "$DERIVED_DATA_PATH"
mkdir -p "$BUILD_ROOT" "$APPCAST_INPUT_PATH"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

log "Archiving $SCHEME $MARKETING_VERSION ($BUILD_NUMBER)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

log "Exporting Developer ID signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

EXPORTED_APP_PATH="$EXPORT_PATH/$PRODUCT_APP_NAME"
[[ -d "$EXPORTED_APP_PATH" ]] || fail "Expected exported app not found: $EXPORTED_APP_PATH"

log "Verifying exported app signature"
codesign --verify --deep --strict --verbose=2 "$EXPORTED_APP_PATH"

log "Creating DMG"
mkdir -p "$DMG_ROOT"
ditto "$EXPORTED_APP_PATH" "$DMG_ROOT/$INSTALL_APP_NAME"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Pulse" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
codesign --force --sign "$DEVELOPER_ID_NAME" --timestamp "$DMG_PATH"

log "Submitting DMG to Apple notary service"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --team-id "$TEAM_ID" --wait

log "Stapling and validating notarization"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

SIGN_UPDATE="$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "$SIGN_UPDATE" ]] || fail "Sparkle sign_update not found: $SIGN_UPDATE"

log "Signing DMG for Sparkle account $SPARKLE_ACCOUNT"
"$SIGN_UPDATE" --account "$SPARKLE_ACCOUNT" "$DMG_PATH" > "$SIGNATURE_OUTPUT"
shasum -a 256 "$DMG_PATH" > "$SHA_OUTPUT"

log "Release artifact ready"
printf 'DMG: %s\n' "$DMG_PATH"
cat "$SIGNATURE_OUTPUT"
cat "$SHA_OUTPUT"
