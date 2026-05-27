import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import pulse

final class ProjectConfigurationTests: XCTestCase {
    func testHostAppInfoPlistKeepsAgentSingleInstanceConfiguration() {
        let infoDictionary = Bundle.main.infoDictionary

        XCTAssertEqual(infoDictionary?["CFBundleDisplayName"] as? String, "Pulse")
        XCTAssertEqual(infoDictionary?["LSUIElement"] as? Bool, true)
        XCTAssertEqual(infoDictionary?["LSMultipleInstancesProhibited"] as? Bool, true)
    }

    func testHostAppInfoPlistConfiguresSignedSparkleUpdatesWithoutSystemProfiling() {
        let infoDictionary = Bundle.main.infoDictionary

        XCTAssertEqual(
            infoDictionary?["SUFeedURL"] as? String,
            "https://www.timelikesilver.com/apps/pulse/appcast.xml"
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

    func testScreenshotModesUseNativeClipboardCaptureArguments() {
        XCTAssertEqual(PulseScreenshotService.arguments(for: .fullScreen), ["-c", "-i", "-w", "-S", "-x"])
        XCTAssertEqual(PulseScreenshotService.arguments(for: .window), ["-c", "-i", "-w", "-o", "-x"])
        XCTAssertEqual(PulseScreenshotService.arguments(for: .selection), ["-c", "-i", "-s", "-x"])
    }

    func testScreenshotModesUseAssetBackedIcons() {
        XCTAssertEqual(PulseScreenshotMode.fullScreen.iconAssetName, "ScreenshotFullScreenIcon")
        XCTAssertEqual(PulseScreenshotMode.window.iconAssetName, "ScreenshotWindowIcon")
        XCTAssertEqual(PulseScreenshotMode.selection.iconAssetName, "ScreenshotSelectionIcon")
    }

    func testScreenshotCaptureResultDetectsPermissionDenials() {
        XCTAssertEqual(
            PulseScreenshotService.captureResult(exitCode: 0, standardError: ""),
            .copiedToClipboard
        )
        XCTAssertEqual(
            PulseScreenshotService.captureResult(
                exitCode: 1,
                standardError: "screencapture: capture error could not create image from display"
            ),
            .permissionDenied
        )
        XCTAssertEqual(
            PulseScreenshotService.captureResult(exitCode: 1, standardError: "user canceled"),
            .cancelled
        )
    }

    @MainActor
    func testScreenshotPreviewImageReadsClipboardImage() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("pulse.screenshot.tests.\(UUID().uuidString)"))
        let image = NSImage(size: NSSize(width: 24, height: 16))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 16).fill()
        image.unlockFocus()

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))

        let previewImage = PulseIslandPanelController.screenshotPreviewImage(from: pasteboard)
        XCTAssertEqual(previewImage?.size, image.size)
    }

    @MainActor
    func testScreenshotPreviewDragProviderExposesPNGDataAndSuggestedName() {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])
        let provider = PulseIslandPanelController.screenshotPreviewDragItemProvider(
            pngData: pngData,
            suggestedFileName: "Pulse Screenshot Test.png"
        )
        let expectation = expectation(description: "loads PNG data")

        XCTAssertEqual(provider.suggestedName, "Pulse Screenshot Test.png")
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.png.identifier))
        provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, pngData)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    @MainActor
    func testScreenshotDragFileWritesPNGWithSuggestedName() throws {
        let fileManager = FileManager.default
        let pngData = Data([0x89, 0x50, 0x4E, 0x47])

        let fileURL = try PulseIslandPanelController.temporaryScreenshotDragFile(
            pngData: pngData,
            suggestedFileName: "Pulse Screenshot Drag Test",
            fileManager: fileManager
        )
        defer {
            try? fileManager.removeItem(at: fileURL.deletingLastPathComponent())
        }

        XCTAssertEqual(fileURL.lastPathComponent, "Pulse Screenshot Drag Test.png")
        XCTAssertEqual(try Data(contentsOf: fileURL), pngData)
    }

    func testPinnedScreenshotWindowSizePreservesAspectRatioWithinVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let imageContentSize = PulsePinnedScreenshotPanelLayout.imageContentSize(
            imageSize: CGSize(width: 2000, height: 1000),
            visibleFrame: visibleFrame
        )
        let windowSize = PulsePinnedScreenshotPanelLayout.windowSize(
            imageSize: CGSize(width: 2000, height: 1000),
            visibleFrame: visibleFrame
        )
        let imageContentRect = PulsePinnedScreenshotPanelLayout.imageContentRect(windowSize: windowSize)

        XCTAssertEqual(imageContentSize.width, 720)
        XCTAssertEqual(imageContentSize.height, 360)
        XCTAssertEqual(windowSize.width, 720)
        XCTAssertEqual(windowSize.height, 360)
        XCTAssertEqual(imageContentRect.size, imageContentSize)
        XCTAssertEqual(imageContentRect.origin, .zero)
        XCTAssertEqual(imageContentSize.width / imageContentSize.height, 2)
        XCTAssertLessThanOrEqual(imageContentSize.width, visibleFrame.width * PulsePinnedScreenshotPanelLayout.maximumScreenWidthFraction)
        XCTAssertLessThanOrEqual(imageContentSize.height, visibleFrame.height * PulsePinnedScreenshotPanelLayout.maximumScreenHeightFraction)
    }

    func testPinnedScreenshotWindowFrameStaysInsideVisibleFrame() {
        let visibleFrame = CGRect(x: 100, y: 80, width: 900, height: 700)
        let frame = PulsePinnedScreenshotPanelLayout.windowFrame(
            imageSize: CGSize(width: 2400, height: 1600),
            visibleFrame: visibleFrame,
            pointerLocation: CGPoint(x: 980, y: 760),
            cascadeIndex: 5
        )
        let safeFrame = visibleFrame.insetBy(
            dx: PulsePinnedScreenshotPanelLayout.edgeInset,
            dy: PulsePinnedScreenshotPanelLayout.edgeInset
        )

        XCTAssertGreaterThanOrEqual(frame.minX, safeFrame.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, safeFrame.minY)
        XCTAssertLessThanOrEqual(frame.maxX, safeFrame.maxX)
        XCTAssertLessThanOrEqual(frame.maxY, safeFrame.maxY)
    }
}
