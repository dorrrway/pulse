import SwiftUI

struct PulseSettingsView: View {
    @Environment(PulseStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let strings = store.strings

        Form {
            Section(strings.text(.startup)) {
                Toggle(
                    strings.text(.launchAtLogin),
                    isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    )
                )

                LabeledContent(strings.text(.loginItemStatus)) {
                    Text(strings.loginItemStatus(store.launchAtLoginStatus))
                        .foregroundStyle(.secondary)
                }

                Text(strings.text(.launchAtLoginDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = store.launchAtLoginError {
                    Text(strings.loginItemError(error))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(strings.text(.language)) {
                Picker(strings.text(.language), selection: $store.languagePreference) {
                    Text(strings.text(.followSystem))
                        .tag(PulseLanguagePreference.system)
                    Text(strings.text(.english))
                        .tag(PulseLanguagePreference.english)
                    Text(strings.text(.chinese))
                        .tag(PulseLanguagePreference.chinese)
                }
                .pickerStyle(.segmented)

                Text(strings.text(.languageDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(strings.text(.pulseSettings))
        .frame(width: 460, height: 300)
        .onAppear {
            store.refreshLaunchAtLoginStatus()
        }
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
