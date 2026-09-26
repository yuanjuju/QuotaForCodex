# Verification Record

2026-09-26 在 macOS arm64 上核验，源码基线 `68241c1`。环境、各项结果和源码指纹见 [verification.json](verification.json)。本次新增展示文档没有改变产品源码。

| 验证层 | 结果 | 覆盖内容 |
| --- | --- | --- |
| Swift Package / XCTest | **9 passed, 0 failed** | RPC 初始化、响应/通知和超时；额度映射、用量聚合、快照读写 |
| QuotaSmoke | **Passed** | 独立 fake process 的 RPC、数据映射与文件存储 |
| Xcode Debug build | **Succeeded** | 主应用与 Widget Extension 编译、链接；关闭代码签名 |

## Test-to-contract map

| 测试 | 契约 |
| --- | --- |
| `CodexAppServerClientTests.testIntegration` | fake server 握手、额度与用量响应、通知事件 |
| `CodexAppServerClientTests.testTimeout` | 已完成初始化后，请求无响应时返回超时 |
| `DailyUsageTests.testZeroFill` | 七日窗口、重复日期求和、缺失日期补零 |
| `DailyUsageTests.testTokenScale` | tokens / K / M 展示单位 |
| `QuotaMapperTests.testOverallBucketWins` | 整体 codex 桶优先、短/周窗口映射 |
| `QuotaMapperTests.testMissingShortWindow` | 缺失短窗口保持缺失 |
| `QuotaMapperTests.testClampsPercentages` | 百分比输入边界处理 |
| `SnapshotStoreTests.testRoundTrip` | Codable JSON 保存/加载一致 |
| `SnapshotStoreTests.testMissingFile` | 文件不存在返回 nil |

测试源码在 [Tests/QuotaCoreTests](../Tests/QuotaCoreTests)，默认 CI 执行 [swift test](../.github/workflows/ci.yml)。9 项是 XCTest 用例数；日志末尾另一个 Swift Testing runner 的 0 tests 不表示 XCTest 没有执行。

## Re-run

```bash
swift test
swift run QuotaSmoke
xcodebuild -project QuotaForCodex.xcodeproj \
  -scheme QuotaForCodex -configuration Debug \
  -derivedDataPath .build/xcode-verification \
  CODE_SIGNING_ALLOWED=NO build
```

本次检查不读取真实账号，fake-server 通过只能证明所覆盖的本地协议路径。Unsigned Debug 编译不等于真实 Widget 交互、Developer ID 签名、公证或 Universal 2 发布验证。完整账户连接另有 `QuotaProbe`，发布链路另有 `scripts/release.sh`，两者未计入本次结果。
