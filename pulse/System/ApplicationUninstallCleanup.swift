import Darwin
import Foundation

nonisolated enum ApplicationUninstallAvailability: Equatable, Sendable {
    case available
    case systemApplication
    case currentApplication
}

nonisolated enum ApplicationUninstallCandidateKind: Int, CaseIterable, Sendable {
    case applicationBundle
    case applicationSupport
    case container
    case groupContainer
    case preferences
    case caches
    case logs
    case launchAgent
    case savedState
    case webKit
    case httpStorage
}

nonisolated struct ApplicationUninstallCandidate: Equatable, Identifiable, Sendable {
    var id: String { url.standardizedFileURL.path }

    var url: URL
    var kind: ApplicationUninstallCandidateKind
    var sizeBytes: Int64?
    var isRequired: Bool
}

nonisolated struct ApplicationUninstallScan: Equatable, Sendable {
    var application: InstalledApplication
    var candidates: [ApplicationUninstallCandidate]

    var requiredCandidateIDs: Set<String> {
        Set(candidates.filter(\.isRequired).map(\.id))
    }
}

nonisolated struct ApplicationUninstallTrashResult: Identifiable, Sendable {
    var id: String { candidate.id }

    var candidate: ApplicationUninstallCandidate
    var trashedURL: URL?
    var errorDescription: String?
    var failureReason: ApplicationUninstallTrashFailureReason?

    var didMoveToTrash: Bool {
        failureReason == nil
    }
}

nonisolated enum ApplicationUninstallTrashFailureReason: Equatable, Sendable {
    case permissionDenied
    case unknown

    static func classify(_ error: Error) -> ApplicationUninstallTrashFailureReason {
        containsPermissionError(error as NSError) ? .permissionDenied : .unknown
    }

    private static func containsPermissionError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case CocoaError.Code.fileReadNoPermission.rawValue,
                CocoaError.Code.fileWriteNoPermission.rawValue:
                return true
            default:
                break
            }
        }

        if error.domain == NSPOSIXErrorDomain && (error.code == Int(EACCES) || error.code == Int(EPERM)) {
            return true
        }

        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return containsPermissionError(underlyingError)
        }

        let normalizedDescription = error.localizedDescription.lowercased()
        return normalizedDescription.contains("permission")
            || normalizedDescription.contains("not permitted")
    }
}

nonisolated enum ApplicationUninstallError: Equatable, LocalizedError {
    case unsupported(ApplicationUninstallAvailability)
    case missingApplicationBundle(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(.systemApplication):
            "System applications cannot be uninstalled by Pulse."
        case .unsupported(.currentApplication):
            "Pulse cannot uninstall itself while it is running."
        case .unsupported(.available):
            "This application cannot be uninstalled."
        case .missingApplicationBundle(let path):
            "The application bundle no longer exists at \(path)."
        }
    }
}

nonisolated enum ApplicationUninstallPolicy {
    static func availability(for application: InstalledApplication) -> ApplicationUninstallAvailability {
        if application.source == .system {
            return .systemApplication
        }

        if application.bundlePath == Bundle.main.bundleURL.standardizedFileURL.path {
            return .currentApplication
        }

        return .available
    }
}

