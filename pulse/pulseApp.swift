//
//  pulseApp.swift
//  pulse
//
//  Created by 韩伟 on 5/2/26.
//

import Darwin
import SwiftUI

@main
struct PulseApp: App {
    private static let instanceLock = AppInstanceLock(
        identifier: Bundle.main.bundleIdentifier ?? "com.timelikesilver.pulse"
    )

    @State private var store = PulseStore(startSamplingImmediately: !Self.isRunningUnitTests)
    @State private var pinnedPanelController = PulsePinnedPanelController()
    @State private var updateController = PulseUpdateController(startingUpdater: !Self.isRunningUnitTests)

    init() {
        guard !Self.isRunningUnitTests else {
            return
        }

        guard Self.instanceLock.acquire() else {
            Darwin.exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        MenuBarExtra(
            "Pulse",
            image: "PulseMenuBarIcon",
            isInserted: .constant(!Self.isRunningUnitTests)
        ) {
            PulsePanelView()
                .environment(store)
                .environment(updateController)
                .environment(\.pulsePanelIsPinned, pinnedPanelController.isPresented)
                .environment(\.pulsePanelPinAction) {
                    pinnedPanelController.toggle(store: store, updateController: updateController)
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            PulseSettingsView()
                .environment(store)
                .environment(updateController)
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
