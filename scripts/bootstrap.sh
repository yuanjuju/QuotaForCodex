#!/bin/zsh
set -euo pipefail

quota_script_dir="${0:A:h}"
quota_project_root="${quota_script_dir:h}"
quota_derived_data="${TMPDIR%/}/QuotaForCodexDerivedData"
quota_host_arch="$(uname -m)"
cd "$quota_project_root"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Missing XcodeGen. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "A complete Xcode installation is required." >&2
  echo "After installing Xcode, select it with xcode-select." >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project QuotaForCodex.xcodeproj \
  -scheme QuotaForCodex \
  -destination "platform=macOS,arch=$quota_host_arch" \
  -derivedDataPath "$quota_derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  test