actor ApplicationUninstallScanner {
    typealias LibraryProvider = @Sendable () -> URL?

    private let fileManager: FileManager
    private let libraryProvider: LibraryProvider

    init(
        fileManager: FileManager = .default,
        libraryProvider: @escaping LibraryProvider = ApplicationUninstallScanner.defaultLibraryURL
    ) {
        self.fileManager = fileManager
        self.libraryProvider = libraryProvider
    }

    func scan(application: InstalledApplication) throws -> ApplicationUninstallScan {
        try Self.scan(
            application: application,
            libraryURL: libraryProvider(),
            fileManager: fileManager
        )
    }

    nonisolated static func scan(
        application: InstalledApplication,
        libraryURL: URL?,
        fileManager: FileManager = .default
    ) throws -> ApplicationUninstallScan {
        let availability = ApplicationUninstallPolicy.availability(for: application)
        guard availability == .available else {
            throw ApplicationUninstallError.unsupported(availability)
        }

        let appURL = URL(fileURLWithPath: application.bundlePath).standardizedFileURL
        guard fileManager.fileExists(atPath: appURL.path) else {
            throw ApplicationUninstallError.missingApplicationBundle(application.bundlePath)
        }

        var candidates: [ApplicationUninstallCandidate] = [
            makeCandidate(
                url: appURL,
                kind: .applicationBundle,
                isRequired: true,
                fileManager: fileManager
            ),
        ]

        if let libraryURL {
            candidates.append(contentsOf: residualCandidates(
                for: application,
                libraryURL: libraryURL.standardizedFileURL,
                fileManager: fileManager
            ))
        }

        return ApplicationUninstallScan(
            application: application,
            candidates: uniqueCandidates(candidates)
        )
    }

    private nonisolated static func defaultLibraryURL() -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    }

    private nonisolated static func residualCandidates(
        for application: InstalledApplication,
        libraryURL: URL,
        fileManager: FileManager
    ) -> [ApplicationUninstallCandidate] {
        let identifiers = ApplicationUninstallIdentifiers(application: application)
        var candidates: [ApplicationUninstallCandidate] = []

        if let bundleIdentifier = identifiers.bundleIdentifier {
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent("Containers", isDirectory: true),
                components: [bundleIdentifier],
                kind: .container,
                fileManager: fileManager
            ))
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent("Preferences", isDirectory: true),
                components: ["\(bundleIdentifier).plist"],
                kind: .preferences,
                fileManager: fileManager
            ))
            candidates.append(contentsOf: matchingChildren(
                in: libraryURL
                    .appendingPathComponent("Preferences", isDirectory: true)
                    .appendingPathComponent("ByHost", isDirectory: true),
                kind: .preferences,
                fileManager: fileManager
            ) { childName in
                childName.hasPrefix("\(bundleIdentifier).") && childName.hasSuffix(".plist")
            })
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent("Saved Application State", isDirectory: true),
                components: ["\(bundleIdentifier).savedState"],
                kind: .savedState,
                fileManager: fileManager
            ))
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent("WebKit", isDirectory: true),
                components: [bundleIdentifier],
                kind: .webKit,
                fileManager: fileManager
            ))
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent("HTTPStorages", isDirectory: true),
                components: [bundleIdentifier, "\(bundleIdentifier).binarycookies"],
                kind: .httpStorage,
                fileManager: fileManager
            ))
            candidates.append(contentsOf: matchingChildren(
                in: libraryURL.appendingPathComponent("Group Containers", isDirectory: true),
                kind: .groupContainer,
                fileManager: fileManager
            ) { childName in
                childName.localizedCaseInsensitiveContains(bundleIdentifier)
            })
            candidates.append(contentsOf: matchingChildren(
                in: libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true),
                kind: .launchAgent,
                fileManager: fileManager
            ) { childName in
                (childName == "\(bundleIdentifier).plist"
                    || childName.hasPrefix("\(bundleIdentifier)."))
                    && childName.hasSuffix(".plist")
            })
        }

        let nameComponents = identifiers.safeNameComponents
        for (directoryName, kind) in [
            ("Application Support", ApplicationUninstallCandidateKind.applicationSupport),
            ("Caches", ApplicationUninstallCandidateKind.caches),
            ("Logs", ApplicationUninstallCandidateKind.logs),
        ] {
            candidates.append(contentsOf: exactCandidates(
                base: libraryURL.appendingPathComponent(directoryName, isDirectory: true),
                components: nameComponents,
                kind: kind,
                fileManager: fileManager
            ))
        }

        if let bundleIdentifier = identifiers.bundleIdentifier {
            for (directoryName, kind) in [
                ("Application Support", ApplicationUninstallCandidateKind.applicationSupport),
                ("Caches", ApplicationUninstallCandidateKind.caches),
                ("Logs", ApplicationUninstallCandidateKind.logs),
            ] {
                candidates.append(contentsOf: exactCandidates(
                    base: libraryURL.appendingPathComponent(directoryName, isDirectory: true),
                    components: [bundleIdentifier],
                    kind: kind,
                    fileManager: fileManager
                ))
            }
        }

        return candidates
    }

    private nonisolated static func exactCandidates(
        base: URL,
        components: [String],
        kind: ApplicationUninstallCandidateKind,
        fileManager: FileManager
    ) -> [ApplicationUninstallCandidate] {
        components.compactMap { component in
            let url = base.appendingPathComponent(component)
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }

            return makeCandidate(
                url: url,
                kind: kind,
                isRequired: false,
                fileManager: fileManager
            )
        }
    }

    private nonisolated static func matchingChildren(
        in directory: URL,
        kind: ApplicationUninstallCandidateKind,
        fileManager: FileManager,
        matches: (String) -> Bool
    ) -> [ApplicationUninstallCandidate] {
        guard
            let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return children
            .filter { matches($0.lastPathComponent) }
            .map {
                makeCandidate(
                    url: $0,
                    kind: kind,
                    isRequired: false,
                    fileManager: fileManager
                )
            }
    }

    private nonisolated static func makeCandidate(
        url: URL,
        kind: ApplicationUninstallCandidateKind,
        isRequired: Bool,
        fileManager: FileManager
    ) -> ApplicationUninstallCandidate {
        ApplicationUninstallCandidate(
            url: url.standardizedFileURL,
            kind: kind,
            sizeBytes: allocatedSize(of: url, fileManager: fileManager),
            isRequired: isRequired
        )
    }

    private nonisolated static func uniqueCandidates(
        _ candidates: [ApplicationUninstallCandidate]
    ) -> [ApplicationUninstallCandidate] {
        var seen: Set<String> = []
        return candidates
            .filter { candidate in
                let path = candidate.id
                guard !seen.contains(path) else {
                    return false
                }

                seen.insert(path)
                return true
            }
            .sorted { lhs, rhs in
                if lhs.isRequired != rhs.isRequired {
                    return lhs.isRequired
                }

                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }

                return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
            }
    }

    private nonisolated static func allocatedSize(
        of url: URL,
        fileManager: FileManager
    ) -> Int64? {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else {
            return nil
        }

        if values.isDirectory != true {
            return fileSize(from: values)
        }

        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { _, _ in true }
            )
        else {
            return nil
        }

        var total: Int64 = 0
        var visitedItemCount = 0

        for case let childURL as URL in enumerator {
            visitedItemCount += 1
            guard visitedItemCount <= 200_000 else {
                return nil
            }

            guard
                let childValues = try? childURL.resourceValues(forKeys: keys),
                childValues.isDirectory != true
            else {
                continue
            }

            total += fileSize(from: childValues) ?? 0
        }

        return total
    }

    private nonisolated static func fileSize(from values: URLResourceValues) -> Int64? {
        let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize
        guard let size else {
            return nil
        }

        return Int64(size)
    }
}

