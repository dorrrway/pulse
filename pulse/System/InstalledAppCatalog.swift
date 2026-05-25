import Foundation

nonisolated enum InstalledApplicationSource: Int, Sendable {
    case user
    case local
    case system
}

nonisolated struct InstalledApplication: Equatable, Identifiable, Sendable {
    var id: String { bundlePath }

    var name: String
    var bundleIdentifier: String?
    var version: String?
    var bundlePath: String
    var source: InstalledApplicationSource
}

actor InstalledAppCatalog {
    typealias DirectoryProvider = @Sendable () -> [URL]

    private let directoryProvider: DirectoryProvider

    init(directoryProvider: @escaping DirectoryProvider = InstalledAppCatalog.defaultApplicationDirectories) {
        self.directoryProvider = directoryProvider
    }

    func applications() -> [InstalledApplication] {
        Self.applications(in: directoryProvider())
    }

    nonisolated static func defaultApplicationDirectories() -> [URL] {
        let fileManager = FileManager.default
        let domains: [FileManager.SearchPathDomainMask] = [
            .systemDomainMask,
            .localDomainMask,
            .userDomainMask,
        ]

        return domains.flatMap { domain in
            fileManager.urls(for: .applicationDirectory, in: domain)
        }
    }

    nonisolated static func applications(
        in directories: [URL],
        fileManager: FileManager = .default
    ) -> [InstalledApplication] {
        var applicationsByPath: [String: InstalledApplication] = [:]

        for directory in directories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard
                    url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                    let application = application(at: url)
                else {
                    continue
                }

                applicationsByPath[application.bundlePath] = application
            }
        }

        return applicationsByPath.values.sorted(by: compareApplications)
    }

    nonisolated static func application(at appURL: URL) -> InstalledApplication? {
        let standardizedURL = appURL.standardizedFileURL
        guard let bundle = Bundle(url: standardizedURL) else {
            return nil
        }

        if
            let packageType = bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String,
            packageType != "APPL"
        {
            return nil
        }

        let name = stringValue(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName"))
            ?? stringValue(bundle.object(forInfoDictionaryKey: "CFBundleName"))
            ?? standardizedURL.deletingPathExtension().lastPathComponent
        let shortVersion = stringValue(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString"))
        let buildVersion = stringValue(bundle.object(forInfoDictionaryKey: "CFBundleVersion"))
        let version = shortVersion ?? buildVersion

        return InstalledApplication(
            name: name,
            bundleIdentifier: bundle.bundleIdentifier,
            version: version,
            bundlePath: standardizedURL.path,
            source: source(for: standardizedURL)
        )
    }

    private nonisolated static func compareApplications(
        _ lhs: InstalledApplication,
        _ rhs: InstalledApplication
    ) -> Bool {
        let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }

        if lhs.source != rhs.source {
            return lhs.source.rawValue < rhs.source.rawValue
        }

        return lhs.bundlePath.localizedStandardCompare(rhs.bundlePath) == .orderedAscending
    }

    private nonisolated static func source(for appURL: URL) -> InstalledApplicationSource {
        let path = appURL.path
        let homeApplicationsPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications")
            .standardizedFileURL
            .path

        if path.hasPrefix(homeApplicationsPath + "/") {
            return .user
        }

        if path.hasPrefix("/System/") {
            return .system
        }

        return .local
    }

    private nonisolated static func stringValue(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
