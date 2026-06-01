import Foundation

@MainActor
final class MemoPersistence {
    struct StoredState: Codable {
        var version: Int
        var entries: [MemoEntry]
    }

    private let rootURL: URL
    private let metadataURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL = MemoPersistence.defaultRootURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.metadataURL = rootURL.appendingPathComponent("memos.json", isDirectory: false)
        self.fileManager = fileManager
    }

    static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return applicationSupport
            .appendingPathComponent("Pulse", isDirectory: true)
            .appendingPathComponent("Memos", isDirectory: true)
    }

    func loadEntries() throws -> [MemoEntry] {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder.pulseMemo.decode(StoredState.self, from: data).entries
    }

    func save(entries: [MemoEntry]) throws {
        try prepareDirectory()
        let state = StoredState(version: 1, entries: entries)
        let data = try JSONEncoder.pulseMemo.encode(state)
        try data.write(to: metadataURL, options: .atomic)
    }

    func clear() throws {
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }

        try prepareDirectory()
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}

private extension JSONEncoder {
    static var pulseMemo: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pulseMemo: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
