import AppKit
import XCTest
@testable import pulse

final class PinnedPanelControllerTests: XCTestCase {
    @MainActor
    func testCoreLayoutValuesComeFromDesignTokens() {
        let panelOuterPadding = PulsePanelLayout.outerPadding
        let spacingMedium = PulseDesign.Spacing.md
        let panelCornerRadius = PulsePanelLayout.panelCornerRadius
        let tokenPanelCornerRadius = PulseDesign.Radius.panel
        let notchLaneSafetyInset = PulseIslandLayout.notchLaneSafetyInset
        let tokenNotchLaneSafetyInset = PulseDesign.Island.notchLaneSafetyInset
        let notchedSeedSideLaneWidth = PulseIslandLayout.notchedSeedSideLaneWidth
        let tokenNotchedSeedSideLaneWidth = PulseDesign.Island.notchedSeedSideLaneWidth
        let notchedSeedContentHorizontalPadding = PulseIslandLayout.notchedSeedContentHorizontalPadding
        let tokenNotchedSeedContentHorizontalPadding = PulseDesign.Island.notchedSeedContentHorizontalPadding

        XCTAssertEqual(panelOuterPadding, spacingMedium)
        XCTAssertEqual(panelCornerRadius, tokenPanelCornerRadius)
        XCTAssertEqual(notchLaneSafetyInset, tokenNotchLaneSafetyInset)
        XCTAssertEqual(notchedSeedSideLaneWidth, tokenNotchedSeedSideLaneWidth)
        XCTAssertEqual(notchedSeedContentHorizontalPadding, tokenNotchedSeedContentHorizontalPadding)
    }

    @MainActor
    func testFavoriteProjectedItemFootprintMatchesContentWidthIncrement() {
        let currentWidth = InstalledAppsPanelLayout.favoriteContentWidth(itemCount: 3)
        let projectedWidth = InstalledAppsPanelLayout.favoriteContentWidth(itemCount: 4)

        XCTAssertEqual(
            projectedWidth - currentWidth,
            InstalledAppsPanelLayout.favoriteProjectedItemFootprint
        )
        XCTAssertGreaterThan(
            InstalledAppsPanelLayout.favoriteProjectedItemFootprint,
            InstalledAppsPanelLayout.favoriteSlotSide
        )
    }

    @MainActor
    func testFavoriteDropInsertionIndexTracksPointerAcrossIconCenters() {
        let itemCount = 3
        let contentWidth = InstalledAppsPanelLayout.favoriteContentWidth(itemCount: itemCount)
        let firstCenter = InstalledAppsPanelLayout.favoriteInsertionGapWidth
            + InstalledAppsPanelLayout.favoriteSlotSide / 2
        let itemStep = InstalledAppsPanelLayout.favoriteSlotSide
            + InstalledAppsPanelLayout.favoriteInsertionGapWidth

        XCTAssertEqual(
            InstalledAppsPanelLayout.favoriteDropInsertionIndex(
                locationX: firstCenter - 1,
                itemCount: itemCount,
                containerWidth: contentWidth
            ),
            0
        )
        XCTAssertEqual(
            InstalledAppsPanelLayout.favoriteDropInsertionIndex(
                locationX: firstCenter + 1,
                itemCount: itemCount,
                containerWidth: contentWidth
            ),
            1
        )
        XCTAssertEqual(
            InstalledAppsPanelLayout.favoriteDropInsertionIndex(
                locationX: firstCenter + itemStep + 1,
                itemCount: itemCount,
                containerWidth: contentWidth
            ),
            2
        )
        XCTAssertEqual(
            InstalledAppsPanelLayout.favoriteDropInsertionIndex(
                locationX: contentWidth + 100,
                itemCount: itemCount,
                containerWidth: contentWidth
            ),
            3
        )
    }

    @MainActor
    func testFavoriteDropIndexCompactsProjectedLayoutAfterSourceRemoval() {
        XCTAssertEqual(
            InstalledAppsPanelLayout.favoriteCompactInsertionIndex(originalIndex: 3, sourceIndex: 1),
            2
        )
        XCTAssertTrue(InstalledAppsPanelLayout.isNoOpFavoriteDrop(originalIndex: 1, sourceIndex: 1))
        XCTAssertTrue(InstalledAppsPanelLayout.isNoOpFavoriteDrop(originalIndex: 2, sourceIndex: 1))
        XCTAssertFalse(InstalledAppsPanelLayout.isNoOpFavoriteDrop(originalIndex: 3, sourceIndex: 1))
    }

    @MainActor
    func testPinnedPanelReceivesUpdateControllerEnvironment() {
        let controller = PulsePinnedPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        XCTAssertTrue(controller.isPresented)
    }

    @MainActor
    func testIslandPanelCanPresentAndDismiss() {
        let controller = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        XCTAssertTrue(controller.isPresented)

        controller.dismiss()

        XCTAssertFalse(controller.isPresented)
    }

    @MainActor
    func testDisplaySelectionUsesDisplayContainingPointer() {
        let builtInDisplay = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let externalDisplay = CGRect(x: 1512, y: 0, width: 2560, height: 1440)

        XCTAssertEqual(
            PulseDisplaySelection.screenIndex(
                containing: CGPoint(x: 2200, y: 700),
                in: [builtInDisplay, externalDisplay]
            ),
            1
        )
    }

    @MainActor
    func testDisplaySelectionReturnsNilOutsideKnownDisplays() {
        let displays = [
            CGRect(x: 0, y: 0, width: 1512, height: 982),
            CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        ]

        XCTAssertNil(
            PulseDisplaySelection.screenIndex(
                containing: CGPoint(x: -200, y: -200),
                in: displays
            )
        )
    }

    @MainActor
    func testIslandControllerTracksPinnedPanelPresentation() {
        let pinnedController = PulsePinnedPanelController()
        let islandController = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)
        pinnedController.presentationDidChange = { isPresented in
            islandController.setPinnedPanelPresented(isPresented)
        }

        XCTAssertFalse(islandController.isPinnedPanelPresented)

        pinnedController.present(store: store, updateController: updateController)
        defer {
            pinnedController.dismiss()
        }

