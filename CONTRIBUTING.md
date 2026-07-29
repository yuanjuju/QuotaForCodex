# Contributing

感谢你帮助改进 Quota for Codex。

## 开始之前

1. Fork 仓库并创建功能分支。
2. 安装 macOS 14+、完整 Xcode 和 XcodeGen。
3. 如果默认 Bundle ID 无法签名，运行：

   ```bash
   ./scripts/configure-identifiers.sh com.yourname
   ```

4. 运行测试：

   ```bash
   ./scripts/bootstrap.sh
   ```

## 工程约定

- `project.yml` 是 Xcode 工程配置的来源；不要只手动修改生成后的 `project.pbxproj`。
- 共享模型和 Codex 协议代码放在 `Sources/QuotaCore`。
- Widget Extension 只读取 App Group 快照，不直接启动 Codex 进程。
- 不要读取、记录或提交 Codex 登录凭证和账号响应原文。
- 协议解析变更应包含假的 app-server 测试，不应要求 CI 使用真实 Codex 账号。
- UI 变更应检查小号、中号、浅色、深色和无数据状态。

## Pull Request

请在 PR 中说明：

- 变更目的和用户可见效果。
- 已运行的测试。
- Widget UI 变更前后的截图（如适用）。
- 是否影响 Codex app-server 协议兼容性或本地数据格式。
