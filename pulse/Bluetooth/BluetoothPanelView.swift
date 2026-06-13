import AppKit
import SwiftUI

struct BluetoothPanelView: View {
    @Environment(PulseStore.self) private var store
    var bluetooth: BluetoothDeviceStore
    @State private var pendingDisconnectDevice: BluetoothDevice?

    private var collapseBeforeAuthorization: () -> Void

    init(
        bluetooth: BluetoothDeviceStore = BluetoothDeviceStore(),
        collapseBeforeAuthorization: @escaping () -> Void = {}
    ) {
        self.bluetooth = bluetooth
        self.collapseBeforeAuthorization = collapseBeforeAuthorization
    }

    var body: some View {
        let strings = store.strings

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            if !bluetooth.needsInitialAuthorization, bluetooth.isBluetoothPoweredOff {
                BluetoothPowerBanner(strings: strings, action: openBluetoothSettings)
            } else if !bluetooth.needsInitialAuthorization, let issue = bluetooth.issue {
                BluetoothIssueBanner(issue: issue, strings: strings)
            }

            content(strings: strings)
                .frame(maxHeight: .infinity, alignment: .top)

            footer(strings: strings)
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
        .onAppear {
            bluetooth.startMonitoring()
        }
        .onDisappear {
            bluetooth.stopMonitoring()
        }
        .confirmationDialog(
            strings.text(.bluetoothDisconnectConfirmationTitle),
            isPresented: isDisconnectConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(strings.text(.disconnectBluetoothDevice), role: .destructive, action: disconnectPendingDevice)
            Button(strings.text(.cancelBluetoothDisconnect), role: .cancel) {
                pendingDisconnectDevice = nil
            }
        } message: {
            Text(strings.bluetoothDisconnectConfirmationMessage(deviceName: pendingDisconnectDevice?.name ?? ""))
        }
    }

