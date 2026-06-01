import SwiftUI

struct PulseSettingsView: View {
    @Environment(PulseStore.self) private var store
    @Environment(\.openURL) private var openURL
    #if DEBUG
    @Environment(\.pulseIslandPreviewCriticalAlerts) private var previewCriticalAlerts
    #endif
    private let settingsControlHeight: CGFloat = 22
    private let websiteURL = URL(string: "https://timelikesilver.com/apps/pulse")

    var body: some View {
        @Bindable var store = store
        let strings = store.strings

        ZStack(alignment: .bottom) {
            Form {
                Section {
                    HStack(alignment: .center) {
                        Text(strings.text(.launchAtLogin))
                        Spacer()

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.launchAtLogin },
                                set: { store.setLaunchAtLogin($0) }
                            )
                        )
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)
                    .frame(maxWidth: .infinity, alignment: .center)

                    if store.launchAtLoginError == nil, shouldShowLaunchAtLoginStatus(for: store) {
                        Text("\(strings.text(.loginItemStatus)): \(strings.loginItemStatus(store.launchAtLoginStatus))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let error = store.launchAtLoginError {
                        Text(strings.loginItemError(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack(alignment: .center) {
                        Text(strings.text(.language))

                        Picker("", selection: $store.languagePreference) {
                            Text(strings.text(.followSystem))
                                .tag(PulseLanguagePreference.system)
                            Text(strings.text(.english))
                                .tag(PulseLanguagePreference.english)
                            Text(strings.text(.chinese))
                                .tag(PulseLanguagePreference.chinese)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)
                    .frame(maxWidth: .infinity, alignment: .center)

                    HStack(alignment: .center) {
                        Text(strings.text(.appearance))

                        Picker("", selection: $store.appearancePreference) {
                            Text(strings.text(.followSystem))
                                .tag(PulseAppearancePreference.system)
                            Text(strings.text(.lightMode))
                                .tag(PulseAppearancePreference.light)
                            Text(strings.text(.darkMode))
                                .tag(PulseAppearancePreference.dark)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section(strings.text(.clipboardSettings)) {
                    HStack(alignment: .center) {
                        Text(strings.text(.clipboardOCR))
                        Spacer()

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.clipboardHistory.ocrEnabled },
                                set: { store.clipboardHistory.ocrEnabled = $0 }
                            )
                        )
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)

                    HStack(alignment: .center) {
                        Text(strings.text(.clipboardRetentionLimit))

                        Picker(
                            "",
                            selection: Binding(
                                get: { store.clipboardHistory.retentionLimit },
                                set: { store.clipboardHistory.retentionLimit = $0 }
                            )
                        ) {
                            ForEach(ClipboardHistoryStore.retentionLimitOptions, id: \.self) { limit in
                                Text(strings.clipboardRetentionLimitLabel(limit))
                                    .tag(limit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)

                    HStack(alignment: .center) {
                        Text(strings.text(.clipboardRetentionDays))

                        Picker(
                            "",
                            selection: Binding(
                                get: { store.clipboardHistory.retentionDays },
                                set: { store.clipboardHistory.retentionDays = $0 }
                            )
                        ) {
                            ForEach(ClipboardHistoryStore.retentionDayOptions, id: \.self) { days in
                                Text(strings.clipboardRetentionDaysLabel(days))
                                    .tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(height: settingsControlHeight)
                    }
                    .frame(height: settingsControlHeight)
                }

                Section(strings.text(.shortcutsSettings)) {
                    shortcutRow(
                        title: strings.text(.wakeClipboardShortcut),
                        action: .wakeClipboard,
                        shortcut: store.wakeClipboardShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.wakeApplicationsShortcut),
                        action: .wakeApplications,
                        shortcut: store.wakeApplicationsShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.captureFullScreenShortcut),
                        action: .captureFullScreen,
                        shortcut: store.captureFullScreenShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.captureWindowShortcut),
                        action: .captureWindow,
                        shortcut: store.captureWindowShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.captureSelectionShortcut),
                        action: .captureSelection,
                        shortcut: store.captureSelectionShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.recordFullScreenShortcut),
                        action: .recordFullScreen,
                        shortcut: store.recordFullScreenShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.recordWindowShortcut),
                        action: .recordWindow,
                        shortcut: store.recordWindowShortcut,
                        strings: strings
                    )

                    shortcutRow(
                        title: strings.text(.recordSelectionShortcut),
                        action: .recordSelection,
                        shortcut: store.recordSelectionShortcut,
                        strings: strings
                    )
                }

                #if DEBUG
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ViewThatFits(in: .horizontal) {
                            previewButtonRow(strings: strings)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    previewButton(title: strings.islandBatteryLevelTitle(), alerts: [.power])
                                    previewButton(
                                        title: strings.text(.bluetooth),
                                        alerts: [PulseIslandCriticalAlert.previewBluetoothBattery]
                                    )
                                    previewButton(title: strings.text(.thermal), alerts: [.thermal])
                                    previewButton(title: strings.text(.disk), alerts: [.disk])
                                }

                                HStack(spacing: 8) {
                                    previewButton(title: strings.text(.memoryPressure), alerts: [.memory])
                                    previewButton(
                                        title: previewAllTitle(strings: strings),
                                        alerts: PulseIslandCriticalAlert.previewCases
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #endif

                Section {
                    HStack(alignment: .center) {
                        Text(strings.text(.contactUs))
                        Spacer()

                        Button {
                            openURLIfNeeded(websiteURL)
                        } label: {
                            Image(systemName: "safari")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 20, height: 20)
                        }
                        .frame(height: settingsControlHeight)
                        .buttonStyle(.plain)
                        .accessibilityLabel(strings.text(.pulseWebsite))
                    }
                    .frame(height: settingsControlHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .formStyle(.grouped)

            Text(appVersionLabel(strings: strings))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)
        }
        .navigationTitle(strings.text(.pulseSettings))
        .frame(width: 460, height: settingsWindowHeight)
        .onAppear {
            store.refreshLaunchAtLoginStatus()
        }
    }
}

private extension PulseSettingsView {
    func shouldShowLaunchAtLoginStatus(for store: PulseStore) -> Bool {
        if store.launchAtLogin {
            return store.launchAtLoginStatus != .enabled
        }

        return store.launchAtLoginStatus != .notRegistered
    }

    func openURLIfNeeded(_ url: URL?) {
        guard let url else {
            return
        }

        openURL(url)
    }

    func appVersionLabel(strings: PulseStrings) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(strings.text(.appVersion)) \(version ?? "Unknown")"
    }

    func shortcutRow(
        title: String,
        action: PulseShortcutAction,
        shortcut: PulseKeyboardShortcut?,
        strings: PulseStrings
    ) -> some View {
        HStack(alignment: .center) {
            Text(title)
            Spacer()

            PulseShortcutRecorder(
                shortcut: shortcut,
                placeholder: strings.text(.shortcutNotSet),
                recordingTitle: strings.text(.shortcutRecording),
                onChange: { store.setShortcut($0, for: action) }
            )
            .frame(width: 150, height: settingsControlHeight)

            Button {
                store.setShortcut(nil, for: action)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(strings.text(.clearShortcut))
            .accessibilityLabel(strings.text(.clearShortcut))
            .opacity(shortcut == nil ? 0 : 1)
            .disabled(shortcut == nil)
        }
        .frame(height: settingsControlHeight)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var settingsWindowHeight: CGFloat {
        #if DEBUG
        return 748
        #else
        return 662
        #endif
    }

    #if DEBUG
    func previewButtonRow(strings: PulseStrings) -> some View {
        HStack(spacing: 8) {
            previewButton(title: strings.islandBatteryLevelTitle(), alerts: [.power])
            previewButton(
                title: strings.text(.bluetooth),
                alerts: [PulseIslandCriticalAlert.previewBluetoothBattery]
            )
            previewButton(title: strings.text(.thermal), alerts: [.thermal])
            previewButton(title: strings.text(.disk), alerts: [.disk])
            previewButton(title: strings.text(.memoryPressure), alerts: [.memory])
            previewButton(title: previewAllTitle(strings: strings), alerts: PulseIslandCriticalAlert.previewCases)
        }
    }

    func previewButton(title: String, alerts: [PulseIslandCriticalAlert]) -> some View {
        Button(title) {
            previewCriticalAlerts(alerts)
        }
        .controlSize(.small)
    }

    func previewAllTitle(strings: PulseStrings) -> String {
        switch strings.language {
        case .english:
            return "All"
        case .chinese:
            return "全部"
        }
    }
    #endif
}

#Preview {
    PulseSettingsView()
        .environment(
            PulseStore(
                launchAtLoginService: PulseLoginItemService(
                    currentStatus: { .enabled },
                    apply: { enabled in enabled ? .enabled : .notRegistered }
                ),
                reconcileLaunchAtLogin: false
            )
        )
}
