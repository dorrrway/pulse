import AppKit
import SwiftUI

struct ApplicationUninstallConfirmationView: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var closeAction: (() -> Void)?
    var onCompleted: (InstalledApplication) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scan: ApplicationUninstallScan?
    @State private var selectedCandidateIDs: Set<String> = []
    @State private var trashResults: [ApplicationUninstallTrashResult] = []
    @State private var errorMessage: String?
    @State private var isScanning = true
    @State private var isMovingToTrash = false

    private let scanner = ApplicationUninstallScanner()
    private let trashMover = ApplicationUninstallTrashMover()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            content
                .frame(minHeight: 260, maxHeight: 360)

            Divider()

            footer
        }
        .padding(20)
        .frame(width: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: application.id) {
            await loadScan()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ApplicationUninstallIcon(bundlePath: application.bundlePath)

            VStack(alignment: .leading, spacing: 4) {
                Text(strings.applicationUninstallTitle(application.name))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(application.bundlePath)
                    .font(.system(.caption, design: .monospaced, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isScanning {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                Text(strings.text(.applicationUninstallScanning))
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label(strings.text(.applicationUninstallCannotScan), systemImage: "exclamationmark.triangle")
                    .font(.system(.callout, design: .rounded, weight: .semibold))

                Text(errorMessage)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if !trashResults.isEmpty {
            uninstallResults
        } else if let scan {
            candidateList(scan)
        }
    }

    private func candidateList(_ scan: ApplicationUninstallScan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(strings.text(.applicationUninstallSelectionDetail))
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(scan.candidates) { candidate in
                        ApplicationUninstallCandidateRow(
                            candidate: candidate,
                            strings: strings,
                            isSelected: selectionBinding(for: candidate),
                            isDisabled: isMovingToTrash
                        )

                        if candidate.id != scan.candidates.last?.id {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var uninstallResults: some View {
        let failureCount = trashResults.filter { !$0.didMoveToTrash }.count
        let successCount = trashResults.count - failureCount
        let hasPermissionFailure = trashResults.contains { $0.failureReason == .permissionDenied }

        return VStack(alignment: .leading, spacing: 10) {
            Label(
                strings.applicationUninstallResultSummary(successCount: successCount, failureCount: failureCount),
                systemImage: failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(failureCount == 0 ? .green : .orange)

            if hasPermissionFailure {
                ApplicationUninstallPermissionRecoveryNotice(
                    applicationName: application.name,
                    strings: strings,
                    openAppManagement: {
                        openPrivacySettings(.appManagement)
                    },
                    openFullDiskAccess: {
                        openPrivacySettings(.fullDiskAccess)
                    }
                )
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(trashResults) { result in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: result.didMoveToTrash ? "checkmark.circle" : "xmark.circle")
                                    .foregroundStyle(result.didMoveToTrash ? .green : .red)
                                    .accessibilityHidden(true)

                                Text(strings.applicationUninstallCandidateKind(result.candidate.kind))
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                            }

                            Text(result.candidate.url.path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)

                            if let failureReason = result.failureReason {
                                Text(strings.applicationUninstallTrashFailureDescription(
                                    failureReason,
                                    fallback: result.errorDescription
                                ))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.red)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var footer: some View {
        let hasFailedResults = trashResults.contains { !$0.didMoveToTrash }

        return HStack(spacing: 10) {
            if let scan, trashResults.isEmpty {
                Text(strings.applicationUninstallSelectedSummary(
                    count: selectedCandidates(from: scan).count,
                    sizeBytes: selectedSizeBytes(from: scan)
                ))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(strings.text(.applicationUninstallCancel)) {
                close()
            }
            .disabled(isMovingToTrash)

            if trashResults.isEmpty {
                Button(role: .destructive) {
                    Task {
                        await moveSelectedItemsToTrash()
                    }
                } label: {
                    if isMovingToTrash {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(strings.text(.applicationUninstallMoveToTrash))
                    }
                }
                .disabled(isScanning || isMovingToTrash || selectedCandidateIDs.isEmpty || scan == nil || errorMessage != nil)
                .keyboardShortcut(.defaultAction)
            } else {
                if hasFailedResults {
                    Button {
                        Task {
                            await retryFailedItemsToTrash()
                        }
                    } label: {
                        if isMovingToTrash {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(strings.text(.applicationUninstallRetryFailedItems))
                        }
                    }
                    .disabled(isMovingToTrash)
                }

                Button(strings.text(.applicationUninstallDone)) {
                    close()
                }
                .disabled(isMovingToTrash)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func selectionBinding(for candidate: ApplicationUninstallCandidate) -> Binding<Bool> {
        Binding {
            candidate.isRequired || selectedCandidateIDs.contains(candidate.id)
        } set: { isSelected in
            guard !candidate.isRequired else {
                selectedCandidateIDs.insert(candidate.id)
                return
            }

            if isSelected {
                selectedCandidateIDs.insert(candidate.id)
            } else {
                selectedCandidateIDs.remove(candidate.id)
            }
        }
    }

    private func loadScan() async {
        isScanning = true
        errorMessage = nil
        scan = nil
        trashResults = []

        do {
            let loadedScan = try await scanner.scan(application: application)
            scan = loadedScan
            selectedCandidateIDs = Set(loadedScan.candidates.map(\.id))
        } catch {
            selectedCandidateIDs = []
            errorMessage = strings.applicationUninstallErrorDescription(error)
        }

        isScanning = false
    }

    private func moveSelectedItemsToTrash() async {
        guard let scan else {
            return
        }

        let selectedCandidates = selectedCandidates(from: scan)
        guard !selectedCandidates.isEmpty else {
            return
        }

        isMovingToTrash = true
        let results = await trashMover.moveToTrash(candidates: selectedCandidates)
        trashResults = results
        isMovingToTrash = false
        onCompleted(application)
    }

    private func retryFailedItemsToTrash() async {
        let failedCandidates = trashResults
            .filter { !$0.didMoveToTrash }
            .map(\.candidate)
        guard !failedCandidates.isEmpty else {
            return
        }

        isMovingToTrash = true
        let retryResults = await trashMover.moveToTrash(candidates: failedCandidates)
        let retryResultsByID = Dictionary(uniqueKeysWithValues: retryResults.map { ($0.id, $0) })
        trashResults = trashResults.map { result in
            guard !result.didMoveToTrash else {
                return result
            }

            return retryResultsByID[result.id] ?? result
        }
        isMovingToTrash = false
        onCompleted(application)
    }

    private func openPrivacySettings(_ pane: ApplicationUninstallPrivacySettingsPane) {
        NSWorkspace.shared.open(pane.url)
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    private func selectedCandidates(from scan: ApplicationUninstallScan) -> [ApplicationUninstallCandidate] {
        scan.candidates.filter { candidate in
            candidate.isRequired || selectedCandidateIDs.contains(candidate.id)
        }
    }

    private func selectedSizeBytes(from scan: ApplicationUninstallScan) -> Int64? {
        let sizes = selectedCandidates(from: scan).map(\.sizeBytes)
        guard sizes.allSatisfy({ $0 != nil }) else {
            return nil
        }

        return sizes.compactMap(\.self).reduce(0, +)
    }
}

private struct ApplicationUninstallPermissionRecoveryNotice: View {
    var applicationName: String
    var strings: PulseStrings
    var openAppManagement: () -> Void
    var openFullDiskAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(strings.applicationUninstallPermissionRecoveryTitle(), systemImage: "lock.shield.fill")
                .font(.system(.caption, design: .rounded, weight: .semibold))

            Text(strings.applicationUninstallPermissionRecoveryDetail(applicationName))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(strings.text(.applicationUninstallOpenAppManagement), action: openAppManagement)
                Button(strings.text(.applicationUninstallOpenFullDiskAccess), action: openFullDiskAccess)
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum ApplicationUninstallPrivacySettingsPane {
    case appManagement
    case fullDiskAccess

    var url: URL {
        switch self {
        case .appManagement:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles")!
        case .fullDiskAccess:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!
        }
    }
}

private struct ApplicationUninstallCandidateRow: View {
    var candidate: ApplicationUninstallCandidate
    var strings: PulseStrings
    @Binding var isSelected: Bool
    var isDisabled: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(strings.applicationUninstallCandidateKind(candidate.kind))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)

                        if candidate.isRequired {
                            Text(strings.text(.applicationUninstallRequired))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(candidate.url.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                if let sizeBytes = candidate.sizeBytes {
                    Text(ResourceFormatters.storageByteString(bytes: sizeBytes))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(strings.text(.applicationUninstallSizeUnavailable))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .toggleStyle(.checkbox)
        .disabled(candidate.isRequired || isDisabled)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

private struct ApplicationUninstallIcon: View {
    var bundlePath: String

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: bundlePath))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
