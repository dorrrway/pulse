import SwiftUI

struct PulseSettingsView: View {
    @Environment(PulseStore.self) private var store
    @Environment(\.openURL) private var openURL
    private let settingsControlHeight: CGFloat = 22
    private let websiteURL = URL(string: "https://timelikesilver.com/apps/pulse")

    var body: some View {
        @Bindable var store = store
        let strings = store.strings

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
        .navigationTitle(strings.text(.pulseSettings))
        .frame(width: 460, height: 326)
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
