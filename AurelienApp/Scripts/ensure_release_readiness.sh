#!/bin/sh

set -eu

manifest_source="${SRCROOT}/AurelienApp/Resources/PrivacyInfo.xcprivacy"
manifest_destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/PrivacyInfo.xcprivacy"
stamp_file="${SCRIPT_OUTPUT_FILE_0:-}"

mkdir -p "$(dirname "${manifest_destination}")"

if [ ! -f "${manifest_source}" ]; then
  echo "error: Missing privacy manifest source at ${manifest_source}."
  exit 1
fi

cp "${manifest_source}" "${manifest_destination}"

if ! plutil -lint "${manifest_destination}" >/dev/null; then
  echo "error: Privacy manifest at ${manifest_destination} is not a valid property list."
  exit 1
fi

write_stamp() {
  if [ -n "${stamp_file}" ]; then
    mkdir -p "$(dirname "${stamp_file}")"
    touch "${stamp_file}"
  fi
}

if [ "${CONFIGURATION:-}" != "Release" ]; then
  write_stamp
  exit 0
fi

require_https_url() {
  setting_name="$1"
  setting_value="$2"

  if [ -z "${setting_value}" ]; then
    echo "error: ${setting_name} must be configured for Release builds."
    exit 1
  fi

  case "${setting_value}" in
    https://*)
      ;;
    *)
      echo "error: ${setting_name} must use an https:// URL for Release builds."
      exit 1
      ;;
  esac
}

require_https_url "AURELIEN_API_BASE_URL" "${AURELIEN_API_BASE_URL:-}"
require_https_url "AURELIEN_STATIC_CONTENT_BASE_URL" "${AURELIEN_STATIC_CONTENT_BASE_URL:-}"
require_https_url "BOUTIQUE_PRIVACY_POLICY_URL" "${BOUTIQUE_PRIVACY_POLICY_URL:-}"
require_https_url "BOUTIQUE_SUPPORT_URL" "${BOUTIQUE_SUPPORT_URL:-}"
write_stamp
