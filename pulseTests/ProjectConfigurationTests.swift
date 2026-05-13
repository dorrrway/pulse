import XCTest

final class ProjectConfigurationTests: XCTestCase {
    func testHostAppInfoPlistKeepsMenuBarSingleInstanceConfiguration() {
        let infoDictionary = Bundle.main.infoDictionary

        XCTAssertEqual(infoDictionary?["CFBundleDisplayName"] as? String, "Pulse")
        XCTAssertEqual(infoDictionary?["LSUIElement"] as? Bool, true)
        XCTAssertEqual(infoDictionary?["LSMultipleInstancesProhibited"] as? Bool, true)
    }

    func testHostAppInfoPlistConfiguresSignedSparkleUpdatesWithoutSystemProfiling() {
        let infoDictionary = Bundle.main.infoDictionary

        XCTAssertEqual(
            infoDictionary?["SUFeedURL"] as? String,
            "https://raw.githubusercontent.com/dorrrway/pulse/main/appcast.xml"
        )
        XCTAssertEqual(
            infoDictionary?["SUPublicEDKey"] as? String,
            "jEAIxFtZ7Pa6nn7C/qM3JQVkz8b/8GNjMJVr7q2qTzM="
        )
        XCTAssertEqual(infoDictionary?["SUEnableAutomaticChecks"] as? Bool, false)
        XCTAssertEqual(infoDictionary?["SUEnableSystemProfiling"] as? Bool, false)
    }

    func testInfoPlistIsNotCopiedAsRuntimeResource() {
        let copiedResourceURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedResourceURL.path))
    }
}
