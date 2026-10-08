import XCTest
@testable import QuotaCore

final class CodexExecutableLocatorTests: XCTestCase {
    func testCandidatePathsPreferCustomAndIncludeCurrentDesktopLayout() {
        let paths = CodexExecutableLocator.candidatePaths(
            customPath: "/custom/codex",
            home: "/Users/tester",
            environment: ["PATH": "/usr/bin:/example/bin"]
        )

        XCTAssertEqual(paths.first, "/custom/codex")
        XCTAssertTrue(
            paths.contains(
                "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
            )
        )
        XCTAssertTrue(
            paths.contains(
                "/Users/tester/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex"
            )
        )
        XCTAssertTrue(paths.contains("/Applications/ChatGPT.app/Contents/Resources/codex"))
        XCTAssertTrue(paths.contains("/example/bin/codex"))
    }

    func testBlankCustomPathIsIgnored() {
        let paths = CodexExecutableLocator.candidatePaths(
            customPath: "   ",
            home: "/Users/tester",
            environment: [:]
        )

        XCTAssertFalse(paths.contains("   "))
    }
}
