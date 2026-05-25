import AppKit
import SwiftUI

struct InstalledAppsPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var hoveredApplicationID: InstalledApplication.ID?

    var body: some View {
        let strings = store.strings

        VStack(alignment: .leading, spacing: 0) {
            appContent(strings: strings)
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
            store.refreshInstalledApplicationsIfNeeded()
        }
    }

    @ViewBuilder
    private func appContent(strings: PulseStrings) -> some View {
        if store.installedApplications.isEmpty && !store.isRefreshingInstalledApplications {
            Text(strings.text(.noApplicationsFound))
                .font(PulseDesign.Typography.panelBody)
                .foregroundStyle(.white.opacity(PulseDesign.Opacity.secondaryOnDark))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            switch store.installedAppsDisplayMode {
            case .list:
                appList(strings: strings)
            case .icon:
                appIconGrid(strings: strings)
            }
        }
    }

    private func appList(strings: PulseStrings) -> some View {
        ScrollView {
            LazyVStack(spacing: PulseDesign.Spacing.xxs) {
                ForEach(store.installedApplications) { application in
                    InstalledAppRow(
                        application: application,
                        strings: strings,
                        isHovering: hoveredApplicationID == application.id
                    )
                    .onHover { isHovering in
                        hoveredApplicationID = isHovering ? application.id : nil
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
    }

    private func appIconGrid(strings: PulseStrings) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 64, maximum: 76), spacing: 8, alignment: .top),
        ]

        return ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: PulseDesign.Spacing.compact) {
                ForEach(store.installedApplications) { application in
                    InstalledAppIconTile(
                        application: application,
                        strings: strings,
                        isHovering: hoveredApplicationID == application.id
                    )
                    .onHover { isHovering in
                        hoveredApplicationID = isHovering ? application.id : nil
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
    }

    private func footer(strings: PulseStrings) -> some View {
        HStack(spacing: 8) {
            InstalledAppsDisplayModeControl(displayMode: store.installedAppsDisplayMode, strings: strings) { mode in
                store.setInstalledAppsDisplayMode(mode)
            }

            Spacer(minLength: 0)

            Text(strings.applicationCount(store.installedApplications.count))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)

            if store.isRefreshingInstalledApplications {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            } else {
                InstalledAppsIconButton(
                    systemName: "arrow.clockwise",
                    help: strings.text(.refreshApplications)
                ) {
                    store.refreshInstalledApplicationsIfNeeded(force: true)
                }
            }
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }
}

nonisolated enum PulseInstalledAppsDisplayMode: String, CaseIterable, Sendable {
    case list
    case icon

    var systemName: String {
        switch self {
        case .list:
            "list.bullet"
        case .icon:
            "square.grid.3x3.fill"
        }
    }

    func accessibilityLabel(strings: PulseStrings) -> String {
        switch self {
        case .list:
            strings.text(.applicationsListView)
        case .icon:
            strings.text(.applicationsIconView)
        }
    }
}

private struct InstalledAppsDisplayModeControl: View {
    var displayMode: PulseInstalledAppsDisplayMode
    var strings: PulseStrings
    var selectMode: (PulseInstalledAppsDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PulseInstalledAppsDisplayMode.allCases, id: \.self) { mode in
                InstalledAppsDisplayModeButton(
                    mode: mode,
                    strings: strings,
                    isSelected: displayMode == mode
                ) {
                    selectMode(mode)
                }
            }
        }
        .padding(PulseDesign.Spacing.micro)
        .background {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.segmentedControl, style: .continuous)
                .fill(.white.opacity(PulseDesign.Opacity.hoverFillOnDark))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct InstalledAppsDisplayModeButton: View {
    var mode: PulseInstalledAppsDisplayMode
    var strings: PulseStrings
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let label = mode.accessibilityLabel(strings: strings)

        Button(action: action) {
            ZStack {
                if isSelected || isHovering {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(isSelected ? PulseDesign.Opacity.selectedFillOnDark : PulseDesign.Opacity.hoverFillOnDark))
                }

                Image(systemName: mode.systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.94 : 0.62))
                    .frame(width: PulseDesign.Control.iconSide, height: PulseDesign.Control.iconSide)
                    .accessibilityHidden(true)
            }
            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Spacing.lg)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct InstalledAppRow: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var isHovering: Bool

    var body: some View {
        Button {
            InstalledApplicationLauncher.open(application)
        } label: {
            HStack(spacing: 10) {
                InstalledApplicationIcon(bundlePath: application.bundlePath)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.name)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(detailText)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(isHovering ? 0.82 : 0.36))
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 9)
            .frame(height: 42)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(strings.openApplicationHelp(application.name))
        .accessibilityLabel(application.name)
        .accessibilityValue(detailText)
    }

    private var detailText: String {
        [
            application.bundleIdentifier,
            application.version.map { "v\($0)" },
            strings.installedApplicationSource(application.source),
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}

private struct InstalledAppIconTile: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var isHovering: Bool

    var body: some View {
        Button {
            InstalledApplicationLauncher.open(application)
        } label: {
            VStack(spacing: 6) {
                InstalledApplicationIcon(bundlePath: application.bundlePath, size: 42, cornerRadius: 10)

                Text(application.name)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(height: 26, alignment: .top)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .top)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(strings.openApplicationHelp(application.name))
        .accessibilityLabel(application.name)
        .accessibilityValue(strings.installedApplicationSource(application.source))
    }
}

private struct InstalledApplicationIcon: View {
    var bundlePath: String
    var size: CGFloat = 26
    var cornerRadius: CGFloat = 6

    var body: some View {
        if let icon = InstalledApplicationIconCache.shared.icon(forBundlePath: bundlePath) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.16))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

private struct InstalledAppsIconButton: View {
    var systemName: String
    var help: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.10))
                }

                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            .frame(width: 28, height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

@MainActor
private final class InstalledApplicationIconCache {
    static let shared = InstalledApplicationIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 192
    }

    func icon(forBundlePath bundlePath: String) -> NSImage? {
        let key = bundlePath as NSString
        if let icon = cache.object(forKey: key) {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: bundlePath)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

@MainActor
private enum InstalledApplicationLauncher {
    static func open(_ application: InstalledApplication) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: application.bundlePath),
            configuration: configuration
        )
    }
}
