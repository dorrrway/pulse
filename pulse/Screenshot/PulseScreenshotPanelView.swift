import AppKit
import SwiftUI

struct PulseScreenshotPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var hasScreenCaptureAccess: Bool

    var preflightScreenCaptureAccess: @MainActor () -> Bool
    var requestScreenCaptureAccess: @MainActor () -> Bool
    var openScreenCaptureSettings: @MainActor () -> Void
    var captureAction: (PulseScreenshotMode) -> Void

    init(
        screenCaptureAccessGranted: Bool? = nil,
        preflightScreenCaptureAccess: @escaping @MainActor () -> Bool = {
            PulseScreenshotService.live.preflightAccess()
        },
        requestScreenCaptureAccess: @escaping @MainActor () -> Bool = {
            PulseScreenshotService.live.requestAccess()
        },
        openScreenCaptureSettings: @escaping @MainActor () -> Void = {
            PulseScreenshotService.live.openScreenCaptureSettings()
        },
        captureAction: @escaping (PulseScreenshotMode) -> Void
    ) {
        self.preflightScreenCaptureAccess = preflightScreenCaptureAccess
        self.requestScreenCaptureAccess = requestScreenCaptureAccess
        self.openScreenCaptureSettings = openScreenCaptureSettings
        self.captureAction = captureAction
        _hasScreenCaptureAccess = State(initialValue: screenCaptureAccessGranted ?? true)
    }

    var body: some View {
        let strings = store.strings

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.sm) {
            if !hasScreenCaptureAccess {
                PulseScreenshotPermissionBanner(
                    message: strings.text(.screenshotScreenRecordingPermissionNotice),
                    authorizeTitle: strings.text(.screenshotAuthorizeScreenRecording),
                    authorizeAction: requestScreenCapturePermission
                )
            }

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

            PulseScreenshotOptionsFooter(
                title: strings.text(.screenshotHidePulseDuringCapture),
                detail: strings.text(.screenshotHidePulseDuringCaptureDetail),
                isOn: Binding(
                    get: { store.hidePulseDuringScreenshots },
                    set: { store.setHidePulseDuringScreenshots($0) }
                )
            )
            .padding(.top, PulsePanelLayout.footerTopSpacing)
        }
        .padding(.horizontal, PulsePanelLayout.outerPadding)
        .padding(.top, PulsePanelLayout.outerPadding)
        .padding(.bottom, PulsePanelLayout.footerBottomPadding)
        .frame(
            width: PulseIslandLayout.attachedPanelSize.width,
            height: PulseIslandLayout.attachedPanelSize.height,
            alignment: .top
        )
        .onAppear(perform: refreshScreenCaptureAccess)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshScreenCaptureAccess()
        }
    }

    @MainActor
    private func refreshScreenCaptureAccess() {
        hasScreenCaptureAccess = preflightScreenCaptureAccess()
    }

    @MainActor
    private func requestScreenCapturePermission() {
        if preflightScreenCaptureAccess() {
            hasScreenCaptureAccess = true
            return
        }

        if requestScreenCaptureAccess() {
            hasScreenCaptureAccess = preflightScreenCaptureAccess()
            return
        }

        hasScreenCaptureAccess = false
        openScreenCaptureSettings()
    }
}

private struct PulseScreenshotOptionsFooter: View {
    var title: String
    var detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Spacer(minLength: 0)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(PulseScreenshotFooterSwitchStyle())
        }
        .frame(maxWidth: .infinity, minHeight: PulsePanelLayout.footerHeight, alignment: .trailing)
        .help(detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

private struct PulseScreenshotFooterSwitchStyle: ToggleStyle {
    private let trackSize = CGSize(width: 38, height: 22)
    private let knobSide: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(trackFill(isOn: configuration.isOn))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(configuration.isOn ? 0.12 : 0.08), lineWidth: 1)
                    }

                Circle()
                    .fill(.white.opacity(0.96))
                    .frame(width: knobSide, height: knobSide)
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                    .padding(2)
            }
            .frame(width: trackSize.width, height: trackSize.height)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func trackFill(isOn: Bool) -> Color {
        isOn ? .green.opacity(0.92) : .white.opacity(0.18)
    }
}

private struct PulseScreenshotPermissionBanner: View {
    var message: String
    var authorizeTitle: String
    var authorizeAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: PulseDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.96))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: PulseDesign.Spacing.xs)

            Button(action: authorizeAction) {
                Text(authorizeTitle)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.96))
                    .lineLimit(1)
                    .padding(.horizontal, PulseDesign.Spacing.sm)
                    .frame(height: 26)
                    .background(
                        .orange.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(authorizeTitle)
        }
        .padding(.horizontal, PulseDesign.Spacing.sm)
        .padding(.vertical, PulseDesign.Spacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .orange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(.orange.opacity(0.28), lineWidth: 1)
        }
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
    PulseScreenshotPanelView(
        screenCaptureAccessGranted: false,
        preflightScreenCaptureAccess: { false },
        requestScreenCaptureAccess: { false },
        openScreenCaptureSettings: {}
    ) { _ in }
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
