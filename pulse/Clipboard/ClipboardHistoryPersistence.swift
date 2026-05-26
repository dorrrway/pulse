import Foundation

@MainActor
final class ClipboardHistoryPersistence {
    struct StoredState: Codable {
        var version: Int
        var entries: [ClipboardHistoryEntry]
    }

    private let rootURL: URL
    private let metadataURL: URL
    private let blobsURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL = ClipboardHistoryPersistence.defaultRootURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.metadataURL = rootURL.appendingPathComponent("history.json", isDirectory: false)
        self.blobsURL = rootURL.appendingPathComponent("Blobs", isDirectory: true)
        self.fileManager = fileManager
    }

    static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return applicationSupport
            .appendingPathComponent("Pulse", isDirectory: true)
            .appendingPathComponent("ClipboardHistory", isDirectory: true)
    }

    func loadEntries() throws -> [ClipboardHistoryEntry] {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder.pulseClipboard.decode(StoredState.self, from: data).entries
    }

    func save(entries: [ClipboardHistoryEntry]) throws {
        try prepareDirectories()
        let state = StoredState(version: 1, entries: entries)
        let data = try JSONEncoder.pulseClipboard.encode(state)
        try data.write(to: metadataURL, options: .atomic)
        try removeOrphanedBlobs(keeping: Set(entries.flatMap(\.blobIDs)))
    }

    func storeBlobs(_ blobs: [String: Data]) throws {
        try prepareDirectories()
        for (id, data) in blobs {
            try data.write(to: blobURL(for: id), options: .atomic)
        }
    }

    func loadBlob(id: String) -> Data? {
        try? Data(contentsOf: blobURL(for: id))
    }

    func deleteBlobs(ids: some Sequence<String>) throws {
        for id in ids {
            let url = blobURL(for: id)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    func clear() throws {
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }

        if fileManager.fileExists(atPath: blobsURL.path) {
            try fileManager.removeItem(at: blobsURL)
        }

        try prepareDirectories()
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: blobsURL, withIntermediateDirectories: true)
    }

    private func blobURL(for id: String) -> URL {
        blobsURL.appendingPathComponent(id, isDirectory: false)
    }

    private func removeOrphanedBlobs(keeping keptBlobIDs: Set<String>) throws {
        guard
            fileManager.fileExists(atPath: blobsURL.path),
            let enumerator = fileManager.enumerator(at: blobsURL, includingPropertiesForKeys: nil)
        else {
            return
        }

        for case let url as URL in enumerator {
            guard !keptBlobIDs.contains(url.lastPathComponent) else {
                continue
            }

            try fileManager.removeItem(at: url)
        }
    }
}

private extension JSONEncoder {
    static var pulseClipboard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pulseClipboard: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
