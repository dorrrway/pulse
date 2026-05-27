import AppKit
import Foundation

@MainActor
protocol ClipboardPasteboardClient: AnyObject {
    var changeCount: Int { get }
    var accessBehavior: ClipboardPasteboardAccessBehavior { get }

    func readSnapshot(capturedAt: Date, inferredSource: ClipboardApplicationSource?) throws -> ClipboardPasteboardSnapshot
    func write(entry: ClipboardHistoryEntry, blobData: [String: Data]) throws
}

nonisolated enum ClipboardPasteboardError: Error, Equatable {
    case readDenied(ClipboardPasteboardAccessBehavior)
    case writeFailed
}

@MainActor
final class AppKitClipboardPasteboardClient: ClipboardPasteboardClient {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    var accessBehavior: ClipboardPasteboardAccessBehavior {
        guard #available(macOS 15.4, *) else {
            return .systemDefault
        }

        switch pasteboard.accessBehavior {
        case .default:
            return .systemDefault
        case .ask:
            return .ask
        case .alwaysAllow:
            return .alwaysAllow
        case .alwaysDeny:
            return .alwaysDeny
        @unknown default:
            return .unknown
        }
    }

    func readSnapshot(
        capturedAt: Date,
        inferredSource: ClipboardApplicationSource?
    ) throws -> ClipboardPasteboardSnapshot {
        guard let pasteboardItems = pasteboard.pasteboardItems else {
            throw ClipboardPasteboardError.readDenied(accessBehavior)
        }

        let items = pasteboardItems.compactMap(Self.capturedItem(from:))
        return ClipboardPasteboardSnapshot(
            changeCount: pasteboard.changeCount,
            capturedAt: capturedAt,
            declaredSource: Self.declaredSource(from: pasteboardItems),
            inferredSource: inferredSource,
            items: items
        )
    }

    func write(entry: ClipboardHistoryEntry, blobData: [String: Data]) throws {
        let pasteboardItems = entry.items.compactMap { item -> NSPasteboardItem? in
            let pasteboardItem = NSPasteboardItem()
            var didSetRepresentation = false
            var didSetContentRepresentation = false

            for representation in item.representations {
                guard let data = blobData[representation.blobID] else {
                    continue
                }

                let type = NSPasteboard.PasteboardType(representation.type)
                if pasteboardItem.setData(data, forType: type) {
                    didSetRepresentation = true
                    if !ClipboardMarkerClassifier.isMarker(representation.type) {
                        didSetContentRepresentation = true
                    }
                }
            }

            for markerType in item.markerTypes {
                if pasteboardItem.setData(Data(), forType: NSPasteboard.PasteboardType(markerType)) {
                    didSetRepresentation = true
                }
            }

            if !didSetContentRepresentation {
                didSetContentRepresentation = Self.writeFallbackContent(
                    for: item,
                    to: pasteboardItem,
                    blobData: blobData
                )
            }

            return didSetRepresentation || didSetContentRepresentation ? pasteboardItem : nil
        }

        guard !pasteboardItems.isEmpty else {
            throw ClipboardPasteboardError.writeFailed
        }

        pasteboard.clearContents()
        guard pasteboard.writeObjects(pasteboardItems) else {
            throw ClipboardPasteboardError.writeFailed
        }
    }

    static func frontmostApplicationSource() -> ClipboardApplicationSource? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return ClipboardApplicationSource(
            name: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            bundlePath: application.bundleURL?.standardizedFileURL.path,
            rawValue: nil
        )
    }

    private static func capturedItem(from item: NSPasteboardItem) -> ClipboardCapturedItem? {
        let typeNames = item.types.map(\.rawValue)
        let markers = ClipboardMarkerClassifier.markers(in: typeNames)
        var representations: [ClipboardCapturedRepresentation] = []

        for type in item.types {
            let data = item.data(forType: type) ?? Data()
            representations.append(ClipboardCapturedRepresentation(type: type.rawValue, data: data))
        }

        guard !representations.isEmpty || !markers.isEmpty else {
            return nil
        }

        return ClipboardCapturedItem(
            markerTypes: markers,
            representations: representations
        )
    }

    private static func declaredSource(from items: [NSPasteboardItem]) -> ClipboardApplicationSource? {
        if let standardSource = standardDeclaredSource(from: items) {
            return standardSource
        }

        return appSpecificDeclaredSource(from: items)
    }

    private static func standardDeclaredSource(from items: [NSPasteboardItem]) -> ClipboardApplicationSource? {
        let sourceType = NSPasteboard.PasteboardType(ClipboardKnownMarker.source.rawValue)

        for item in items {
            guard
                let rawValue = item.string(forType: sourceType)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !rawValue.isEmpty
            else {
                continue
            }

            return source(fromDeclaredValue: rawValue)
        }

        return nil
    }

    private static func appSpecificDeclaredSource(from items: [NSPasteboardItem]) -> ClipboardApplicationSource? {
        for item in items {
            if let source = ClipboardAppSpecificSource.declaredSource(in: item.types.map(\.rawValue)) {
                return source
            }
        }

        return nil
    }

    private static func writeFallbackContent(
        for item: ClipboardHistoryItem,
        to pasteboardItem: NSPasteboardItem,
        blobData: [String: Data]
    ) -> Bool {
        switch item.kind {
        case .image:
            guard
                let imageBlobID = item.imageBlobID,
                let imageData = blobData[imageBlobID]
            else {
                return false
            }

            return pasteboardItem.setData(imageData, forType: .png)
        case .url:
            guard !item.displayText.isEmpty else {
                return false
            }

            let didSetURL = pasteboardItem.setString(item.displayText, forType: .URL)
            let didSetText = pasteboardItem.setString(item.displayText, forType: .string)
            return didSetURL || didSetText
        case .file:
            guard !item.displayText.isEmpty else {
                return false
            }

            let fileURLString = URL(fileURLWithPath: item.displayText).absoluteString
            return pasteboardItem.setString(fileURLString, forType: .fileURL)
        case .text, .mixed, .data:
            guard !item.displayText.isEmpty else {
                return false
            }

            return pasteboardItem.setString(item.displayText, forType: .string)
        }
    }

    private static func source(fromDeclaredValue rawValue: String) -> ClipboardApplicationSource {
        let runningApplication = NSWorkspace.shared.runningApplications.first { application in
            application.bundleIdentifier == rawValue || application.bundleURL?.path == rawValue
        }

        if let runningApplication {
            return ClipboardApplicationSource(
                name: runningApplication.localizedName,
                bundleIdentifier: runningApplication.bundleIdentifier,
                bundlePath: runningApplication.bundleURL?.standardizedFileURL.path,
                rawValue: rawValue
            )
        }

        if rawValue.hasSuffix(".app") || rawValue.hasPrefix("/") {
            let url = URL(fileURLWithPath: rawValue).standardizedFileURL
            let bundle = Bundle(url: url)
            return ClipboardApplicationSource(
                name: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent,
                bundleIdentifier: bundle?.bundleIdentifier,
                bundlePath: url.path,
                rawValue: rawValue
            )
        }

        return ClipboardApplicationSource(
            name: nil,
            bundleIdentifier: rawValue.contains(".") ? rawValue : nil,
            bundlePath: nil,
            rawValue: rawValue
        )
    }
}

