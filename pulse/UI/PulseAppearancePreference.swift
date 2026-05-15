import AppKit
import SwiftUI

nonisolated enum PulseAppearancePreference: String, Sendable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            Self.systemResolvedNSAppearance
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    func apply(to window: NSWindow) {
        let appearance = nsAppearance
        window.appearance = appearance
        window.contentView?.appearance = appearance
        window.contentView?.needsLayout = true
        window.contentView?.needsDisplay = true
        window.invalidateShadow()
        window.displayIfNeeded()
    }

    private static var systemResolvedNSAppearance: NSAppearance? {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        return NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}

private struct PulsePreferredAppearanceWindowReader: NSViewRepresentable {
    var preference: PulseAppearancePreference

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.preference = preference
        context.coordinator.applyPreference(to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.preference = preference
        context.coordinator.applyPreference(to: view)
    }

    final class Coordinator: NSObject {
        var preference: PulseAppearancePreference = .system
        private weak var view: NSView?
        private var isObservingSystemAppearance = false

        deinit {
            DistributedNotificationCenter.default().removeObserver(self)
        }

        @MainActor
        func applyPreference(to view: NSView) {
            self.view = view
            updateThemeObserver()

            guard let window = view.window else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else {
                        return
                    }

                    self.applyPreference(to: view)
                }
                return
            }

            preference.apply(to: window)
        }

        @MainActor
        private func updateThemeObserver() {
            if preference == .system {
                guard !isObservingSystemAppearance else {
                    return
                }

                DistributedNotificationCenter.default().addObserver(
                    self,
                    selector: #selector(systemAppearanceDidChange),
                    name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                    object: nil
                )
                isObservingSystemAppearance = true
            } else if isObservingSystemAppearance {
                DistributedNotificationCenter.default().removeObserver(
                    self,
                    name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                    object: nil
                )
                isObservingSystemAppearance = false
            }
        }

        @objc
        private func systemAppearanceDidChange(_ notification: Notification) {
            Task { @MainActor in
                guard let view else {
                    return
                }

                applyPreference(to: view)
            }
        }
    }
}

private struct PulsePreferredAppearanceModifier: ViewModifier {
    let store: PulseStore

    func body(content: Content) -> some View {
        let preference = store.appearancePreference

        content
            .background {
                PulsePreferredAppearanceWindowReader(preference: preference)
            }
    }
}

extension View {
    func pulsePreferredAppearance(_ store: PulseStore) -> some View {
        modifier(PulsePreferredAppearanceModifier(store: store))
    }
}
