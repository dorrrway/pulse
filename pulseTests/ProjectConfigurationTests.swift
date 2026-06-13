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
        XCTAssertEqual(PulseScreenshotService.arguments(for: .fullScreen, displayIndex: 2), ["-c", "-D2", "-x"])
        XCTAssertEqual(PulseScreenshotService.arguments(for: .window), ["-c", "-i", "-w", "-o", "-x"])
        XCTAssertEqual(PulseScreenshotService.arguments(for: .selection), ["-c", "-i", "-s", "-x"])
    }

    func testShortcutActionsMapCaptureAndRecordingModes() {
        XCTAssertEqual(PulseShortcutAction(hotKeyID: 3), .captureFullScreen)
        XCTAssertEqual(PulseShortcutAction(hotKeyID: 6), .recordFullScreen)
        XCTAssertEqual(PulseShortcutAction.captureWindow.screenshotMode, .window)
        XCTAssertEqual(PulseShortcutAction.captureWindow.screenRecordingMode, nil)
        XCTAssertEqual(PulseShortcutAction.recordSelection.screenshotMode, nil)
        XCTAssertEqual(PulseShortcutAction.recordSelection.screenRecordingMode, .selection)
        XCTAssertEqual(PulseScreenshotMode.window.shortcutAction, .captureWindow)
        XCTAssertEqual(PulseScreenshotMode.window.screenRecordingShortcutAction, .recordWindow)
    }

    func testScreenRecordingTargetSelectionUsesNativeScreenshotPickerForWindow() {
        let selectionURL = URL(fileURLWithPath: "/tmp/pulse-recording-selection.png")

        XCTAssertEqual(
            PulseScreenRecordingService.selectionArguments(for: .window, outputURL: selectionURL),
            ["-i", "-w", "-o", "-x", selectionURL.path]
        )
    }

    func testScreenRecordingCustomSelectionConvertsAppKitScreenPointsToDisplayCoordinates() {
        let display = PulseScreenRecordingSelectionDisplay(
            displayID: 1,
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            displayBounds: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        XCTAssertEqual(
            display.cgPoint(fromAppKitScreenPoint: CGPoint(x: 120, y: 820)),
            CGPoint(x: 120, y: 80)
        )
        XCTAssertEqual(
            display.viewRect(fromCGRect: CGRect(x: 120, y: 80, width: 320, height: 180)),
            CGRect(x: 120, y: 640, width: 320, height: 180)
        )
    }

    func testScreenRecordingCustomSelectionRectStandardizesAndClampsToDisplay() {
        let displayBounds = CGRect(x: 100, y: 50, width: 900, height: 600)

        XCTAssertEqual(
            PulseScreenRecordingSelectionGeometry.selectionRect(
                from: CGPoint(x: 900, y: 500),
                to: CGPoint(x: 60, y: 900),
                in: displayBounds
            ),
            CGRect(x: 100, y: 500, width: 800, height: 150)
        )
        XCTAssertTrue(
            PulseScreenRecordingSelectionGeometry.isValidSelectionRect(
                CGRect(x: 100, y: 100, width: 8, height: 8)
            )
        )
        XCTAssertFalse(
            PulseScreenRecordingSelectionGeometry.isValidSelectionRect(
                CGRect(x: 100, y: 100, width: 7, height: 8)
            )
        )
    }

    func testScreenRecordingCustomSelectionOnlyDrawsRenderableStrokeRects() {
        XCTAssertNil(
            PulseScreenRecordingSelectionGeometry.renderableSelectionStrokeRect(
                from: CGRect(x: 10, y: 10, width: 1, height: 20)
            )
        )
        XCTAssertNil(
            PulseScreenRecordingSelectionGeometry.renderableSelectionStrokeRect(
                from: CGRect(x: 10, y: 10, width: CGFloat.infinity, height: 20)
            )
        )
        XCTAssertEqual(
            PulseScreenRecordingSelectionGeometry.renderableSelectionStrokeRect(
                from: CGRect(x: 10, y: 10, width: 20, height: 30)
            ),
            CGRect(x: 11, y: 11, width: 18, height: 28)
        )
    }

    func testScreenRecordingRegionOverlayUsesSelectedDisplayOnlyForCutout() {
        let primaryDisplay = PulseScreenRecordingSelectionDisplay(
            displayID: 1,
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            displayBounds: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        let secondaryDisplay = PulseScreenRecordingSelectionDisplay(
            displayID: 2,
            screenFrame: CGRect(x: 1440, y: 0, width: 1000, height: 800),
            displayBounds: CGRect(x: 1440, y: 0, width: 1000, height: 800)
        )
        let selectionRect = CGRect(x: 1500, y: 40, width: 300, height: 180)

        XCTAssertEqual(
            PulseScreenRecordingRegionOverlayGeometry.selectedDisplayID(
                for: selectionRect,
                displays: [primaryDisplay, secondaryDisplay]
            ),
            2
        )
        XCTAssertNil(
            PulseScreenRecordingRegionOverlayGeometry.selectedViewRect(
                for: selectionRect,
                display: primaryDisplay,
                selectedDisplayID: 2
            )
        )
        XCTAssertEqual(
            PulseScreenRecordingRegionOverlayGeometry.selectedViewRect(
                for: selectionRect,
                display: secondaryDisplay,
                selectedDisplayID: 2
            ),
            CGRect(x: 60, y: 580, width: 300, height: 180)
        )
    }

    func testScreenshotModesUseAssetBackedIcons() {
        XCTAssertEqual(PulseScreenshotMode.fullScreen.iconAssetName, "ScreenshotFullScreenIcon")
        XCTAssertEqual(PulseScreenshotMode.window.iconAssetName, "ScreenshotWindowIcon")
        XCTAssertEqual(PulseScreenshotMode.selection.iconAssetName, "ScreenshotSelectionIcon")
        XCTAssertEqual(PulseScreenshotMode.fullScreen.screenRecordingIconAssetName, "ScreenRecordingFullScreenIcon")
        XCTAssertEqual(PulseScreenshotMode.window.screenRecordingIconAssetName, "ScreenRecordingWindowIcon")
        XCTAssertEqual(PulseScreenshotMode.selection.screenRecordingIconAssetName, "ScreenRecordingSelectionIcon")
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
    func testScreenshotPreviewImageIgnoresUnchangedClipboardAfterReportedSuccess() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("pulse.screenshot.tests.\(UUID().uuidString)"))
        let image = NSImage(size: NSSize(width: 24, height: 16))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 16).fill()
        image.unlockFocus()

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))

        let previousChangeCount = pasteboard.changeCount
        let previewImage = PulseIslandPanelController.screenshotPreviewImage(
            afterCaptureResult: .copiedToClipboard,
            from: pasteboard,
            previousChangeCount: previousChangeCount
        )

        XCTAssertNil(previewImage)
    }

    @MainActor
    func testScreenshotPreviewImageReadsChangedClipboardAfterReportedSuccess() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("pulse.screenshot.tests.\(UUID().uuidString)"))
        let previousChangeCount = pasteboard.changeCount

        let image = NSImage(size: NSSize(width: 24, height: 16))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 16).fill()
        image.unlockFocus()

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))

        let previewImage = PulseIslandPanelController.screenshotPreviewImage(
            afterCaptureResult: .copiedToClipboard,
            from: pasteboard,
            previousChangeCount: previousChangeCount
        )

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

    func testPinnedScreenshotPanelStyleKeepsBorderlessVisualAndNativeResize() {
        let styleMask = PulsePinnedScreenshotPanelLayout.panelStyleMask

        XCTAssertTrue(styleMask.contains(.resizable))
        XCTAssertTrue(styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(styleMask.contains(.titled))
        XCTAssertFalse(styleMask.contains(.closable))
        XCTAssertFalse(styleMask.contains(.miniaturizable))
    }

    func testPinnedScreenshotContentAspectRatioUsesImageSize() {
        XCTAssertEqual(
            PulsePinnedScreenshotPanelLayout.contentAspectRatio(imageSize: CGSize(width: 1600, height: 900)),
            CGSize(width: 1600, height: 900)
        )
        XCTAssertEqual(
            PulsePinnedScreenshotPanelLayout.contentAspectRatio(imageSize: .zero),
            PulsePinnedScreenshotPanelLayout.fallbackSize
        )
    }

    func testPinnedScreenshotNativeResizeLimitsPreserveAspectRatio() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 900, height: 700)
        let minimumSize = PulsePinnedScreenshotPanelLayout.minimumResizeSize(
            imageSize: CGSize(width: 1600, height: 900)
        )
        let maximumSize = PulsePinnedScreenshotPanelLayout.maximumResizeSize(
            imageSize: CGSize(width: 1600, height: 900),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(minimumSize.width / minimumSize.height, 16.0 / 9.0, accuracy: 0.01)
        XCTAssertEqual(maximumSize.width / maximumSize.height, 16.0 / 9.0, accuracy: 0.01)
        XCTAssertLessThanOrEqual(maximumSize.width, visibleFrame.width - PulsePinnedScreenshotPanelLayout.edgeInset * 2)
        XCTAssertLessThanOrEqual(maximumSize.height, visibleFrame.height - PulsePinnedScreenshotPanelLayout.edgeInset * 2)
    }
}