struct ClipboardAppSpecificSource: Equatable {
    var typeSignatures: [String]
    var displayName: String
    var bundleIdentifiers: [String]

    static let knownSources: [Self] = [
        ClipboardAppSpecificSource(
            typeSignatures: [
                "wechat",
                "weixin",
            ],
            displayName: "WeChat",
            bundleIdentifiers: [
                "com.tencent.xinWeChat",
                "com.tencent.WeChat",
            ]
        ),
    ]

    static func matching(_ pasteboardType: String) -> Self? {
        let normalizedType = pasteboardType.lowercased()
        return knownSources.first { source in
            source.typeSignatures.contains { normalizedType.contains($0) }
        }
    }

    @MainActor
    static func declaredSource(in pasteboardTypes: some Sequence<String>) -> ClipboardApplicationSource? {
        for pasteboardType in pasteboardTypes {
            guard let source = matching(pasteboardType) else {
                continue
            }

            return source.resolvedApplicationSource(rawValue: pasteboardType)
        }

        return nil
    }

    @MainActor
    func resolvedApplicationSource(rawValue: String) -> ClipboardApplicationSource {
        if let runningApplication = runningApplication {
            return ClipboardApplicationSource(
                name: runningApplication.localizedName ?? displayName,
                bundleIdentifier: runningApplication.bundleIdentifier,
                bundlePath: runningApplication.bundleURL?.standardizedFileURL.path,
                rawValue: rawValue
            )
        }

        for bundleIdentifier in bundleIdentifiers {
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                continue
            }

            let bundle = Bundle(url: applicationURL)
            return ClipboardApplicationSource(
                name: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? displayName,
                bundleIdentifier: bundle?.bundleIdentifier ?? bundleIdentifier,
                bundlePath: applicationURL.standardizedFileURL.path,
                rawValue: rawValue
            )
        }

        return ClipboardApplicationSource(
            name: displayName,
            bundleIdentifier: bundleIdentifiers.first,
            bundlePath: nil,
            rawValue: rawValue
        )
    }

    @MainActor
    private var runningApplication: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            guard let bundleIdentifier = application.bundleIdentifier else {
                return false
            }

            return bundleIdentifiers.contains(bundleIdentifier)
        }
    }
}
