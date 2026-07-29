#!/bin/zsh
set -euo pipefail

quota_script_dir="${0:A:h}"
quota_project_root="${quota_script_dir:h}"
cd "$quota_project_root"

: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to the Apple Developer team identifier}"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to the full signing identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"

quota_release_version="${RELEASE_VERSION:-0.1.0}"
quota_release_tmp="$(mktemp -d /tmp/quota-for-codex-release.XXXXXX)"
quota_archive_path="$quota_release_tmp/QuotaForCodex.xcarchive"
quota_export_path="$quota_release_tmp/export"
quota_export_options="$quota_release_tmp/ExportOptions.plist"
quota_output_dir="$quota_project_root/build/releases"
quota_dmg_path="$quota_output_dir/Quota-for-Codex-$quota_release_version.dmg"

mkdir -p "$quota_export_path" "$quota_output_dir"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Missing XcodeGen. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "A complete Xcode installation is required." >&2
  exit 1
fi

xcodegen generate

plutil -create xml1 "$quota_export_options"
/usr/libexec/PlistBuddy -c "Add :method string developer-id" "$quota_export_options"
/usr/libexec/PlistBuddy -c "Add :teamID string $APPLE_TEAM_ID" "$quota_export_options"
/usr/libexec/PlistBuddy -c "Add :signingStyle string manual" "$quota_export_options"
/usr/libexec/PlistBuddy -c "Add :signingCertificate string $DEVELOPER_ID_APPLICATION" "$quota_export_options"

xcodebuild archive \
  -project QuotaForCodex.xcodeproj \
  -scheme QuotaForCodex \
  -configuration Release \
  -archivePath "$quota_archive_path" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
  MARKETING_VERSION="$quota_release_version" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

xcodebuild -exportArchive \
  -archivePath "$quota_archive_path" \
  -exportPath "$quota_export_path" \
  -exportOptionsPlist "$quota_export_options"

quota_app_path="$quota_export_path/Quota for Codex.app"
if [[ ! -d "$quota_app_path" ]]; then
  echo "Exported app was not found at: $quota_app_path" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$quota_app_path"
spctl --assess --type execute --verbose=2 "$quota_app_path"

hdiutil create \
  -volname "Quota for Codex" \
  -srcfolder "$quota_app_path" \
  -format UDZO \
  -ov \
  "$quota_dmg_path"

xcrun notarytool submit \
  "$quota_dmg_path" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$quota_dmg_path"
xcrun stapler validate "$quota_dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$quota_dmg_path"

echo "Release created: $quota_dmg_path"
echo "Temporary archive retained at: $quota_release_tmp"
