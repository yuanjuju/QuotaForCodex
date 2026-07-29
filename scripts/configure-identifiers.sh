#!/bin/zsh
set -euo pipefail

quota_script_dir="${0:A:h}"
quota_project_root="${quota_script_dir:h}"
quota_new_prefix="${1:-}"
quota_project_file="$quota_project_root/project.yml"

if ! print -r -- "$quota_new_prefix" \
  | grep -Eq '^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$'; then
  echo "用法：$0 com.yourname" >&2
  echo "前缀必须是反向域名格式，只能包含英文字母、数字和点。" >&2
  exit 1
fi

quota_old_prefix="$(
  awk '/bundleIdPrefix:/ { print $2; exit }' "$quota_project_file"
)"

if [[ -z "$quota_old_prefix" ]]; then
  echo "无法从 project.yml 读取当前 Bundle ID 前缀。" >&2
  exit 1
fi

if [[ "$quota_old_prefix" == "$quota_new_prefix" ]]; then
  echo "Bundle ID 前缀已经是：$quota_new_prefix"
  exit 0
fi

quota_files=(
  "$quota_project_file"
  "$quota_project_root/Config/App.entitlements"
  "$quota_project_root/Config/Widget.entitlements"
  "$quota_project_root/Sources/QuotaCore/Models.swift"
  "$quota_project_root/scripts/install-local.sh"
)

QUOTA_OLD_PREFIX="$quota_old_prefix" QUOTA_NEW_PREFIX="$quota_new_prefix" \
  perl -pi -e 's/\Q$ENV{QUOTA_OLD_PREFIX}\E/$ENV{QUOTA_NEW_PREFIX}/g' "${quota_files[@]}"

if command -v xcodegen >/dev/null 2>&1; then
  (
    cd "$quota_project_root"
    xcodegen generate
  )
fi

echo "Bundle ID 前缀已从 $quota_old_prefix 修改为 $quota_new_prefix。"
echo "请重新运行 ./scripts/install-local.sh。"
