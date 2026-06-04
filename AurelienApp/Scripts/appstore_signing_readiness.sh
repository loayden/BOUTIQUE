#!/bin/sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ROOT_DIR}/build/Aurelien-AppStore.xcarchive}"
EXPORT_PLIST="${ROOT_DIR}/AurelienApp/Release/TestFlightUploadOptions.plist"

fail() {
  echo "error: $1"
  exit 1
}

warn() {
  echo "warning: $1"
}

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not available."
command -v security >/dev/null 2>&1 || fail "security command is not available."

[ -f "$EXPORT_PLIST" ] || fail "Missing TestFlight export options: $EXPORT_PLIST"

identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if ! echo "$identities" | grep -Eq "Apple Distribution|iPhone Distribution"; then
  fail "No Apple Distribution signing identity was found in the local keychain. Add Apple Distribution signing before TestFlight export."
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
  warn "Archive not found at $ARCHIVE_PATH. Create it before export validation."
fi

if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] ||
   [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] ||
   [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ]; then
  [ -f "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] ||
    fail "APP_STORE_CONNECT_API_KEY_PATH is set but the key file was not found."
  [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] ||
    fail "APP_STORE_CONNECT_API_KEY_ID is required when using API-key upload."
  [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ] ||
    fail "APP_STORE_CONNECT_API_ISSUER_ID is required when using API-key upload."
  echo "App Store Connect API-key inputs are present."
else
  warn "No App Store Connect API-key inputs found. Xcode account provider access must be configured locally for export/upload."
fi

echo "Signing readiness checks passed."
