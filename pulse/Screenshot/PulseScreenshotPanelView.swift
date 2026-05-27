import SwiftUI

struct PulseScreenshotPanelView: View {
    @Environment(PulseStore.self) private var store

    var captureAction: (PulseScreenshotMode) -> Void

    var body: some View {
        let strings = store.strings

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.sm) {
            ForEach(PulseScreenshotMode.allCases) { mode in
                PulseScreenshotModeButton(
                    mode: mode,
                    title: strings.screenshotModeTitle(mode),
                    shortcut: store.shortcutPreferences.shortcut(for: mode.shortcutAction),
                    shortcutPlaceholder: strings.text(.shortcutNotSet),
                    shortcutRecordingTitle: strings.text(.shortcutRecording),
                    clearShortcutTitle: strings.text(.clearShortcut),
                    shortcutAction: { shortcut in
                        store.setShortcut(shortcut, for: mode.shortcutAction)
                    },
                    clearShortcutAction: {
                        store.setShortcut(nil, for: mode.shortcutAction)
                    }
                ) {
                    captureAction(mode)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulsePanelLayout.outerPadding)
        .padding(.top, PulsePanelLayout.outerPadding)
        .padding(.bottom, PulsePanelLayout.footerBottomPadding)
        .frame(
            width: PulseIslandLayout.attachedPanelSize.width,
            height: PulseIslandLayout.attachedPanelSize.height,
            alignment: .top
        )
    }
}

private struct PulseScreenshotModeButton: View {
    var mode: PulseScreenshotMode
    var title: String
    var shortcut: PulseKeyboardShortcut?
    var shortcutPlaceholder: String
    var shortcutRecordingTitle: String
    var clearShortcutTitle: String
    var shortcutAction: (PulseKeyboardShortcut?) -> Void
    var clearShortcutAction: () -> Void
    var action: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: action) {
                HStack(spacing: PulseDesign.Spacing.sm) {
                    Image(mode.iconAssetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.leading, PulseDesign.Spacing.md)
                .padding(.trailing, Self.trailingControlFootprint)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)

            HStack(spacing: PulseDesign.Spacing.sm) {
                PulseShortcutRecorder(
                    shortcut: shortcut,
                    placeholder: shortcutPlaceholder,
                    recordingTitle: shortcutRecordingTitle,
                    onChange: shortcutAction
                )
                .frame(width: Self.shortcutRecorderWidth, height: 24)

                Button(action: clearShortcutAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .frame(width: Self.clearButtonSide, height: Self.clearButtonSide)
                }
                .buttonStyle(.plain)
                .help(clearShortcutTitle)
                .accessibilityLabel(clearShortcutTitle)
                .opacity(shortcut == nil ? 0 : 1)
                .disabled(shortcut == nil)
            }
            .padding(.trailing, PulseDesign.Spacing.md)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private static let shortcutRecorderWidth: CGFloat = 112
    private static let clearButtonSide: CGFloat = 18
    private static var trailingControlFootprint: CGFloat {
        shortcutRecorderWidth + clearButtonSide + PulseDesign.Spacing.sm * 2 + PulseDesign.Spacing.md
    }
}

#Preview {
    PulseScreenshotPanelView { _ in }
        .environment(
            PulseStore(
                launchAtLoginService: PulseLoginItemService(
                    currentStatus: { .enabled },
                    apply: { enabled in enabled ? .enabled : .notRegistered }
                ),
                reconcileLaunchAtLogin: false
            )
        )
        .background(.black)
}