    @ViewBuilder
    private func content(strings: PulseStrings) -> some View {
        if bluetooth.needsInitialAuthorization {
            BluetoothAuthorizationPrompt(strings: strings, action: requestBluetoothAuthorization)
        } else if bluetooth.isBluetoothPoweredOff {
            BluetoothPoweredOffState(strings: strings)
        } else if bluetooth.devices.isEmpty && !bluetooth.isRefreshing {
            BluetoothEmptyState(strings: strings)
        } else {
            ScrollView {
                LazyVStack(spacing: PulseDesign.Spacing.xs) {
                    ForEach(bluetooth.devices) { device in
                        BluetoothDeviceRow(
                            device: device,
                            strings: strings,
                            isPerformingAction: bluetooth.activeActionDeviceID == device.id,
                            action: {
                                activate(device)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, PulseDesign.Spacing.micro)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func footer(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            BluetoothFooterActionButton(
                iconAssetName: "IslandBluetoothIcon",
                title: strings.text(.openBluetoothSettings)
            ) {
                openBluetoothSettings()
            }

            Spacer(minLength: 0)

            if !bluetooth.needsInitialAuthorization {
                HStack(spacing: PulseDesign.Spacing.xs) {
                    Text(strings.bluetoothDeviceCount(bluetooth.devices.count))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)

                    if bluetooth.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                    } else {
                        BluetoothIconButton(
                            systemName: "arrow.clockwise",
                            help: strings.text(.refreshBluetoothDevices)
                        ) {
                            bluetooth.refresh()
                        }
                    }
                }
            }
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private var isDisconnectConfirmationPresented: Binding<Bool> {
        Binding {
            pendingDisconnectDevice != nil
        } set: { isPresented in
            if !isPresented {
                pendingDisconnectDevice = nil
            }
        }
    }

    private func activate(_ device: BluetoothDevice) {
        guard device.supportsConnectionAction, bluetooth.activeActionDeviceID == nil else {
            return
        }

        if device.isConnected {
            pendingDisconnectDevice = device
        } else {
            bluetooth.connect(device)
        }
    }

    private func disconnectPendingDevice() {
        guard let pendingDisconnectDevice else {
            return
        }

        bluetooth.disconnect(pendingDisconnectDevice)
        self.pendingDisconnectDevice = nil
    }

    private func requestBluetoothAuthorization() {
        collapseBeforeAuthorization()
        Task { @MainActor in
            let status = await BluetoothAuthorizationRequester.shared.requestAfterPanelCollapse()
            if status.canSampleDevices {
                bluetooth.startBackgroundMonitoring()
            }
        }
    }

    private func openBluetoothSettings() {
        for urlString in [
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth",
        ] {
            guard let url = URL(string: urlString) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

private struct BluetoothDeviceRow: View {
    var device: BluetoothDevice
    var strings: PulseStrings
    var isPerformingAction: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            Button(action: action) {
                rowActionContent
            }
            .buttonStyle(.plain)
            .disabled(!device.supportsConnectionAction || isPerformingAction)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(actionHelp)
            .accessibilityLabel(device.name)
            .accessibilityHint(actionHelp)

            if device.hasBattery {
                BluetoothBatteryCluster(
                    device: device,
                    levels: device.batteryLevels,
                    strings: strings,
                    isConnected: device.isConnected
                )
                .fixedSize()
            }

            if isPerformingAction {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.xs)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            rowBackground,
            in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var rowActionContent: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            BluetoothSymbolImage(
                symbol: BluetoothDeviceSymbol.row(for: device),
                font: .system(size: 18, weight: .semibold),
                foregroundStyle: iconColor
            )
                .frame(width: 30, height: 30)
                .background(iconBackground, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PulseDesign.Spacing.xxs) {
                Text(device.name)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Text(statusText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            Spacer(minLength: PulseDesign.Spacing.sm)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var statusText: String {
        device.isConnected ? strings.text(.bluetoothConnected) : strings.text(.bluetoothDisconnected)
    }

    private var statusColor: Color {
        device.isConnected ? .green.opacity(0.88) : .white.opacity(0.38)
    }

    private var iconColor: Color {
        device.isConnected ? .white.opacity(0.88) : .white.opacity(0.46)
    }

    private var iconBackground: Color {
        .white.opacity(device.isConnected ? 0.08 : 0.045)
    }

    private var nameColor: Color {
        device.isConnected ? .white.opacity(0.92) : .white.opacity(PulseDesign.Opacity.secondaryOnDark)
    }

    private var rowBackground: Color {
        if device.isConnected {
            return .white.opacity(isHovering ? 0.11 : 0.07)
        }

        return .white.opacity(isHovering ? 0.075 : 0.045)
    }

    private var rowStroke: Color {
        if device.isConnected {
            return .white.opacity(isHovering ? 0.16 : 0.08)
        }

        return .white.opacity(isHovering ? 0.10 : 0.055)
    }

    private var actionHelp: String {
        device.isConnected ? strings.text(.disconnectBluetoothDevice) : strings.text(.connectBluetoothDevice)
    }

}

private struct BluetoothBatteryCluster: View {
    var device: BluetoothDevice
    var levels: [BluetoothBatteryLevel]
    var strings: PulseStrings
    var isConnected: Bool

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.fine) {
            ForEach(levels) { level in
                BluetoothBatteryRing(device: device, level: level, strings: strings)
            }
        }
        .opacity(isConnected ? 1 : 0.42)
        .accessibilityElement(children: .contain)
    }
}

private struct BluetoothBatteryRing: View {
    var device: BluetoothDevice
    var level: BluetoothBatteryLevel
    var strings: PulseStrings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingChargingSymbol = false

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.xxs) {
            ringContent
                .frame(width: 34, height: 34)

            Text(ResourceFormatters.percentage(level.percentage))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(width: 42)
        .accessibilityLabel(strings.bluetoothBatteryLabel(level))
        .onAppear(perform: updateChargingAnimation)
        .onChange(of: level.isCharging) { _, _ in
            updateChargingAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateChargingAnimation()
        }
    }

    private var ringContent: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            Circle()
                .trim(from: 0, to: level.percentage)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            centerSymbol
        }
    }

    private var centerSymbol: some View {
        ZStack {
            BluetoothSymbolImage(
                symbol: BluetoothDeviceSymbol.battery(for: device, role: level.role),
                font: .system(size: 13, weight: .semibold),
                foregroundStyle: .white.opacity(0.90)
            )
            .opacity(deviceSymbolOpacity)
            .scaleEffect(deviceSymbolScale)

            if level.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.green)
                    .opacity(chargingSymbolOpacity)
                    .scaleEffect(chargingSymbolScale)
                    .shadow(color: .black.opacity(0.36), radius: 1.2, x: 0, y: 0.6)
            }
        }
        .animation(chargingSymbolAnimation, value: isShowingChargingSymbol)
        .accessibilityHidden(true)
    }

    private var deviceSymbolOpacity: Double {
        guard level.isCharging else {
            return 1
        }

        if reduceMotion {
            return 0
        }

        return isShowingChargingSymbol ? 0.12 : 1
    }

    private var deviceSymbolScale: CGFloat {
        guard level.isCharging, !reduceMotion else {
            return 1
        }

        return isShowingChargingSymbol ? 0.82 : 1
    }

    private var chargingSymbolOpacity: Double {
        guard level.isCharging else {
            return 0
        }

        if reduceMotion {
            return 1
        }

        return isShowingChargingSymbol ? 1 : 0.08
    }

    private var chargingSymbolScale: CGFloat {
        guard level.isCharging, !reduceMotion else {
            return 1
        }

        return isShowingChargingSymbol ? 1.06 : 0.84
    }

    private var chargingSymbolAnimation: Animation? {
        guard level.isCharging, !reduceMotion else {
            return nil
        }

        return .easeInOut(duration: 1.35).repeatForever(autoreverses: true)
    }

    private func updateChargingAnimation() {
        guard level.isCharging, !reduceMotion else {
            isShowingChargingSymbol = false
            return
        }

        isShowingChargingSymbol = true
    }

    private var ringColor: Color {
        if level.isCharging {
            return .green
        }

        if level.percentage <= 0.1 {
            return .red
        }

        if level.percentage <= 0.2 {
            return .orange
        }

        return .green
    }
}

private struct BluetoothSymbolImage: View {
    var symbol: BluetoothDeviceSymbol
    var font: Font
    var foregroundStyle: Color

    var body: some View {
        Image(systemName: resolvedSystemName)
            .font(font)
            .foregroundStyle(foregroundStyle)
    }

    private var resolvedSystemName: String {
        symbol.candidates.first { candidate in
            NSImage(systemSymbolName: candidate, accessibilityDescription: nil) != nil
        } ?? BluetoothDeviceSymbol.fallbackName
    }
}

private struct BluetoothIconButton: View {
    var systemName: String
    var help: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovering ? 0.92 : 0.70))
                .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct BluetoothFooterActionButton: View {
    var iconAssetName: String
    var title: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseDesign.Spacing.xxs) {
                Image(iconAssetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }
            .foregroundStyle(.white.opacity(isHovering ? 0.82 : 0.64))
            .padding(.horizontal, PulseDesign.Spacing.xs)
            .frame(height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct BluetoothPowerBanner: View {
    var strings: PulseStrings
    var action: () -> Void

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.96))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.text(.bluetoothPoweredOffTitle))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)

