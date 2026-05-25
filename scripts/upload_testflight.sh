#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/private/testflight.env"
PROJECT_PATH="${ROOT_DIR}/Tennitus.xcodeproj"
SCHEME="Tennitus"
CONFIGURATION="Release"
TEAM_ID="533TNBFYQ3"
BUNDLE_ID="com.avinashkannan.tennitus"
DEVELOPER_DIR_PATH="/Applications/Xcode.app/Contents/Developer"
BUILD_ROOT="/private/tmp/TennitusTestFlight"
ARCHIVE_PATH="${BUILD_ROOT}/Tennitus.xcarchive"
EXPORT_PATH="${BUILD_ROOT}/Export"
EXPORT_OPTIONS_PLIST="${BUILD_ROOT}/ExportOptions.plist"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  cat >&2 <<EOF
Missing ${CONFIG_FILE}

Create it with:
ASC_KEY_ID=your-key-id
ASC_ISSUER_ID=your-issuer-id
ASC_KEY_PATH=private/AuthKey_<key-id>.p8
EOF
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${CONFIG_FILE}"
set +a

: "${ASC_KEY_ID:?ASC_KEY_ID is required in private/testflight.env}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required in private/testflight.env}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH is required in private/testflight.env}"

if [[ "${ASC_KEY_PATH}" != /* ]]; then
  ASC_KEY_PATH="${ROOT_DIR}/${ASC_KEY_PATH}"
fi

if [[ ! -f "${ASC_KEY_PATH}" ]]; then
  echo "Missing App Store Connect key file: ${ASC_KEY_PATH}" >&2
  exit 1
fi

export DEVELOPER_DIR="${DEVELOPER_DIR_PATH}"

if [[ "${1:-}" == "--increment-build" ]]; then
  /usr/bin/python3 - "${ROOT_DIR}/Tennitus.xcodeproj/project.pbxproj" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
versions = [int(match) for match in re.findall(r"CURRENT_PROJECT_VERSION = ([0-9]+);", text)]
if not versions:
    raise SystemExit("CURRENT_PROJECT_VERSION not found")
next_version = max(versions) + 1
text = re.sub(r"CURRENT_PROJECT_VERSION = [0-9]+;", f"CURRENT_PROJECT_VERSION = {next_version};", text)
path.write_text(text)
print(f"Set build number to {next_version}")
PY
fi

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}" "${EXPORT_PATH}"

cat > "${EXPORT_OPTIONS_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>uploadSymbols</key>
  <true/>
  <key>testFlightInternalTestingOnly</key>
  <false/>
</dict>
</plist>
EOF

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  -archivePath "${ARCHIVE_PATH}" \
  archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${ASC_KEY_PATH}" \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}"

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -allowProvisioningUpdates

echo "Uploaded ${BUNDLE_ID} to App Store Connect / TestFlight."
