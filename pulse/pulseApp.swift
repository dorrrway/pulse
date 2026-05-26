//
//  pulseApp.swift
//  pulse
//
//  Created by 韩伟 on 5/2/26.
//

import Darwin
import AppKit
import SwiftUI

private final class PulseAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var didFinishLaunching: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            Self.didFinishLaunching?()
        }
    }
}

@main
struct PulseApp: App {
    private static let instanceLock = AppInstanceLock(
        identifier: Bundle.main.bundleIdentifier ?? "com.timelikesilver.pulse"
    )

    @NSApplicationDelegateAdaptor(PulseAppDelegate.self) private var appDelegate
    @State private var store: PulseStore
    @State private var pinnedPanelController: PulsePinnedPanelController
    @State private var islandPanelController: PulseIslandPanelController
    @State private var updateController: PulseUpdateController

    init() {
        let isRunningUnitTests = Self.isRunningUnitTests
        let store = PulseStore(
            startSamplingImmediately: !isRunningUnitTests,
            startClipboardImmediately: !isRunningUnitTests
        )
        let pinnedPanelController = PulsePinnedPanelController()
        let islandPanelController = PulseIslandPanelController()
        let updateController = PulseUpdateController(startingUpdater: !isRunningUnitTests)
        pinnedPanelController.presentationDidChange = { [weak islandPanelController] isPresented in
            islandPanelController?.setPinnedPanelPresented(isPresented)
        }

        _store = State(initialValue: store)
        _pinnedPanelController = State(initialValue: pinnedPanelController)
        _islandPanelController = State(initialValue: islandPanelController)
        _updateController = State(initialValue: updateController)

        guard !Self.isRunningUnitTests else {
            return
        }

        guard Self.instanceLock.acquire() else {
            Darwin.exit(EXIT_SUCCESS)
        }

        PulseAppDelegate.didFinishLaunching = {
            islandPanelController.present(
                store: store,
                updateController: updateController,
                pinAction: {
                    pinnedPanelController.toggle(store: store, updateController: updateController)
                },
                isPinnedPanelPresented: pinnedPanelController.isPresented
            )
        }
    }

    var body: some Scene {
        Settings {
            PulseSettingsView()
                .environment(store)
                .environment(updateController)
                #if DEBUG
                .environment(\.pulseIslandPreviewCriticalAlerts) { alerts in
                    previewCriticalAlerts(alerts)
                }
                #endif
                .pulsePreferredAppearance(store)
        }
    }

    private func presentIsland() {
        islandPanelController.present(
            store: store,
            updateController: updateController,
            pinAction: islandPinAction(),
            isPinnedPanelPresented: pinnedPanelController.isPresented
        )
    }

    #if DEBUG
    private func previewCriticalAlerts(_ alerts: [PulseIslandCriticalAlert]) {
        presentIsland()
        islandPanelController.presentCriticalAlertPreview(alerts)
    }
    #endif

    private func islandPinAction() -> () -> Void {
        let pinnedPanelController = pinnedPanelController
        let store = store
        let updateController = updateController

        return {
            pinnedPanelController.toggle(store: store, updateController: updateController)
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
