import AppKit
import SwiftUI

@MainActor
final class ApplicationUninstallWindowController: NSObject, NSWindowDelegate {
    private var windowsByApplicationID: [InstalledApplication.ID: NSWindow] = [:]
    private var applicationIDsByWindow: [ObjectIdentifier: InstalledApplication.ID] = [:]

    private static let contentSize = CGSize(width: 580, height: 520)

    func present(application: InstalledApplication, store: PulseStore) {
        if let window = windowsByApplicationID[application.id] {
            show(window)
            return
        }

        let window = makeWindow(application: application, store: store)
        windowsByApplicationID[application.id] = window
        applicationIDsByWindow[ObjectIdentifier(window)] = application.id
        show(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        let identifier = ObjectIdentifier(window)
        if let applicationID = applicationIDsByWindow.removeValue(forKey: identifier) {
            windowsByApplicationID[applicationID] = nil
        }
    }

    private func makeWindow(application: InstalledApplication, store: PulseStore) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = store.strings.applicationUninstallTitle(application.name)
        window.identifier = NSUserInterfaceItemIdentifier("ApplicationUninstallWindow-\(application.id)")
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.managed]
        window.isMovableByWindowBackground = true
        window.contentMinSize = Self.contentSize
        window.contentMaxSize = Self.contentSize
        window.delegate = self

        let rootView = ApplicationUninstallConfirmationView(
            application: application,
            strings: store.strings,
            closeAction: { [weak window] in
                window?.close()
            }
        ) { [weak store] completedApplication in
            store?.removeFavoriteApplication(completedApplication)
            store?.refreshInstalledApplicationsIfNeeded(force: true)
            store?.refreshRunningApplications()
        }
        .pulsePreferredAppearance(store)

        window.contentViewController = NSHostingController(rootView: rootView)
        window.center()

        return window
    }

    private func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
