#!/bin/sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="${ROOT_DIR}/AurelienApp"
PROJECT_FILE="${ROOT_DIR}/Aurelien.xcodeproj/project.pbxproj"
INFO_PLIST="${APP_DIR}/Sources/Support/Info.plist"
PRIVACY_MANIFEST="${APP_DIR}/Resources/PrivacyInfo.xcprivacy"

fail() {
  echo "error: $1"
  exit 1
}

warn() {
  echo "warning: $1"
}

require_file() {
  [ -f "$1" ] || fail "Missing required file: $1"
}

require_https_url() {
  name="$1"
  value="$2"

  [ -n "$value" ] || fail "$name must be set."
  case "$value" in
    https://*) ;;
    *) fail "$name must use https:// for App Store/TestFlight builds." ;;
  esac
}

require_live_url() {
  name="$1"
  value="$2"

  require_https_url "$name" "$value"
  status="$(curl -L -s -o /dev/null -w "%{http_code}" "$value" || true)"
  case "$status" in
    200|204|301|302) ;;
    *) fail "$name did not return a reviewable HTTP response. URL: $value status: $status" ;;
  esac
}

require_file "$PROJECT_FILE"
require_file "$INFO_PLIST"
require_file "$PRIVACY_MANIFEST"

plutil -lint "$INFO_PLIST" >/dev/null
plutil -lint "$PRIVACY_MANIFEST" >/dev/null

grep -q "PrivacyInfo.xcprivacy in Resources" "$PROJECT_FILE" ||
  fail "PrivacyInfo.xcprivacy is not listed in the app target resources."

if grep -q 'DEVELOPMENT_ASSET_PATHS = "\\"AurelienApp/Resources\\""' "$PROJECT_FILE"; then
  fail "AurelienApp/Resources is marked as development-only assets. This strips real resources from device archives."
fi

privacy_api_type="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "$PRIVACY_MANIFEST" 2>/dev/null || true)"
privacy_reason="$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "$PRIVACY_MANIFEST" 2>/dev/null || true)"

[ "$privacy_api_type" = "NSPrivacyAccessedAPICategoryUserDefaults" ] ||
  fail "Privacy manifest must declare UserDefaults required-reason API usage."
[ "$privacy_reason" = "CA92.1" ] ||
  fail "Privacy manifest must declare UserDefaults reason CA92.1 for app-scoped settings."

if /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity" "$INFO_PLIST" >/dev/null 2>&1; then
  fail "Info.plist contains NSAppTransportSecurity. Remove localhost/development ATS exceptions before App Store upload."
fi

if /usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" "$INFO_PLIST" >/dev/null 2>&1 ||
   /usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" "$INFO_PLIST" >/dev/null 2>&1 ||
   /usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryAddUsageDescription" "$INFO_PLIST" >/dev/null 2>&1; then
  warn "Info.plist contains camera/photo permission strings. Confirm these match reachable release features."
fi

iphone_orientations="$(/usr/libexec/PlistBuddy -c "Print :UISupportedInterfaceOrientations" "$INFO_PLIST" 2>/dev/null || true)"
echo "$iphone_orientations" | grep -q "UIInterfaceOrientationPortrait" ||
  fail "iPhone portrait orientation is not declared."
if echo "$iphone_orientations" | grep -q "Landscape"; then
  fail "iPhone landscape orientation is enabled. Ship portrait-only unless landscape QA is complete."
fi

require_https_url "AURELIEN_API_BASE_URL" "${AURELIEN_API_BASE_URL:-}"
require_https_url "AURELIEN_STATIC_CONTENT_BASE_URL" "${AURELIEN_STATIC_CONTENT_BASE_URL:-}"
require_live_url "BOUTIQUE_PRIVACY_POLICY_URL" "${BOUTIQUE_PRIVACY_POLICY_URL:-}"
require_live_url "BOUTIQUE_SUPPORT_URL" "${BOUTIQUE_SUPPORT_URL:-}"

api_status="$(curl -L -s -o /dev/null -w "%{http_code}" "${AURELIEN_API_BASE_URL%/}/products" || true)"
[ "$api_status" = "200" ] ||
  fail "Production product API must return 200 before TestFlight QA. Status: $api_status"

if ! xcodebuild -version >/dev/null 2>&1; then
  fail "xcodebuild is not available."
fi

if ! rg -q "Delete Account|Account Deletion|deleteCurrentAccount|/account/delete" "${APP_DIR}/Sources" "${APP_DIR}/Tests"; then
  fail "Account deletion surface or backend call was not found in app source/tests."
fi

echo "Phase 8 readiness checks passed."
