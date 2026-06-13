import Darwin
import AppKit
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

    func testUninstallScanFindsExactBundleAndLibraryResiduals() throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let applicationURL = try makeApplication(
            named: "Widget.app",
            in: root,
            displayName: "Widget",
            bundleIdentifier: "com.example.widget"
        )
        let application = try XCTUnwrap(InstalledAppCatalog.application(at: applicationURL))
        let libraryURL = root.appendingPathComponent("Library", isDirectory: true)
        let expectedResiduals = try makeUninstallResiduals(
            libraryURL: libraryURL,
            bundleIdentifier: "com.example.widget",
            appName: "Widget"
        )
        let unrelatedURL = libraryURL
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("Widget Helper", isDirectory: true)
        try FileManager.default.createDirectory(at: unrelatedURL, withIntermediateDirectories: true)

        let scan = try ApplicationUninstallScanner.scan(
            application: application,
            libraryURL: libraryURL
        )
        let candidatePaths = Set(scan.candidates.map { $0.url.path })

        XCTAssertTrue(candidatePaths.contains(applicationURL.standardizedFileURL.path))
        XCTAssertTrue(expectedResiduals.allSatisfy { candidatePaths.contains($0.standardizedFileURL.path) })
        XCTAssertFalse(candidatePaths.contains(unrelatedURL.standardizedFileURL.path))
        XCTAssertEqual(scan.candidates.first?.kind, .applicationBundle)
        XCTAssertEqual(scan.requiredCandidateIDs, [applicationURL.standardizedFileURL.path])
    }

    func testUninstallScanRejectsSystemApplications() throws {
        let application = InstalledApplication(
            name: "System Settings",
            bundleIdentifier: "com.apple.SystemSettings",
            version: "1",
            bundlePath: "/System/Applications/System Settings.app",
            source: .system
        )

        XCTAssertEqual(ApplicationUninstallPolicy.availability(for: application), .systemApplication)
        XCTAssertThrowsError(
            try ApplicationUninstallScanner.scan(application: application, libraryURL: nil)
        ) { error in
            XCTAssertEqual(error as? ApplicationUninstallError, .unsupported(.systemApplication))
        }
    }

    func testUninstallTrashFailureReasonRecognizesCocoaPermissionErrors() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.Code.fileWriteNoPermission.rawValue,
            userInfo: [:]
        )

        XCTAssertEqual(ApplicationUninstallTrashFailureReason.classify(error), .permissionDenied)
    }

    func testUninstallTrashFailureReasonRecognizesUnderlyingPermissionErrors() {
        let underlyingError = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(EACCES),
            userInfo: [:]
        )
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 0,
            userInfo: [NSUnderlyingErrorKey: underlyingError]
        )

        XCTAssertEqual(ApplicationUninstallTrashFailureReason.classify(error), .permissionDenied)
    }

    func testUninstallTrashFailureReasonTreatsOtherErrorsAsUnknown() {
        let error = NSError(domain: "ApplicationUninstallTests", code: 1, userInfo: [:])

        XCTAssertEqual(ApplicationUninstallTrashFailureReason.classify(error), .unknown)
    }

    @MainActor
    func testUninstallFlowUsesNormalWindowInsteadOfIslandPanelSheet() {
        let store = PulseStore(startSamplingImmediately: false, startClipboardImmediately: false)
        let controller = ApplicationUninstallWindowController()
        let application = InstalledApplication(
            name: "Widget",
            bundleIdentifier: "com.example.widget",
            version: "1",
            bundlePath: "/Applications/Widget.app",
            source: .local
        )

        controller.present(application: application, store: store)
        let windowIdentifier = NSUserInterfaceItemIdentifier("ApplicationUninstallWindow-\(application.id)")
        let window = NSApp.windows.first { $0.identifier == windowIdentifier }

        addTeardownBlock { @MainActor in
            window?.close()
        }

        XCTAssertNotNil(window)
        XCTAssertFalse(window is NSPanel)
        XCTAssertEqual(window?.level, .normal)
        XCTAssertTrue(window?.styleMask.contains(.titled) == true)
        XCTAssertTrue(window?.styleMask.contains(.closable) == true)
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

    private func makeUninstallResiduals(
        libraryURL: URL,
        bundleIdentifier: String,
        appName: String
    ) throws -> [URL] {
        let applicationSupportURL = libraryURL
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
        let cachesURL = libraryURL
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
        let preferencesURL = libraryURL
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
        let byHostURL = libraryURL
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("ByHost", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).123456.plist")
        let groupContainerURL = libraryURL
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent("TEAMID.\(bundleIdentifier)", isDirectory: true)
        let launchAgentURL = libraryURL
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).helper.plist")

        for url in [applicationSupportURL, cachesURL, groupContainerURL] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        for url in [preferencesURL, byHostURL, launchAgentURL] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("test".utf8).write(to: url)
        }

        return [
            applicationSupportURL,
            cachesURL,
            preferencesURL,
            byHostURL,
            groupContainerURL,
            launchAgentURL,
        ]
    }
}
