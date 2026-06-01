import AppKit
import SwiftUI

struct PulseScreenshotPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var hasScreenCaptureAccess: Bool

    var preflightScreenCaptureAccess: @MainActor () -> Bool
    var requestScreenCaptureAccess: @MainActor () -> Bool
    var openScreenCaptureSettings: @MainActor () -> Void
    var captureAction: (PulseScreenshotMode) -> Void
    var recordingState: PulseScreenRecordingState
    var recordAction: (PulseScreenshotMode) -> Void
    var stopRecordingAction: () -> Void

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
        recordingState: PulseScreenRecordingState = .idle,
        recordAction: @escaping (PulseScreenshotMode) -> Void = { _ in },
        stopRecordingAction: @escaping () -> Void = {},
        captureAction: @escaping (PulseScreenshotMode) -> Void
    ) {
        self.preflightScreenCaptureAccess = preflightScreenCaptureAccess
        self.requestScreenCaptureAccess = requestScreenCaptureAccess
        self.openScreenCaptureSettings = openScreenCaptureSettings
        self.captureAction = captureAction
        self.recordingState = recordingState
        self.recordAction = recordAction
        self.stopRecordingAction = stopRecordingAction
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

            VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
                Text(strings.text(.screenshotSectionTitle))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .textCase(.uppercase)

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
            }

            VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
                Text(strings.text(.screenRecordingSectionTitle))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .textCase(.uppercase)

                ForEach(PulseScreenshotMode.allCases) { mode in
                    PulseScreenRecordingModeButton(
                        mode: mode,
                        title: screenRecordingButtonTitle(mode: mode, strings: strings),
                        shortcut: store.shortcutPreferences.shortcut(for: mode.screenRecordingShortcutAction),
                        shortcutPlaceholder: strings.text(.shortcutNotSet),
                        shortcutRecordingTitle: strings.text(.shortcutRecording),
                        clearShortcutTitle: strings.text(.clearShortcut),
                        isActive: recordingState.activeSession?.mode == mode,
                        isDisabled: isScreenRecordingButtonDisabled(mode),
                        areShortcutControlsDisabled: recordingState.isBusy,
                        shortcutAction: { shortcut in
                            store.setShortcut(shortcut, for: mode.screenRecordingShortcutAction)
                        },
                        clearShortcutAction: {
                            store.setShortcut(nil, for: mode.screenRecordingShortcutAction)
                        }
                    ) {
                        if recordingState.activeSession?.mode == mode {
                            stopRecordingAction()
                        } else {
                            recordAction(mode)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
                Text(strings.text(.settings))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .textCase(.uppercase)

                VStack(spacing: PulseDesign.Spacing.xxs) {
                    PulseScreenshotOptionRow(
                        title: strings.text(.screenshotHidePulseDuringCapture),
                        detail: strings.text(.screenshotHidePulseDuringCaptureDetail),
                        icon: .system("eye.slash.fill"),
                        isOn: Binding(
                            get: { store.hidePulseDuringScreenshots },
                            set: { store.setHidePulseDuringScreenshots($0) }
                        )
                    )

                    PulseScreenshotOptionRow(
                        title: strings.text(.screenRecordingHideCursorDuringCapture),
                        detail: strings.text(.screenRecordingHideCursorDuringCaptureDetail),
                        icon: .asset("ScreenshotMouseIcon"),
                        isOn: Binding(
                            get: { store.hideCursorDuringScreenRecordings },
                            set: { store.setHideCursorDuringScreenRecordings($0) }
                        )
                    )
                }
            }
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

    private func screenRecordingButtonTitle(mode: PulseScreenshotMode, strings: PulseStrings) -> String {
        switch recordingState {
        case .starting(let startingMode) where startingMode == mode:
            strings.text(.screenRecordingPreparing)
        case .recording(let session) where session.mode == mode:
            strings.text(.screenRecordingStopAction)
        case .stopping(let session) where session.mode == mode:
            strings.text(.screenRecordingSaving)
        default:
            strings.screenRecordingModeTitle(mode)
        }
    }

    private func isScreenRecordingButtonDisabled(_ mode: PulseScreenshotMode) -> Bool {
        switch recordingState {
        case .idle:
            false
        case .starting, .stopping:
            true
        case .recording(let session):
            session.mode != mode
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

private struct PulseScreenshotOptionRow: View {
    var title: String
    var detail: String
    var icon: PulseScreenshotOptionIcon
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            iconView
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: PulseDesign.Spacing.sm)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(PulseScreenshotFooterSwitchStyle())
        }
        .padding(.leading, PulseDesign.Spacing.md)
        .padding(.trailing, PulseDesign.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .help(detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }

    private static let rowHeight: CGFloat = 46

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}

private enum PulseScreenshotOptionIcon {
    case system(String)
    case asset(String)
}

private struct PulseScreenRecordingModeButton: View {
    var mode: PulseScreenshotMode
    var title: String
    var shortcut: PulseKeyboardShortcut?
    var shortcutPlaceholder: String
    var shortcutRecordingTitle: String
    var clearShortcutTitle: String
    var isActive: Bool
    var isDisabled: Bool
    var areShortcutControlsDisabled: Bool
    var shortcutAction: (PulseKeyboardShortcut?) -> Void
    var clearShortcutAction: () -> Void
    var action: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: action) {
                HStack(spacing: PulseDesign.Spacing.sm) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(mode.iconAssetName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .frame(width: 28, height: 28)

                        Circle()
                            .fill(isActive ? .red.opacity(0.98) : .white.opacity(0.70))
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .stroke(.black.opacity(0.50), lineWidth: 1)
                            }
                            .offset(x: -2, y: -2)
                    }
                    .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.leading, PulseDesign.Spacing.md)
                .padding(.trailing, Self.trailingControlFootprint)
                .foregroundStyle(.white.opacity(isDisabled ? 0.38 : 0.9))
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .help(title)
            .accessibilityLabel(title)

            HStack(spacing: PulseDesign.Spacing.sm) {
                PulseShortcutRecorder(
                    shortcut: shortcut,
                    placeholder: shortcutPlaceholder,
                    recordingTitle: shortcutRecordingTitle,
                    isEnabled: !areShortcutControlsDisabled,
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
                .disabled(shortcut == nil || areShortcutControlsDisabled)
            }
            .disabled(areShortcutControlsDisabled)
            .padding(.trailing, PulseDesign.Spacing.md)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(
            (isActive ? Color.red.opacity(0.16) : Color.white.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(isActive ? .red.opacity(0.34) : .white.opacity(0.08), lineWidth: 1)
        }
    }

    private static let shortcutRecorderWidth: CGFloat = 112
    private static let clearButtonSide: CGFloat = 18
    private static var trailingControlFootprint: CGFloat {
        shortcutRecorderWidth + clearButtonSide + PulseDesign.Spacing.sm * 2 + PulseDesign.Spacing.md
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