        XCTAssertTrue(islandController.isPinnedPanelPresented)

        pinnedController.dismiss()

        XCTAssertFalse(islandController.isPinnedPanelPresented)
    }

    @MainActor
    func testIslandLayoutKeepsTopAttachmentOffscreen() {
        XCTAssertGreaterThan(PulseIslandLayout.topAttachmentDepth(for: .seed), 0)
        XCTAssertGreaterThan(PulseIslandLayout.topAttachmentDepth(for: .criticalSeed), 0)
        XCTAssertGreaterThan(PulseIslandLayout.topAttachmentDepth(for: .screenshotPreview), 0)
        XCTAssertGreaterThan(PulseIslandLayout.topAttachmentDepth(for: .expanded), 0)
        XCTAssertLessThan(
            PulseIslandLayout.visibleHeight(for: .seed),
            PulseIslandLayout.contentSize(for: .seed).height
        )
        XCTAssertLessThan(
            PulseIslandLayout.visibleHeight(for: .criticalSeed),
            PulseIslandLayout.contentSize(for: .criticalSeed).height
        )
        XCTAssertLessThan(
            PulseIslandLayout.visibleHeight(for: .screenshotPreview),
            PulseIslandLayout.contentSize(for: .screenshotPreview).height
        )
        XCTAssertLessThan(
            PulseIslandLayout.visibleHeight(for: .expanded),
            PulseIslandLayout.contentSize(for: .expanded).height
        )
    }

    @MainActor
    func testIslandLayoutKeepsTopShoulderVisibleAtScreenEdge() {
        XCTAssertGreaterThan(
            PulseIslandLayout.surfaceTopShoulderRadius(for: .seed),
            PulseIslandLayout.topAttachmentDepth(for: .seed)
        )
        XCTAssertGreaterThan(
            PulseIslandLayout.surfaceTopShoulderDepth(for: .seed),
            PulseIslandLayout.topAttachmentDepth(for: .seed)
        )
        XCTAssertGreaterThan(
            PulseIslandLayout.surfaceTopShoulderRadius(for: .expanded),
            PulseIslandLayout.topAttachmentDepth(for: .expanded)
        )
        XCTAssertGreaterThan(
            PulseIslandLayout.surfaceTopShoulderDepth(for: .expanded),
            PulseIslandLayout.topAttachmentDepth(for: .expanded)
        )
    }

    @MainActor
    func testIslandLayoutKeepsBodyWidthIndependentFromTopShoulders() {
        XCTAssertEqual(
            PulseIslandLayout.surfaceWidth(for: .seed) - PulseIslandLayout.surfaceTopShoulderInset(for: .seed) * 2,
            PulseIslandLayout.seedVisibleWidth
        )
        XCTAssertEqual(
            PulseIslandLayout.surfaceWidth(for: .expanded) - PulseIslandLayout.surfaceTopShoulderInset(for: .expanded) * 2,
            PulseIslandLayout.expandedSurfaceWidth
        )
        XCTAssertLessThan(
            PulseIslandLayout.surfaceTopShoulderInset(for: .seed),
            PulseIslandLayout.surfaceTopShoulderRadius(for: .seed)
        )
        XCTAssertLessThan(
            PulseIslandLayout.surfaceTopShoulderInset(for: .expanded),
            PulseIslandLayout.surfaceTopShoulderRadius(for: .expanded)
        )
    }

    @MainActor
    func testIslandContentPaddingDoesNotFollowTopShoulderWidth() {
        XCTAssertLessThan(
            PulseIslandLayout.seedContentHorizontalPadding,
            PulseIslandLayout.surfaceTopShoulderRadius(for: .seed)
        )
        XCTAssertLessThan(
            PulseIslandLayout.expandedContentHorizontalPadding,
            PulseIslandLayout.surfaceTopShoulderRadius(for: .expanded)
        )
        XCTAssertEqual(PulseIslandLayout.expandedContentHorizontalPadding, 12)
    }

    @MainActor
    func testIslandExpandedSurfaceDoesNotCastShadowOntoAttachedPanel() {
        XCTAssertGreaterThan(PulseIslandLayout.surfaceShadowOpacity(for: .seed), 0)
        XCTAssertGreaterThan(PulseIslandLayout.surfaceShadowRadius(for: .seed), 0)
        XCTAssertEqual(PulseIslandLayout.surfaceShadowOpacity(for: .expanded), 0)
        XCTAssertEqual(PulseIslandLayout.surfaceShadowRadius(for: .expanded), 0)
    }

    @MainActor
    func testIslandExpandedHeaderUsesTwoRowSurfaceAboveAttachedPanel() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 38, notchUnsafeWidth: 220)

        XCTAssertEqual(PulseIslandLayout.expandedSurfaceHeightMultiplier, 2)
        XCTAssertEqual(PulseIslandLayout.expandedHeaderExtraHeight, 12)
        XCTAssertEqual(PulseIslandLayout.expandedHeaderRowHeight(metrics: metrics), 38)
        XCTAssertEqual(PulseIslandLayout.expandedHeaderContentHeight(metrics: metrics), 76)
        XCTAssertEqual(PulseIslandLayout.expandedSurfaceVisibleHeight(metrics: metrics), 88)
        XCTAssertEqual(PulseIslandLayout.visibleHeight(for: .criticalSeed, metrics: metrics), 76)
        XCTAssertGreaterThan(
            PulseIslandLayout.seedVisibleSize(for: .criticalSeed, metrics: metrics).width,
            PulseIslandLayout.seedVisibleSize(for: .seed, metrics: metrics).width + 60
        )
        XCTAssertLessThan(
            PulseIslandLayout.seedVisibleSize(for: .criticalSeed, metrics: metrics).width,
            PulseIslandLayout.expandedSurfaceWidth
        )
        XCTAssertEqual(PulseIslandLayout.expandedHeaderRowHeight, PulseIslandLayout.defaultSeedVisibleHeight)
        XCTAssertLessThan(PulseIslandLayout.attachedPanelTopGap, 12)
        XCTAssertLessThan(
            PulseIslandLayout.expandedSurfaceVisibleHeight(metrics: metrics),
            PulseIslandLayout.attachedPanelSize.height / 2
        )
    }

    @MainActor
    func testScreenshotPreviewReminderUsesTallerCompactSurface() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 38, notchUnsafeWidth: 220)

        XCTAssertEqual(PulseIslandLayout.screenshotPreviewHeaderRowHeight(metrics: metrics), 38)
        XCTAssertEqual(
            PulseIslandLayout.screenshotPreviewHeaderRowHeight(metrics: metrics),
            PulseIslandLayout.expandedHeaderRowHeight(metrics: metrics)
        )
        XCTAssertEqual(PulseIslandLayout.visibleHeight(for: .screenshotPreview, metrics: metrics), 226)
        XCTAssertGreaterThan(
            PulseIslandLayout.visibleHeight(for: .screenshotPreview, metrics: metrics),
            PulseIslandLayout.visibleHeight(for: .criticalSeed, metrics: metrics) * 2
        )
        XCTAssertEqual(
            PulseIslandLayout.seedVisibleSize(for: .screenshotPreview, metrics: metrics).width,
            PulseIslandLayout.screenshotPreviewVisibleWidth
        )
    }

    @MainActor
    func testScreenshotPreviewReminderSuspendsAutoDismissWhileHovered() async throws {
        let controller = PulseIslandPanelController()
        let reminder = PulseCapturePreviewReminder(image: NSImage(size: NSSize(width: 8, height: 8)))

        controller.presentScreenshotPreview(reminder, autoDismissDuration: .milliseconds(50))
        controller.setHovering(true)

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(controller.style, .screenshotPreview)
        XCTAssertEqual(controller.capturePreviewReminder, reminder)

        controller.setHovering(false)

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(controller.style, .seed)
        XCTAssertNil(controller.capturePreviewReminder)
    }

    @MainActor
    func testClosingScreenshotPreviewRestoresExpandedStyleWhenPreviewStartedExpanded() {
        let controller = PulseIslandPanelController()
        let reminder = PulseCapturePreviewReminder(image: NSImage(size: NSSize(width: 8, height: 8)))

        controller.toggleStyle()
        controller.presentScreenshotPreview(reminder)

        XCTAssertEqual(controller.style, .screenshotPreview)

        controller.closeCapturePreview()

        XCTAssertEqual(controller.style, .expanded)
        XCTAssertNil(controller.capturePreviewReminder)
    }

    @MainActor
    func testScreenRecordingPreviewPersistsUntilDiscardedAndRemovesTemporaryFile() throws {
        let controller = PulseIslandPanelController()
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-recording-preview-\(UUID().uuidString).mov")
        try Data([0, 1, 2, 3]).write(to: temporaryURL, options: .atomic)
        let preview = PulseScreenRecordingPreview(
            url: temporaryURL,
            thumbnail: NSImage(size: NSSize(width: 16, height: 9)),
            duration: 61,
            suggestedFileName: "Pulse Recording Test.mov"
        )

        controller.presentScreenRecordingPreview(preview)

        XCTAssertEqual(controller.style, .screenshotPreview)
        XCTAssertEqual(controller.capturePreviewReminder?.screenRecording, preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))

        controller.setHovering(false)
        controller.discardCapturePreview()

        XCTAssertEqual(controller.style, .seed)
        XCTAssertNil(controller.capturePreviewReminder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    @MainActor
    func testClosingScreenRecordingPreviewRemovesTemporaryFile() throws {
        let controller = PulseIslandPanelController()
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-recording-preview-close-\(UUID().uuidString).mov")
        try Data([0, 1, 2, 3]).write(to: temporaryURL, options: .atomic)
        let preview = PulseScreenRecordingPreview(
            url: temporaryURL,
            thumbnail: NSImage(size: NSSize(width: 16, height: 9)),
            duration: 24,
            suggestedFileName: "Pulse Recording Close Test.mov"
        )

        controller.presentScreenRecordingPreview(preview)
        controller.closeCapturePreview()

        XCTAssertEqual(controller.style, .seed)
        XCTAssertNil(controller.capturePreviewReminder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    @MainActor
    func testScreenshotCaptureCanKeepPulseVisible() async throws {
        let controller = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)
        let service = PulseScreenshotService(
            preflightAccess: { true },
            requestAccess: { false },
            openScreenCaptureSettings: {},
            capture: { _, _, _ in .cancelled }
        )

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        controller.captureScreenshot(
            mode: .selection,
            hidesPulseDuringCapture: false,
            service: service
        )

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(controller.isPresented)
        XCTAssertEqual(controller.style, .seed)
    }

    @MainActor
    func testIslandModulesCycleHorizontally() {
        XCTAssertEqual(PulseIslandModule.resourceMonitor.shifted(by: 1), .applications)
        XCTAssertEqual(PulseIslandModule.applications.shifted(by: 1), .clipboard)
        XCTAssertEqual(PulseIslandModule.clipboard.shifted(by: 1), .memos)
        XCTAssertEqual(PulseIslandModule.memos.shifted(by: 1), .screenshots)
        XCTAssertEqual(PulseIslandModule.screenshots.shifted(by: 1), .bluetooth)
        #if DEBUG
        XCTAssertEqual(PulseIslandModule.bluetooth.shifted(by: 1), .translation)
        XCTAssertEqual(PulseIslandModule.translation.shifted(by: 1), .resourceMonitor)
        XCTAssertEqual(PulseIslandModule.resourceMonitor.shifted(by: -1), .translation)
        XCTAssertEqual(PulseIslandModule.translation.shifted(by: -1), .bluetooth)
        #else
        XCTAssertEqual(PulseIslandModule.bluetooth.shifted(by: 1), .resourceMonitor)
        XCTAssertEqual(PulseIslandModule.resourceMonitor.shifted(by: -1), .bluetooth)
        #endif
        XCTAssertEqual(PulseIslandModule.applications.shifted(by: -1), .resourceMonitor)
        XCTAssertEqual(PulseIslandModule.clipboard.shifted(by: -1), .applications)
        XCTAssertEqual(PulseIslandModule.memos.shifted(by: -1), .clipboard)
        XCTAssertEqual(PulseIslandModule.screenshots.shifted(by: -1), .memos)
        XCTAssertEqual(PulseIslandModule.bluetooth.shifted(by: -1), .screenshots)
    }

    @MainActor
    func testIslandDefaultsToApplicationsModule() {
        let controller = PulseIslandPanelController()

        XCTAssertEqual(controller.selectedModule, .applications)
    }

    @MainActor
    func testIslandModuleHorizontalInputDirectionMatchesNaturalPaging() {
        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.switchOffset(forHorizontalDragTranslation: -20),
            1
        )
        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.switchOffset(forHorizontalDragTranslation: 20),
            -1
        )
        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.switchOffset(forHorizontalScrollDelta: -20),
            1
        )
        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.switchOffset(forHorizontalScrollDelta: 20),
            -1
        )
    }

    @MainActor
    func testIslandModuleInteractionRegionIncludesHeaderBlankSpace() {
        let bounds = CGRect(x: 0, y: 0, width: PulseIslandLayout.expandedSurfaceWidth, height: 60)
        let moduleRowHeight: CGFloat = 30

        XCTAssertTrue(
            PulseIslandModuleInteractionGeometry.isModuleSwitchRegion(
                point: CGPoint(x: 24, y: 15),
                bounds: bounds,
                moduleRowHeight: moduleRowHeight
            )
        )
        XCTAssertTrue(
            PulseIslandModuleInteractionGeometry.isModuleSwitchRegion(
                point: CGPoint(x: 24, y: 45),
                bounds: bounds,
                moduleRowHeight: moduleRowHeight
            )
        )
        XCTAssertFalse(
            PulseIslandModuleInteractionGeometry.isModuleSwitchRegion(
                point: CGPoint(x: 540, y: 45),
                bounds: bounds,
                moduleRowHeight: moduleRowHeight
            )
        )
    }

    @MainActor
    func testIslandModuleClickGeometryMatchesCenteredSelector() {
        let bounds = CGRect(x: 0, y: 0, width: PulseIslandLayout.expandedSurfaceWidth, height: 60)
        let moduleRowHeight: CGFloat = 30
        let itemWidths: [PulseIslandModule: CGFloat] = [
            .resourceMonitor: 88,
            .applications: 88,
            .clipboard: 72
        ]

        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.module(
                at: CGPoint(x: 280, y: 15),
                bounds: bounds,
                selectedModule: .resourceMonitor,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            ),
            .resourceMonitor
        )
        XCTAssertEqual(
            PulseIslandModuleInteractionGeometry.module(
                at: CGPoint(x: 392, y: 15),
                bounds: bounds,
                selectedModule: .resourceMonitor,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            ),
            .applications
        )
        XCTAssertNil(
            PulseIslandModuleInteractionGeometry.module(
                at: CGPoint(x: 336, y: 15),
                bounds: bounds,
                selectedModule: .resourceMonitor,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            )
        )
        XCTAssertNil(
            PulseIslandModuleInteractionGeometry.module(
                at: CGPoint(x: 24, y: 15),
                bounds: bounds,
                selectedModule: .resourceMonitor,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            )
        )
        XCTAssertNil(
            PulseIslandModuleInteractionGeometry.module(
                at: CGPoint(x: 280, y: 45),
                bounds: bounds,
                selectedModule: .resourceMonitor,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            )
        )
    }

    @MainActor
    func testIslandSeedMetricRotatesBetweenMemoryAndCPU() {
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 0, interval: 3), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 2.9, interval: 3), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 3, interval: 3), .cpu)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 6, interval: 3), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.memory.next, .cpu)
        XCTAssertEqual(PulseIslandSeedMetric.cpu.next, .memory)
    }

    @MainActor
    func testIslandSeedMetricIncludesPowerOnlyForLowBatteryPower() {
        let lowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let thresholdBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.2,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let pluggedInLowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: true,
            isCharging: false,
            timeRemaining: nil
        )
        let chargingLowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: true,
            isCharging: true,
            timeRemaining: nil
        )
        let unknownBatteryPercentage = PowerUsage(
            hasBattery: true,
            batteryPercentage: nil,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let lowBatteryMetrics = PulseIslandSeedMetric.rotationMetrics(for: lowBattery)

        XCTAssertEqual(lowBatteryMetrics, [.memory, .cpu, .power])
        XCTAssertEqual(PulseIslandSeedMetric.rotationMetrics(for: thresholdBattery), [.memory, .cpu, .power])
        XCTAssertEqual(PulseIslandSeedMetric.rotationMetrics(for: pluggedInLowBattery), [.memory, .cpu])
        XCTAssertEqual(PulseIslandSeedMetric.rotationMetrics(for: chargingLowBattery), [.memory, .cpu, .power])
        XCTAssertEqual(PulseIslandSeedMetric.rotationMetrics(for: unknownBatteryPercentage), [.memory, .cpu])
        XCTAssertEqual(PulseIslandSeedMetric.rotationMetrics(for: .empty), [.memory, .cpu])
        XCTAssertEqual(PulseIslandSeedMetric.cpu.next(in: lowBatteryMetrics), .power)
        XCTAssertEqual(PulseIslandSeedMetric.power.next(in: lowBatteryMetrics), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.power.normalized(in: PulseIslandSeedMetric.defaultRotationMetrics), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 6, interval: 3, metrics: lowBatteryMetrics), .power)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 9, interval: 3, metrics: lowBatteryMetrics), .memory)
    }

    @MainActor
    func testIslandSeedMetricIncludesBluetoothLowBatteryInDefaultRotation() {
        let airPods = BluetoothDevice(
            id: "airpods",
            name: "AirPods Pro",
            category: .headphones,
            connectionState: .connected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .left, percentage: 0.18),
                BluetoothBatteryLevel(role: .right, percentage: 0.09),
                BluetoothBatteryLevel(role: .case, percentage: 0.31),
            ]
        )
        let alerts = airPods.lowBatteryAlerts

        let metrics = PulseIslandSeedMetric.rotationMetrics(
            for: .empty,
            bluetoothDevices: [airPods]
        )

        XCTAssertEqual(
            metrics,
            [
                .memory,
                .cpu,
                .bluetoothBattery(alerts[1]),
                .bluetoothBattery(alerts[0]),
            ]
        )
        XCTAssertEqual(PulseIslandSeedMetric.cpu.next(in: metrics), .bluetoothBattery(alerts[1]))
        XCTAssertEqual(PulseIslandSeedMetric.bluetoothBattery(alerts[0]).next(in: metrics), .memory)
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 6, interval: 3, metrics: metrics), .bluetoothBattery(alerts[1]))
        XCTAssertEqual(PulseIslandSeedMetric.current(elapsedTime: 9, interval: 3, metrics: metrics), .bluetoothBattery(alerts[0]))
    }

    @MainActor
    func testIslandSeedMetricKeepsInternalPowerBeforeBluetoothBattery() {
        let lowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let trackpad = BluetoothDevice(
            id: "trackpad",
            name: "Magic Trackpad",
            category: .trackpad,
            connectionState: .connected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .device, percentage: 0.19),
            ]
        )

        XCTAssertEqual(
            PulseIslandSeedMetric.rotationMetrics(for: lowBattery, bluetoothDevices: [trackpad]),
            [.memory, .cpu, .power, .bluetoothBattery(trackpad.lowBatteryAlerts[0])]
        )
    }

    @MainActor
    func testIslandSeedMetricUsesCompactIconAssets() {
        let lowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let criticalBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.1,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let chargingLowBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: true,
            isCharging: true,
            timeRemaining: nil
        )

        XCTAssertEqual(PulseIslandSeedMetric.memory.compactIconAssetName(power: .empty), "IslandMemoryIcon")
        XCTAssertEqual(PulseIslandSeedMetric.cpu.compactIconAssetName(power: .empty), "IslandCPUIcon")
        XCTAssertEqual(PulseIslandSeedMetric.power.compactIconAssetName(power: lowBattery), "IslandBattery20Icon")
        XCTAssertEqual(PulseIslandSeedMetric.power.compactIconAssetName(power: criticalBattery), "IslandBattery10Icon")
        XCTAssertEqual(PulseIslandSeedMetric.power.compactIconAssetName(power: chargingLowBattery), "IslandBatteryChargingIcon")
        XCTAssertEqual(
            PulseIslandSeedMetric.bluetoothBattery(
                BluetoothBatteryAlert(
                    deviceID: "airpods",
                    deviceName: "AirPods Pro",
                    category: .headphones,
                    role: .left,
                    percentage: 0.09,
                    severity: .critical,
                    isConnected: true
                )
            )
                .compactIconAssetName(power: .empty),
            "IslandBattery10Icon"
        )
    }

    @MainActor
    func testIslandSeedMetricPresentsCriticalPowerAlertOnlyForRedBatteryPower() {
        let redBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let thresholdRedBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.1,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let orangeBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let pluggedInRedBattery = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: true,
            isCharging: false,
            timeRemaining: nil
        )

        XCTAssertTrue(PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(redBattery))
        XCTAssertTrue(PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(thresholdRedBattery))
        XCTAssertFalse(PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(orangeBattery))
        XCTAssertFalse(PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(pluggedInRedBattery))
        XCTAssertFalse(PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(.empty))
    }

    @MainActor
    func testIslandCriticalAlertsUsePriorityOrder() {
        let highMemory = MemoryUsage(
            totalBytes: 100_000_000_000,
            usedBytes: 91_000_000_000,
            availableBytes: 9_000_000_000,
            compressedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )
        let lowDisk = DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)
        let criticalPower = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let core = CoreMetricsSnapshot(
            cpu: .empty,
            memory: highMemory,
            network: .empty,
            disk: lowDisk
        )
        let signal = SignalMetricsSnapshot(
            memory: highMemory,
            thermal: ThermalUsage(condition: .critical, stateDuration: 12),
            power: criticalPower,
            diskIO: .empty,
            runtime: .empty
        )

        XCTAssertEqual(
            PulseIslandCriticalAlert.active(core: core, signal: signal),
            [.power, .thermal, .disk, .memory]
        )
    }

    @MainActor
    func testIslandCriticalAlertsIncludeBluetoothBatteryAfterInternalPower() {
        let criticalPower = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let signal = SignalMetricsSnapshot(
            memory: .empty,
            thermal: .empty,
            power: criticalPower,
            diskIO: .empty,
            runtime: .empty
        )
        let airPods = BluetoothDevice(
            id: "airpods",
            name: "AirPods Pro",
            category: .headphones,
            connectionState: .disconnected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .left, percentage: 0.18),
                BluetoothBatteryLevel(role: .right, percentage: 0.09),
            ]
        )

        let alerts = PulseIslandCriticalAlert.active(
            core: .empty,
            signal: signal,
            bluetoothDevices: [airPods]
        )

        XCTAssertEqual(alerts.count, 3)
        XCTAssertEqual(alerts.first, .power)
        XCTAssertEqual(
            Array(alerts.dropFirst()),
            [
                .bluetoothBattery(airPods.lowBatteryAlerts[1]),
                .bluetoothBattery(airPods.lowBatteryAlerts[0]),
            ]
        )
    }

    @MainActor
    func testNotificationSuggestionsUseCriticalAlertPriorityAndDismissals() {
        let highMemory = MemoryUsage(
            totalBytes: 100_000_000_000,
            usedBytes: 91_000_000_000,
            availableBytes: 9_000_000_000,
            compressedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )
        let lowDisk = DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)
        let criticalPower = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let bluetoothDevice = BluetoothDevice(
            id: "keyboard",
            name: "Magic Keyboard",
            category: .keyboard,
            connectionState: .connected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .device, percentage: 0.08),
            ]
        )
        let bluetoothAlert = BluetoothBatteryAlert.active(devices: [bluetoothDevice])[0]
        let core = CoreMetricsSnapshot(
            cpu: .empty,
            memory: highMemory,
            network: .empty,
            disk: lowDisk
        )
        let signal = SignalMetricsSnapshot(
            memory: highMemory,
            thermal: ThermalUsage(condition: .critical, stateDuration: 12),
            power: criticalPower,
            diskIO: .empty,
            runtime: .empty
        )

        let suggestions = PulseNotificationSuggestion.active(
            core: core,
            signal: signal,
            bluetoothDevices: [bluetoothDevice],
            isEnabled: true,
            dismissedIDs: [],
            limit: 2
        )

        XCTAssertEqual(
            suggestions.map(\.alert),
            [.power, .bluetoothBattery(bluetoothAlert)]
        )

        let dismissedIDs = Set(suggestions.map(\.id))
        let remainingSuggestions = PulseNotificationSuggestion.active(
            core: core,
            signal: signal,
            bluetoothDevices: [bluetoothDevice],
            isEnabled: true,
            dismissedIDs: dismissedIDs,
            limit: 3
        )

        XCTAssertEqual(
            remainingSuggestions.map(\.alert),
            [.thermal, .disk, .memory]
        )

        XCTAssertTrue(
            PulseNotificationSuggestion.active(
                core: core,
                signal: signal,
                bluetoothDevices: [bluetoothDevice],
                isEnabled: false,
                dismissedIDs: []
            ).isEmpty
        )
    }

    @MainActor
    func testNotificationSuggestionPreferencesPersistAndReconcile() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertTrue(store.notificationSuggestionsEnabled)
        XCTAssertTrue(store.dismissedNotificationSuggestionIDs.isEmpty)

        store.setNotificationSuggestionsEnabled(false)
        store.dismissNotificationSuggestion(withID: "disk")
        store.dismissNotificationSuggestion(withID: " ")

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertFalse(reloadedStore.notificationSuggestionsEnabled)
        XCTAssertEqual(reloadedStore.dismissedNotificationSuggestionIDs, Set(["disk"]))

        reloadedStore.reconcileDismissedNotificationSuggestions(activeIDs: ["power"])
        XCTAssertTrue(reloadedStore.dismissedNotificationSuggestionIDs.isEmpty)
    }

    @MainActor
    func testIslandCriticalAlertsUseIconAssets() {
        let criticalPower = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.09,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )

        XCTAssertEqual(PulseIslandCriticalAlert.power.iconAssetName(power: criticalPower), "IslandBattery10Icon")
        XCTAssertEqual(
            PulseIslandCriticalAlert.bluetoothBattery(
                BluetoothBatteryAlert(
                    deviceID: "keyboard",
                    deviceName: "Keyboard",
                    category: .keyboard,
                    role: .device,
                    percentage: 0.19,
                    severity: .low,
                    isConnected: true
                )
            ).iconAssetName(power: .empty),
            "IslandBattery20Icon"
        )
        XCTAssertEqual(PulseIslandCriticalAlert.thermal.iconAssetName(power: .empty), "IslandThermalIcon")
        XCTAssertEqual(PulseIslandCriticalAlert.disk.iconAssetName(power: .empty), "IslandStorageIcon")
        XCTAssertEqual(PulseIslandCriticalAlert.memory.iconAssetName(power: .empty), "IslandMemoryIcon")
    }

    #if DEBUG
    @MainActor
    func testIslandCriticalAlertPreviewCasesIncludeBluetoothBattery() {
        let bluetoothAlert = PulseIslandCriticalAlert.previewBluetoothBattery

        XCTAssertTrue(PulseIslandCriticalAlert.previewCases.contains(bluetoothAlert))
        XCTAssertEqual(bluetoothAlert.iconAssetName(power: .empty), "IslandBattery10Icon")
    }
    #endif

    @MainActor
    func testIslandCriticalAlertsIgnoreNonCriticalSignals() {
        let elevatedMemory = MemoryUsage(
            totalBytes: 100_000_000_000,
            usedBytes: 82_000_000_000,
            availableBytes: 18_000_000_000,
            compressedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0
        )
        let healthyDisk = DiskUsage(totalBytes: 100_000_000_000, availableBytes: 10_000_000_000)
        let lowButNotCriticalPower = PowerUsage(
            hasBattery: true,
            batteryPercentage: 0.19,
            isPluggedIn: false,
            isCharging: false,
            timeRemaining: nil
        )
        let core = CoreMetricsSnapshot(
            cpu: .empty,
            memory: elevatedMemory,
            network: .empty,
            disk: healthyDisk
        )
        let signal = SignalMetricsSnapshot(
            memory: elevatedMemory,
            thermal: ThermalUsage(condition: .serious, stateDuration: 12),
            power: lowButNotCriticalPower,
            diskIO: .empty,
            runtime: .empty
        )

        XCTAssertEqual(PulseIslandCriticalAlert.active(core: core, signal: signal), [])
    }

    @MainActor
    func testIslandCriticalDiskAlertUsesAvailableSpaceAndUsageRatio() {
        XCTAssertTrue(
            PulseIslandCriticalAlert.shouldPresentDiskAlert(
                DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)
            )
        )
        XCTAssertTrue(
            PulseIslandCriticalAlert.shouldPresentDiskAlert(
                DiskUsage(totalBytes: 100_000_000_000, availableBytes: 5_000_000_000)
            )
        )
        XCTAssertTrue(
            PulseIslandCriticalAlert.shouldPresentDiskAlert(
                DiskUsage(totalBytes: 200_000_000_000, availableBytes: 8_000_000_000)
            )
        )
        XCTAssertFalse(
            PulseIslandCriticalAlert.shouldPresentDiskAlert(
                DiskUsage(totalBytes: 100_000_000_000, availableBytes: 10_000_000_000)
            )
        )
        XCTAssertFalse(PulseIslandCriticalAlert.shouldPresentDiskAlert(.empty))
    }

    @MainActor
    func testIslandLayoutMeasuresTopBarHeightFromVisibleFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let visibleFrame = CGRect(x: 0, y: 0, width: 2560, height: 1410)

        XCTAssertEqual(
            PulseIslandLayout.topBarHeight(
                screenFrame: screenFrame,
                visibleFrame: visibleFrame,
                safeAreaTop: 0
            ),
            30
        )
    }

    @MainActor
    func testIslandLayoutUsesMeasuredSeedHeight() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 30, notchUnsafeWidth: 0)

        XCTAssertEqual(
            PulseIslandLayout.visibleHeight(for: .seed, metrics: metrics),
            30
        )
        XCTAssertEqual(
            PulseIslandLayout.contentSize(for: .seed, metrics: metrics).height,
            30 + PulseIslandLayout.topAttachmentDepth(for: .seed)
        )
    }

    @MainActor
    func testIslandLayoutWidensSeedSurfaceAroundNotch() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 34, notchUnsafeWidth: 139)
        let expectedWidth = 139
            + PulseIslandLayout.notchLaneSafetyInset * 2
            + PulseIslandLayout.notchedSeedSideLaneWidth(metrics: metrics) * 2

        XCTAssertEqual(
            PulseIslandLayout.seedVisibleSize(metrics: metrics).width,
            max(PulseIslandLayout.seedVisibleWidth, expectedWidth)
        )
        XCTAssertEqual(
            PulseIslandLayout.notchContentGapWidth(metrics: metrics),
            139 + PulseIslandLayout.notchLaneSafetyInset * 2
        )
    }

    @MainActor
    func testIslandLayoutFitsContentPaddingInsideFixedFortyPointSideLanes() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 38, notchUnsafeWidth: 220)
        let contentWidth = PulseIslandLayout.seedVisibleSize(metrics: metrics).width
        let occupiedWidth = PulseIslandLayout.notchContentGapWidth(metrics: metrics)
            + PulseIslandLayout.notchedSeedContentSideLaneWidth(metrics: metrics) * 2
            + PulseIslandLayout.notchedSeedContentHorizontalPadding * 2

        XCTAssertEqual(PulseIslandLayout.notchedSeedSideLaneWidth(metrics: metrics), 40)
        XCTAssertEqual(PulseIslandLayout.notchedSeedContentHorizontalPadding, 12)
        XCTAssertEqual(PulseIslandLayout.notchedSeedContentSideLaneWidth(metrics: metrics), 28)
        XCTAssertEqual(
            contentWidth - occupiedWidth,
            0
        )
    }

    @MainActor
    func testIslandLayoutUsesAuxiliaryTopGapForPhysicalCameraHousing() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftArea = CGRect(x: 0, y: 948, width: 622, height: 34)
        let rightArea = CGRect(x: 890, y: 948, width: 622, height: 34)
        let notchUnsafeWidth = PulseIslandLayout.notchUnsafeWidth(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea,
            safeAreaTop: 34
        )

        XCTAssertEqual(notchUnsafeWidth, rightArea.minX - leftArea.maxX)
    }

    @MainActor
    func testIslandLayoutEstimatesCameraHousingWhenAuxiliaryAreasAreUnavailable() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let notchUnsafeWidth = PulseIslandLayout.notchUnsafeWidth(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            safeAreaTop: 34
        )

        XCTAssertEqual(notchUnsafeWidth, 139)
    }

    @MainActor
    func testIslandExpandedLayoutOmitsNotificationPanelWhenEmpty() {
        let metrics = PulseIslandLayoutMetrics(seedVisibleHeight: 38, notchUnsafeWidth: 139)
        let heightWithoutNotificationPanel = PulseIslandLayout.expandedSurfaceVisibleHeight(metrics: metrics)
            + PulseIslandLayout.attachedPanelTopGap
            + PulseIslandLayout.attachedPanelSize.height
        let heightWithNotificationPanel = heightWithoutNotificationPanel
            + PulseIslandLayout.notificationPanelHeight
            + PulseIslandLayout.attachedPanelTopGap

        XCTAssertEqual(
            PulseIslandLayout.visibleHeight(for: .expanded, metrics: metrics),
            heightWithoutNotificationPanel
        )
        XCTAssertEqual(
            PulseIslandLayout.visibleHeight(
                for: .expanded,
                metrics: metrics,
                includesNotificationPanel: true
            ),
            heightWithNotificationPanel
        )
        XCTAssertGreaterThan(PulseIslandLayout.notificationPanelHeight, 0)
        XCTAssertLessThan(
            PulseIslandLayout.notificationPanelHeight,
            PulseIslandLayout.attachedPanelSize.height
        )
        XCTAssertGreaterThanOrEqual(
            PulseIslandLayout.panelContentSize.width,
            PulseIslandLayout.attachedPanelSize.width
        )
        XCTAssertEqual(
            PulseIslandLayout.attachedPanelSize.width,
            PulseIslandLayout.expandedSurfaceWidth
        )
        XCTAssertGreaterThan(
            PulseIslandLayout.surfaceWidth(for: .expanded),
            PulseIslandLayout.attachedPanelSize.width
        )
    }

    @MainActor
    func testIslandLayoutUsesFixedOpenedPanelFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let centerX = screenFrame.midX
        let panelFrame = PulseIslandLayout.panelFrame(screenFrame: screenFrame, centerX: centerX)
        let panelFrameWithNotification = PulseIslandLayout.panelFrame(
            screenFrame: screenFrame,
            centerX: centerX,
            includesNotificationPanel: true
        )

        XCTAssertEqual(
            panelFrame.size,
            PulseIslandLayout.panelContentSize
        )
        XCTAssertEqual(
            panelFrame.minY,
            screenFrame.maxY - PulseIslandLayout.visibleHeight(for: .expanded),
            accuracy: 0.001
        )
        XCTAssertEqual(
            panelFrameWithNotification.minY,
            screenFrame.maxY - PulseIslandLayout.visibleHeight(
                for: .expanded,
                includesNotificationPanel: true
            ),
            accuracy: 0.001
        )
        XCTAssertGreaterThan(panelFrameWithNotification.height, panelFrame.height)
    }

    @MainActor
    func testIslandLayoutUsesScreenCenterWithoutCameraHousingAreas() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)

        XCTAssertEqual(
            PulseIslandLayout.preferredTopAnchorCenterX(
                screenFrame: screenFrame
            ),
            screenFrame.midX
        )
    }

    @MainActor
    func testIslandLayoutCentersOverCameraHousingGapOnNotchedScreens() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftArea = CGRect(x: 0, y: 948, width: 622, height: 34)
        let rightArea = CGRect(x: 890, y: 948, width: 622, height: 34)
        let centerX = PulseIslandLayout.preferredTopAnchorCenterX(
            screenFrame: screenFrame
        )
        let panelFrame = PulseIslandLayout.panelFrame(screenFrame: screenFrame, centerX: centerX)
        let cameraHousingGap = CGRect(
            x: leftArea.maxX,
            y: leftArea.minY,
            width: rightArea.minX - leftArea.maxX,
            height: leftArea.height
        )

        XCTAssertEqual(centerX, screenFrame.midX)
        XCTAssertTrue(panelFrame.intersects(cameraHousingGap))
    }

    @MainActor
    func testIslandLayoutPinsVisibleSurfaceToScreenTopInsideFixedPanel() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let centerX = screenFrame.midX
        let panelFrame = PulseIslandLayout.panelFrame(screenFrame: screenFrame, centerX: centerX)
        let panelBounds = CGRect(origin: .zero, size: panelFrame.size)
        let seedSurfaceFrame = PulseIslandLayout.surfaceFrame(for: .seed, in: panelBounds)
        let expandedSurfaceFrame = PulseIslandLayout.surfaceFrame(for: .expanded, in: panelBounds)

        XCTAssertEqual(
            panelFrame.minY + seedSurfaceFrame.maxY - PulseIslandLayout.topAttachmentDepth(for: .seed),
            screenFrame.maxY,
            accuracy: 0.001
        )
        XCTAssertEqual(
            panelFrame.minY + expandedSurfaceFrame.maxY - PulseIslandLayout.topAttachmentDepth(for: .expanded),
            screenFrame.maxY,
            accuracy: 0.001
        )
    }

    @MainActor
    func testIslandContentRectTracksCurrentVisualStyle() {
        let controller = PulseIslandPanelController()
        let bounds = CGRect(origin: .zero, size: PulseIslandLayout.panelContentSize)

        XCTAssertEqual(
            controller.contentRect(in: bounds),
            PulseIslandLayout.surfaceFrame(for: .seed, in: bounds)
        )

        controller.setHovering(true)

        XCTAssertEqual(
            controller.contentRect(in: bounds),
            PulseIslandLayout.surfaceFrame(for: .expanded, in: bounds)
        )
    }

    @MainActor
    func testIslandControllerSuppressesPostLaunchHoverUntilDeadlinePasses() {
        let now = Date()
        let deadline = now.addingTimeInterval(0.45)

        XCTAssertTrue(PulseIslandPanelController.shouldAcceptHoverExpansion(
            now: now,
            suppressionDeadline: nil
        ))
        XCTAssertFalse(PulseIslandPanelController.shouldAcceptHoverExpansion(
            now: now,
            suppressionDeadline: deadline
        ))
        XCTAssertTrue(PulseIslandPanelController.shouldAcceptHoverExpansion(
            now: deadline,
            suppressionDeadline: deadline
        ))
    }

    @MainActor
    func testIslandPanelExpandsWhenHoverBegins() {
        let controller = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        controller.setHovering(true)

        XCTAssertEqual(controller.style, .expanded)
    }

    @MainActor
    func testIslandPanelSuppressesImmediateHoverAfterLaunchingApplication() {
        let controller = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)
        let now = Date()

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        controller.collapseAfterLaunchingApplication(now: now)
        controller.setHovering(true, now: now)
        XCTAssertEqual(controller.style, .seed)

        controller.setHovering(true, now: now.addingTimeInterval(1))
        XCTAssertEqual(controller.style, .expanded)
    }

    #if DEBUG
    @MainActor
    func testIslandPanelKeepsRecordingControlsCollapsedWhenHoverBegins() {
        let controller = PulseIslandPanelController()

        controller.setScreenRecordingStateForTesting(.recording(Self.makeScreenRecordingSession()))
        controller.setHovering(true)

        XCTAssertEqual(controller.style, .seed)
    }

    @MainActor
    func testIslandPanelKeepsRecordingControlsCollapsedWhenTapped() {
        let controller = PulseIslandPanelController()

        controller.setScreenRecordingStateForTesting(.recording(Self.makeScreenRecordingSession()))
        controller.toggleStyle()

        XCTAssertEqual(controller.style, .seed)
    }

    @MainActor
    func testIslandPanelReturnsToCollapsedControlsWhenRecordingBeginsFromExpandedPanel() {
        let controller = PulseIslandPanelController()

        controller.toggleStyle()
        XCTAssertEqual(controller.style, .expanded)

        controller.setScreenRecordingStateForTesting(.recording(Self.makeScreenRecordingSession()))

        XCTAssertEqual(controller.style, .seed)
    }
    #endif

    @MainActor
    func testIslandPanelWakeSelectsModuleAndExpands() {
        let controller = PulseIslandPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)

        controller.wake(
            module: .clipboard,
            store: store,
            updateController: updateController
        )
        defer {
            controller.dismiss()
        }

        XCTAssertTrue(controller.isPresented)
        XCTAssertEqual(controller.style, .expanded)
        XCTAssertEqual(controller.selectedModule, .clipboard)
    }

    @MainActor
    func testIslandHoverCollapseDefersWhileMouseButtonIsPressed() {
        XCTAssertFalse(PulseIslandPanelController.shouldDeferHoverCollapse(pressedMouseButtons: 0))
        XCTAssertTrue(PulseIslandPanelController.shouldDeferHoverCollapse(pressedMouseButtons: 1))
        XCTAssertTrue(PulseIslandPanelController.shouldDeferHoverCollapse(pressedMouseButtons: 1 << 1))
        XCTAssertTrue(PulseIslandPanelController.shouldDeferHoverCollapse(pressedMouseButtons: 1 << 2))
    }

    @MainActor
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "pulse.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    private func makeLoginItemService() -> PulseLoginItemService {
        PulseLoginItemService(
            currentStatus: { .enabled },
            apply: { enabled in enabled ? .enabled : .notRegistered }
        )
    }

    private static func makeScreenRecordingSession() -> PulseScreenRecordingSession {
        PulseScreenRecordingSession(
            id: UUID(),
            mode: .fullScreen,
            startedAt: Date(),
            outputURL: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("pulse-screen-recording-test.mov")
        )
    }
}
