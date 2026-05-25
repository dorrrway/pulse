import Foundation
import XCTest
@testable import pulse

final class InstalledAppCatalogTests: XCTestCase {
    func testDiscoversApplicationsFromStandardDirectoryTree() throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let utilitiesDirectory = root.appendingPathComponent("Utilities", isDirectory: true)
        try FileManager.default.createDirectory(at: utilitiesDirectory, withIntermediateDirectories: true)
        try makeApplication(
            named: "Zeta.app",
            in: root,
            displayName: "Zeta",
            bundleIdentifier: "com.example.zeta",
            shortVersion: "2.0"
        )
        try makeApplication(
            named: "Alpha.app",
            in: utilitiesDirectory,
            displayName: "Alpha",
            bundleIdentifier: "com.example.alpha",
            shortVersion: "1.0"
        )

        let applications = InstalledAppCatalog.applications(in: [root])

        XCTAssertEqual(applications.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(applications.first?.bundleIdentifier, "com.example.alpha")
        XCTAssertEqual(applications.first?.version, "1.0")
        XCTAssertEqual(applications.first?.source, .local)
    }

    func testSkipsNonApplicationBundles() throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try makeApplication(
            named: "Document.app",
            in: root,
            displayName: "Document",
            bundleIdentifier: "com.example.document",
            packageType: "BNDL"
        )

        XCTAssertTrue(InstalledAppCatalog.applications(in: [root]).isEmpty)
    }

    func testDeduplicatesApplicationsByBundlePath() throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let applicationURL = try makeApplication(
            named: "Pulse.app",
            in: root,
            displayName: "Pulse",
            bundleIdentifier: "com.timelikesilver.pulse"
        )

        let applications = InstalledAppCatalog.applications(in: [root, root])

        XCTAssertEqual(applications.count, 1)
        XCTAssertEqual(applications.first?.bundlePath, applicationURL.standardizedFileURL.path)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-installed-app-catalog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func makeApplication(
        named appName: String,
        in directory: URL,
        displayName: String,
        bundleIdentifier: String,
        shortVersion: String? = nil,
        packageType: String = "APPL"
    ) throws -> URL {
        let appURL = directory.appendingPathComponent(appName, isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        var info: [String: Any] = [
            "CFBundleDisplayName": displayName,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": displayName,
            "CFBundlePackageType": packageType,
            "CFBundleVersion": "1",
        ]
        if let shortVersion {
            info["CFBundleShortVersionString"] = shortVersion
        }

        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return appURL
    }
}