                Text(strings.text(.bluetoothPoweredOffDetail))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer(minLength: PulseDesign.Spacing.xs)

            Button(action: action) {
                HStack(spacing: PulseDesign.Spacing.fine) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .heavy))
                        .accessibilityHidden(true)

                    Text(strings.text(.turnOnBluetooth))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .foregroundStyle(.black.opacity(0.82))
                .padding(.horizontal, PulseDesign.Spacing.xs)
                .frame(height: 26)
                .background(.orange.opacity(0.92), in: Capsule())
            }
            .buttonStyle(.plain)
            .help(strings.text(.openBluetoothSettings))
            .accessibilityLabel(strings.text(.turnOnBluetooth))
        }
        .padding(.horizontal, PulseDesign.Spacing.sm)
        .padding(.vertical, PulseDesign.Spacing.compact)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(.orange.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct BluetoothIssueBanner: View {
    var issue: BluetoothDeviceIssue
    var strings: PulseStrings

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.96))
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(2)

            Spacer(minLength: PulseDesign.Spacing.xs)

            if case .permission = issue {
                Button(strings.text(.openSystemSettings), action: openBluetoothPrivacySettings)
                    .buttonStyle(.plain)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.96))
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.sm)
        .padding(.vertical, PulseDesign.Spacing.compact)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .stroke(.orange.opacity(0.28), lineWidth: 1)
        }
    }

    private var message: String {
        switch issue {
        case .permission:
            strings.text(.bluetoothPermissionDetail)
        case .actionFailed:
            strings.text(.bluetoothActionFailed)
        }
    }

    private func openBluetoothPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct BluetoothAuthorizationPrompt: View {
    var strings: PulseStrings
    var action: () -> Void

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Image("IslandBluetoothIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 34, height: 34)
                    .frame(width: 66, height: 66)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }
                    .offset(x: 5, y: 5)
            }
            .accessibilityHidden(true)

            VStack(spacing: PulseDesign.Spacing.xxs) {
                Text(strings.text(.bluetoothAuthorizationTitle))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                Text(strings.text(.bluetoothAuthorizationDetail))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Text(strings.text(.authorizeBluetoothDeviceAccess))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.horizontal, PulseDesign.Spacing.lg)
                    .frame(height: 34)
                    .background(
                        .white.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.text(.authorizeBluetoothDeviceAccess))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, PulseDesign.Spacing.lg)
    }
}

private struct BluetoothPoweredOffState: View {
    var strings: PulseStrings

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.xs) {
            ZStack(alignment: .bottomTrailing) {
                Image("IslandBluetoothIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 30, height: 30)

                Image(systemName: "power.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.96))
                    .background(.black.opacity(0.24), in: Circle())
                    .offset(x: 7, y: 6)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            Text(strings.text(.bluetoothPoweredOffTitle))
                .font(PulseDesign.Typography.panelBody)
                .foregroundStyle(.white.opacity(0.82))

            Text(strings.text(.bluetoothPoweredOffDetail))
                .font(PulseDesign.Typography.panelLabel)
                .foregroundStyle(.white.opacity(PulseDesign.Opacity.secondaryOnDark))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, PulseDesign.Spacing.lg)
    }
}

private struct BluetoothEmptyState: View {
    var strings: PulseStrings

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.xs) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))

            Text(strings.text(.bluetoothNoDevicesTitle))
                .font(PulseDesign.Typography.panelBody)
                .foregroundStyle(.white.opacity(0.82))

            Text(strings.text(.bluetoothNoDevicesDetail))
                .font(PulseDesign.Typography.panelLabel)
                .foregroundStyle(.white.opacity(PulseDesign.Opacity.secondaryOnDark))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, PulseDesign.Spacing.lg)
    }
}

#Preview {
    BluetoothPanelView()
        .environment(
            PulseStore(
                launchAtLoginService: PulseLoginItemService(
                    currentStatus: { .notRegistered },
                    apply: { enabled in enabled ? .enabled : .notRegistered }
                ),
                reconcileLaunchAtLogin: false
            )
        )
}
