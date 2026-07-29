#!/bin/zsh
set -euo pipefail

quota_script_dir="${0:A:h}"
quota_project_root="${quota_script_dir:h}"
quota_host_arch="$(uname -m)"
quota_derived_data="${TMPDIR%/}/QuotaForCodexLocalInstall"
quota_built_app="$quota_derived_data/Build/Products/Debug/Quota for Codex.app"
quota_built_widget="$quota_built_app/Contents/PlugIns/Quota for Codex Widget.appex"
quota_installed_app="$HOME/Applications/Quota for Codex.app"
quota_widget="$quota_installed_app/Contents/PlugIns/Quota for Codex Widget.appex"
quota_team_id="${APPLE_TEAM_ID:-}"

cd "$quota_project_root"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 XcodeGen，请先运行：brew install xcodegen" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "需要安装并启用完整 Xcode。" >&2
  exit 1
fi

if [[ -z "$quota_team_id" && -d "$quota_installed_app" ]]; then
  quota_team_id="$(
    codesign -d --entitlements :- "$quota_installed_app" 2>/dev/null \
      | sed -n 's|.*<key>com.apple.developer.team-identifier</key><string>\([^<]*\)</string>.*|\1|p'
  )"
fi

if [[ -z "$quota_team_id" ]]; then
  quota_team_id="$(
    security find-certificate -a -c "Apple Development" -p 2>/dev/null \
      | openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
      | awk -F' = ' '/organizationalUnitName/ { gsub(/[[:space:]]/, "", $2); print $2; exit }'
  )"
fi

if ! print -r -- "$quota_team_id" | grep -Eq '^[A-Z0-9]{10}$'; then
  echo "无法自动识别 Apple Developer Team ID。" >&2
  echo "请在 Xcode -> Settings -> Accounts 登录 Apple ID，然后运行：" >&2
  echo "APPLE_TEAM_ID=你的TeamID ./scripts/install-local.sh" >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project QuotaForCodex.xcodeproj \
  -scheme QuotaForCodex \
  -configuration Debug \
  -destination "platform=macOS,arch=$quota_host_arch" \
  -derivedDataPath "$quota_derived_data" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$quota_team_id" \
  build

codesign --verify --deep --strict --verbose=2 "$quota_built_app"

osascript -e 'tell application id "com.jinian.QuotaForCodex" to quit' \
  >/dev/null 2>&1 || true

mkdir -p "$HOME/Applications"
ditto "$quota_built_app" "$quota_installed_app"

codesign --verify --deep --strict --verbose=2 "$quota_installed_app"

quota_lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
"$quota_lsregister" -f -R -trusted "$quota_installed_app"
pluginkit -a "$quota_widget"
pluginkit -r "$quota_built_widget" >/dev/null 2>&1 || true
"$quota_lsregister" -u "$quota_built_app" >/dev/null 2>&1 || true
open -n "$quota_installed_app"

echo
echo "安装完成：$quota_installed_app"
echo "现在可在桌面右键 -> 编辑小组件 -> 搜索 Quota for Codex。"
