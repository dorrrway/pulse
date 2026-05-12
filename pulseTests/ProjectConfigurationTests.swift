import XCTest

final class ProjectConfigurationTests: XCTestCase {
    func testHostAppInfoPlistKeepsMenuBarSingleInstanceConfiguration() {
        let infoDictionary = Bundle.main.infoDictionary

        XCTAssertEqual(infoDictionary?["CFBundleDisplayName"] as? String, "Pulse")
        XCTAssertEqual(infoDictionary?["LSUIElement"] as? Bool, true)
        XCTAssertEqual(infoDictionary?["LSMultipleInstancesProhibited"] as? Bool, true)
    }

    func testInfoPlistIsNotCopiedAsRuntimeResource() {
        let copiedResourceURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedResourceURL.path))
    }
}
