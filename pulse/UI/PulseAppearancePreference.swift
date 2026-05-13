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
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }
}

private struct PulsePreferredAppearanceWindowReader: NSViewRepresentable {
    var preference: PulseAppearancePreference

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyPreference(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyPreference(to: nsView)
    }

    private func applyPreference(to view: NSView) {
        DispatchQueue.main.async {
            view.window?.appearance = preference.nsAppearance
        }
    }
}

private struct PulsePreferredAppearanceModifier: ViewModifier {
    let store: PulseStore

    func body(content: Content) -> some View {
        let preference = store.appearancePreference

        content
            .preferredColorScheme(preference.colorScheme)
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