actor ApplicationUninstallTrashMover {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func moveToTrash(candidates: [ApplicationUninstallCandidate]) -> [ApplicationUninstallTrashResult] {
        candidates.map { candidate in
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(
                    at: candidate.url,
                    resultingItemURL: &resultingURL
                )

                return ApplicationUninstallTrashResult(
                    candidate: candidate,
                    trashedURL: resultingURL as URL?,
                    errorDescription: nil,
                    failureReason: nil
                )
            } catch {
                return ApplicationUninstallTrashResult(
                    candidate: candidate,
                    trashedURL: nil,
                    errorDescription: error.localizedDescription,
                    failureReason: ApplicationUninstallTrashFailureReason.classify(error)
                )
            }
        }
    }
}

private nonisolated struct ApplicationUninstallIdentifiers {
    var bundleIdentifier: String?
    var safeNameComponents: [String]

    init(application: InstalledApplication) {
        bundleIdentifier = application.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        let bundleStem = URL(fileURLWithPath: application.bundlePath)
            .deletingPathExtension()
            .lastPathComponent

        safeNameComponents = Self.uniqueSafeComponents([
            application.name,
            bundleStem,
        ])
    }

    private static func uniqueSafeComponents(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let component = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !component.isEmpty,
                !component.contains("/"),
                !seen.contains(component)
            else {
                return nil
            }

            seen.insert(component)
            return component
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
