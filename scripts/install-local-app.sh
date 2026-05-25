#!/usr/bin/env bash
set -euo pipefail

PROJECT="pulse.xcodeproj"
SCHEME="pulse"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCT_APP_NAME="pulse.app"
INSTALL_APP_NAME="Pulse.app"
BUNDLE_ID="com.timelikesilver.pulse"

BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/pulse-local-install}"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
INSTALL_APP_PATH="$INSTALL_DIR/$INSTALL_APP_NAME"

log() {
  printf '==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

command -v xcodebuild >/dev/null 2>&1 || fail "Missing required command: xcodebuild"
command -v ditto >/dev/null 2>&1 || fail "Missing required command: ditto"
command -v codesign >/dev/null 2>&1 || fail "Missing required command: codesign"

[[ -d "$PROJECT" ]] || fail "Run this script from the repository root."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 ]] || fail "--configuration requires a value"
      CONFIGURATION="$2"
      shift 2
      ;;
    --configuration=*)
      CONFIGURATION="${1#*=}"
      shift
      ;;
    Debug|Release)
      CONFIGURATION="$1"
      shift
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

case "$CONFIGURATION" in
  Debug|Release) ;;
  *) fail "Unsupported configuration: $CONFIGURATION" ;;
esac

PRODUCT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$PRODUCT_APP_NAME"

log "Building $CONFIGURATION app"
rm -rf "$DERIVED_DATA_PATH"
export COPYFILE_DISABLE=1
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  build

[[ -d "$PRODUCT_APP_PATH" ]] || fail "Expected app was not built: $PRODUCT_APP_PATH"

log "Stopping any running Pulse instance"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 1
pkill -x "pulse" >/dev/null 2>&1 || true

log "Installing to $INSTALL_APP_PATH"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_APP_PATH"
ditto "$PRODUCT_APP_PATH" "$INSTALL_APP_PATH"

log "Verifying installed signature"
codesign --verify --deep --strict --verbose=2 "$INSTALL_APP_PATH"

log "Opening installed app"
open "$INSTALL_APP_PATH"

log "Installed"
printf '%s\n' "$INSTALL_APP_PATH"
