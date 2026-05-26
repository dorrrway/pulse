import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardHistoryStore {
    var entries: [ClipboardHistoryEntry] = []
    var searchText = ""
    var selectedContentFilter: ClipboardContentFilter = .all
    var accessBehavior: ClipboardPasteboardAccessBehavior = .systemDefault
    var accessIssue: ClipboardHistoryAccessIssue?
    var lastCopiedEntryID: UUID?
    var latestRecordNotice: ClipboardHistoryRecordNotice?
    var ocrEnabled: Bool {
        didSet {
            userDefaults.set(ocrEnabled, forKey: Self.ocrEnabledKey)
            if ocrEnabled {
                enqueueOCRForVisibleImages()
            }
        }
    }
    var retentionLimit: Int {
        didSet {
            userDefaults.set(retentionLimit, forKey: Self.retentionLimitKey)
            trimHistoryAndPersist()
        }
    }
    var retentionDays: Int {
        didSet {
            userDefaults.set(retentionDays, forKey: Self.retentionDaysKey)
            trimHistoryAndPersist()
        }
    }

    @ObservationIgnored private let client: ClipboardPasteboardClient
    @ObservationIgnored private let controller: ClipboardHistoryController
    @ObservationIgnored private let persistence: ClipboardHistoryPersistence
    @ObservationIgnored private let ocrService: ClipboardOCRService
    @ObservationIgnored private let pasteCommandPoster: ClipboardFocusedPasteCommandPosting
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var ignoredPasteboardChangeCounts: Set<Int> = []

    nonisolated static let unlimitedRetentionLimit = 0
    nonisolated static let unlimitedRetentionDays = 0
    nonisolated static let retentionLimitOptions = [unlimitedRetentionLimit, 100, 500, 1_000]
    nonisolated static let retentionDayOptions = [unlimitedRetentionDays, 7, 30, 90]

    private static let ocrEnabledKey = "pulse.settings.clipboard.ocrEnabled"
    private static let retentionLimitKey = "pulse.settings.clipboard.retentionLimit"
    private static let retentionDaysKey = "pulse.settings.clipboard.retentionDays"
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    private static let classifiableLinkSchemes: Set<String> = ["http", "https", "mailto"]

    init(
        userDefaults: UserDefaults = .standard,
        client: ClipboardPasteboardClient = AppKitClipboardPasteboardClient(),
        persistence: ClipboardHistoryPersistence = ClipboardHistoryPersistence(),
        ocrService: ClipboardOCRService = ClipboardOCRService(),
        pasteCommandPoster: ClipboardFocusedPasteCommandPosting = AppKitClipboardFocusedPasteCommandPoster()
    ) {
        self.userDefaults = userDefaults
        self.client = client
        self.controller = ClipboardHistoryController(client: client)
        self.persistence = persistence
        self.ocrService = ocrService
        self.pasteCommandPoster = pasteCommandPoster
        self.ocrEnabled = userDefaults.object(forKey: Self.ocrEnabledKey) as? Bool ?? false
        self.retentionLimit = Self.loadRetentionLimit(from: userDefaults)
        self.retentionDays = Self.loadRetentionDays(from: userDefaults)
        self.entries = Self.restoringStoredEntries(in: (try? persistence.loadEntries()) ?? [])
        trimHistoryAndPersist()
    }

    var filteredEntries: [ClipboardHistoryEntry] {
        entries.filter {
            $0.matches(contentFilter: selectedContentFilter)
                && $0.matches(searchText: searchText)
        }
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    func startMonitoring() {
        controller.start { [weak self] behavior in
            self?.accessBehavior = behavior
        } captured: { [weak self] snapshot in
            self?.record(snapshot)
        } failed: { [weak self] issue in
            self?.accessIssue = issue
        }
    }

    func stopMonitoring() {
        controller.stop()
    }

    func clearHistory() {
        entries = []
        searchText = ""
        selectedContentFilter = .all
        accessIssue = nil
        lastCopiedEntryID = nil
        latestRecordNotice = nil
        ignoredPasteboardChangeCounts = []
        try? persistence.clear()
    }

    func delete(_ entry: ClipboardHistoryEntry) {
        let blobIDs = entry.blobIDs
        entries.removeAll { $0.id == entry.id }
        if entries.isEmpty {
            searchText = ""
            selectedContentFilter = .all
        }
        try? persistence.deleteBlobs(ids: blobIDs)
        persistEntries()
    }

    @discardableResult
    func copy(_ entry: ClipboardHistoryEntry) -> Bool {
        var blobData: [String: Data] = [:]
        for blobID in entry.blobIDs {
            if let data = persistence.loadBlob(id: blobID) {
                blobData[blobID] = data
            }
        }

        do {
            try client.write(entry: entry, blobData: blobData)
            ignoredPasteboardChangeCounts.insert(client.changeCount)
            lastCopiedEntryID = entry.id
            return true
        } catch {
            accessIssue = .readFailed(error.localizedDescription)
            return false
        }
    }

    func pasteIntoFocusedTarget(_ entry: ClipboardHistoryEntry) {
        guard copy(entry) else {
            return
        }

        switch pasteCommandPoster.postPasteCommand() {
        case .posted:
            clearPasteCommandIssue()
        case .accessibilityPermissionRequired:
            accessIssue = .pasteCommandDenied
        }
    }

    func imageData(for blobID: String) -> Data? {
        persistence.loadBlob(id: blobID)
    }

    func markerLabels(for entry: ClipboardHistoryEntry, strings: PulseStrings) -> [String] {
        let labels: [String] = entry.markerTypes.compactMap { markerType -> String? in
            guard isRemoteClipboardMarker(markerType) else {
                return nil
            }

            return strings.text(.clipboardMarkerRemote)
        }

        return Array(Set(labels)).sorted()
    }

    func record(_ snapshot: ClipboardPasteboardSnapshot) {
        guard !snapshot.items.isEmpty else {
            return
        }

        if ignoredPasteboardChangeCounts.remove(snapshot.changeCount) != nil {
            accessIssue = nil
            return
        }

        ignoredPasteboardChangeCounts = Set(ignoredPasteboardChangeCounts.filter { $0 > snapshot.changeCount })

        let result = Self.buildHistoryEntry(from: snapshot)

        if let duplicateIndex = entries.firstIndex(where: { $0.fingerprint == result.entry.fingerprint }) {
            do {
                try persistence.storeBlobs(result.blobs)
            } catch {
                accessIssue = .readFailed(error.localizedDescription)
                return
            }

            accessIssue = nil
            let existingEntry = entries.remove(at: duplicateIndex)
            let refreshedEntry = Self.refreshedDuplicateEntry(existingEntry, using: result.entry)
            entries.insert(refreshedEntry, at: 0)
            trimHistoryAndPersist()

            if ocrEnabled {
                enqueueOCR(for: refreshedEntry.id)
            }

            publishRecordNotice(for: refreshedEntry)
            return
        }

        do {
            try persistence.storeBlobs(result.blobs)
        } catch {
            accessIssue = .readFailed(error.localizedDescription)
            return
        }

        accessIssue = nil
        entries.insert(result.entry, at: 0)
        trimHistoryAndPersist()

        if ocrEnabled {
            enqueueOCR(for: result.entry.id)
        }

        publishRecordNotice(for: result.entry)
    }

    private func publishRecordNotice(for entry: ClipboardHistoryEntry) {
        latestRecordNotice = ClipboardHistoryRecordNotice(entry: entry)
    }

    private func trimHistoryAndPersist() {
        let originalEntries = entries
        let retainedByDate: [ClipboardHistoryEntry]
        if retentionDays == Self.unlimitedRetentionDays {
            retainedByDate = entries
        } else {
            let cutoff = Date().addingTimeInterval(-TimeInterval(retentionDays) * 24 * 60 * 60)
            retainedByDate = entries.filter { $0.createdAt >= cutoff }
        }

        if retentionLimit == Self.unlimitedRetentionLimit {
            entries = retainedByDate
        } else {
            entries = Array(retainedByDate.prefix(max(retentionLimit, 1)))
        }

        if entries.isEmpty {
            searchText = ""
            selectedContentFilter = .all
        }

        let keptIDs = Set(entries.map(\.id))
        let removedBlobIDs = originalEntries
            .filter { !keptIDs.contains($0.id) }
            .flatMap(\.blobIDs)

        if !removedBlobIDs.isEmpty {
            try? persistence.deleteBlobs(ids: removedBlobIDs)
        }

        persistEntries()
    }

    private func persistEntries() {
        do {
            try persistence.save(entries: entries)
        } catch {
            accessIssue = .readFailed(error.localizedDescription)
        }
    }

    private func enqueueOCRForVisibleImages() {
        for entry in entries where entry.items.contains(where: { $0.imageBlobID != nil && $0.searchableText.isEmpty }) {
            enqueueOCR(for: entry.id)
        }
    }

    private func enqueueOCR(for entryID: UUID) {
        Task { @MainActor [weak self] in
            guard let self, let entryIndex = entries.firstIndex(where: { $0.id == entryID }) else {
                return
            }

            var updatedEntry = entries[entryIndex]
            var didUpdate = false

            for itemIndex in updatedEntry.items.indices {
                guard
                    let imageBlobID = updatedEntry.items[itemIndex].imageBlobID,
                    let imageData = persistence.loadBlob(id: imageBlobID)
                else {
                    continue
                }

                let recognizedText = await ocrService.recognizedText(in: imageData)
                guard !recognizedText.isEmpty else {
                    continue
                }

                updatedEntry.items[itemIndex].searchableText = [
                    updatedEntry.items[itemIndex].searchableText,
                    recognizedText,
                ]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                didUpdate = true
            }

            guard didUpdate, let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else {
                return
            }

            updatedEntry.searchableText = Self.entrySearchableText(
                items: updatedEntry.items,
                markerTypes: updatedEntry.markerTypes,
                declaredSource: updatedEntry.declaredSource,
                inferredSource: updatedEntry.inferredSource
            )
            entries[currentIndex] = updatedEntry
            persistEntries()
        }
    }

    private static func refreshedDuplicateEntry(
        _ entry: ClipboardHistoryEntry,
        using latestEntry: ClipboardHistoryEntry
    ) -> ClipboardHistoryEntry {
        var refreshedEntry = latestEntry
        refreshedEntry.id = entry.id
        refreshedEntry.declaredSource = latestEntry.declaredSource ?? entry.declaredSource
        refreshedEntry.inferredSource = effectiveInferredSource(
            inferredSource: latestEntry.inferredSource ?? entry.inferredSource,
            markerTypes: refreshedEntry.markerTypes
        )
        refreshedEntry.searchableText = entrySearchableText(
            items: refreshedEntry.items,
            markerTypes: refreshedEntry.markerTypes,
            declaredSource: refreshedEntry.declaredSource,
            inferredSource: refreshedEntry.inferredSource
        )
        return refreshedEntry
    }

    private static func restoringStoredEntries(
        in entries: [ClipboardHistoryEntry]
    ) -> [ClipboardHistoryEntry] {
        entries.map { entry in
            repairingStoredPlainTextURLFileEntry(
                repairingStoredRemoteImageFileEntry(
                    restoringStoredDeclaredSource(in: entry)
                )
            )
        }
    }

    private static func restoringStoredDeclaredSource(
        in entry: ClipboardHistoryEntry
    ) -> ClipboardHistoryEntry {
        guard entry.declaredSource == nil else {
            return entry
        }

        let pasteboardTypes = entry.items.flatMap { item in
            item.markerTypes + item.representations.map(\.type)
        }
        guard let declaredSource = ClipboardAppSpecificSource.declaredSource(in: pasteboardTypes) else {
            return entry
        }

        var restoredEntry = entry
        restoredEntry.declaredSource = declaredSource
        restoredEntry.searchableText = entrySearchableText(
            items: restoredEntry.items,
            markerTypes: restoredEntry.markerTypes,
            declaredSource: restoredEntry.declaredSource,
            inferredSource: restoredEntry.inferredSource
        )
        return restoredEntry
    }

    private static func repairingStoredRemoteImageFileEntry(
        _ entry: ClipboardHistoryEntry
    ) -> ClipboardHistoryEntry {
        var repairedEntry = entry
        var didRepair = false

        for index in repairedEntry.items.indices {
            guard
                repairedEntry.items[index].kind == .file,
                (repairedEntry.markerTypes + repairedEntry.items[index].markerTypes)
                    .contains(where: ClipboardMarkerClassifier.isRemoteClipboard)
            else {
                continue
            }

            let paths = fileDisplayPaths(from: repairedEntry.items[index].displayText)
            guard
                !paths.isEmpty,
                paths.allSatisfy(ClipboardPasteboardTypeClassifier.isImageFilePath)
            else {
                continue
            }

            let originalDisplayText = repairedEntry.items[index].displayText
            repairedEntry.items[index].kind = .image
            repairedEntry.items[index].displayText = fallbackDisplayText(for: .image)
            repairedEntry.items[index].searchableText = searchText(
                primary: originalDisplayText,
                fallback: repairedEntry.items[index].searchableText
            )
            didRepair = true
        }

        guard didRepair else {
            return repairedEntry
        }

        repairedEntry.kind = entryKind(for: repairedEntry.items)
        repairedEntry.displayText = repairedEntry.items.first(where: { !$0.displayText.isEmpty })?.displayText
            ?? fallbackDisplayText(for: repairedEntry.kind)
        repairedEntry.searchableText = entrySearchableText(
            items: repairedEntry.items,
            markerTypes: repairedEntry.markerTypes,
            declaredSource: repairedEntry.declaredSource,
            inferredSource: repairedEntry.inferredSource
        )
        return repairedEntry
    }

    private static func repairingStoredPlainTextURLFileEntry(
        _ entry: ClipboardHistoryEntry
    ) -> ClipboardHistoryEntry {
        var repairedEntry = entry
        var didRepair = false

        for index in repairedEntry.items.indices {
            guard
                repairedEntry.items[index].kind == .text,
                storedItemHasPlainTextContent(repairedEntry.items[index])
            else {
                continue
            }

            if let value = standaloneClassifiableLinkValue(repairedEntry.items[index].displayText) {
                repairedEntry.items[index].kind = .url
                repairedEntry.items[index].displayText = value
                repairedEntry.items[index].searchableText = searchText(
                    primary: value,
                    fallback: repairedEntry.items[index].searchableText
                )
                didRepair = true
                continue
            }

            if let value = standaloneDetectedFileURLValue(repairedEntry.items[index].displayText) {
                let display = fileDisplayText(from: value)
                repairedEntry.items[index].kind = .file
                repairedEntry.items[index].displayText = display
                repairedEntry.items[index].searchableText = searchText(
                    primary: display,
                    fallback: repairedEntry.items[index].searchableText
                )
                didRepair = true
            }
        }

        guard didRepair else {
            return repairedEntry
        }

        repairedEntry.kind = entryKind(for: repairedEntry.items)
        repairedEntry.displayText = repairedEntry.items.first(where: { !$0.displayText.isEmpty })?.displayText
            ?? fallbackDisplayText(for: repairedEntry.kind)
        repairedEntry.searchableText = entrySearchableText(
            items: repairedEntry.items,
            markerTypes: repairedEntry.markerTypes,
            declaredSource: repairedEntry.declaredSource,
            inferredSource: repairedEntry.inferredSource
        )
        return repairedEntry
    }

    private static func buildHistoryEntry(from snapshot: ClipboardPasteboardSnapshot) -> ClipboardHistoryBuildResult {
        var blobs: [String: Data] = [:]
        var historyItems: [ClipboardHistoryItem] = []
        var allMarkers: Set<String> = []

        for capturedItem in snapshot.items {
            let itemResult = buildHistoryItem(from: capturedItem, blobs: &blobs)
            historyItems.append(itemResult)
            allMarkers.formUnion(itemResult.markerTypes)
        }

        let kind = entryKind(for: historyItems)
        let displayText = historyItems.first(where: { !$0.displayText.isEmpty })?.displayText
            ?? fallbackDisplayText(for: kind)
        let markerTypes = Array(allMarkers).sorted()
        let inferredSource = effectiveInferredSource(
            inferredSource: snapshot.inferredSource,
            markerTypes: markerTypes
        )
        let searchableText = entrySearchableText(
            items: historyItems,
            markerTypes: markerTypes,
            declaredSource: snapshot.declaredSource,
            inferredSource: inferredSource
        )
        let fingerprint = fingerprint(for: snapshot.items)

        return ClipboardHistoryBuildResult(
            entry: ClipboardHistoryEntry(
                id: UUID(),
                changeCount: snapshot.changeCount,
                createdAt: snapshot.capturedAt,
                kind: kind,
                displayText: displayText,
                searchableText: searchableText,
                markerTypes: markerTypes,
                declaredSource: snapshot.declaredSource,
                inferredSource: inferredSource,
                items: historyItems,
                fingerprint: fingerprint
            ),
            blobs: blobs
        )
    }

    private static func buildHistoryItem(
        from item: ClipboardCapturedItem,
        blobs: inout [String: Data]
    ) -> ClipboardHistoryItem {
        var storedRepresentations: [ClipboardStoredRepresentation] = []
        var imageBlobID: String?
        var imagePixelWidth: Double?
        var imagePixelHeight: Double?

        for representation in item.representations {
            let blobID = UUID().uuidString
            blobs[blobID] = representation.data
            storedRepresentations.append(ClipboardStoredRepresentation(
                type: representation.type,
                blobID: blobID,
                byteCount: representation.data.count
            ))

            if imageBlobID == nil, ClipboardPasteboardTypeClassifier.isImage(representation.type), !representation.data.isEmpty {
                imageBlobID = blobID
                if let image = NSImage(data: representation.data) {
                    imagePixelWidth = Double(image.size.width)
                    imagePixelHeight = Double(image.size.height)
                }
            }
        }

        let parsedContent = parsedContent(
            from: item.representations,
            markerTypes: item.markerTypes
        )
        if
            parsedContent.kind == .image,
            imageBlobID == nil,
            let fileImageRepresentation = imageRepresentationFromFileValue(
                in: item.representations,
                markerTypes: item.markerTypes
            )
        {
            let blobID = UUID().uuidString
            blobs[blobID] = fileImageRepresentation.data
            storedRepresentations.append(ClipboardStoredRepresentation(
                type: fileImageRepresentation.type,
                blobID: blobID,
                byteCount: fileImageRepresentation.data.count
            ))
            imageBlobID = blobID
            if let image = NSImage(data: fileImageRepresentation.data) {
                imagePixelWidth = Double(image.size.width)
                imagePixelHeight = Double(image.size.height)
            }
        }

        return ClipboardHistoryItem(
            id: UUID(),
            kind: parsedContent.kind,
            displayText: parsedContent.displayText,
            searchableText: parsedContent.searchableText,
            markerTypes: item.markerTypes,
            representations: storedRepresentations,
            imageBlobID: imageBlobID,
            imagePixelWidth: imagePixelWidth,
            imagePixelHeight: imagePixelHeight
        )
    }

    private static func parsedContent(
        from representations: [ClipboardCapturedRepresentation],
        markerTypes: [String]
    ) -> (kind: ClipboardContentKind, displayText: String, searchableText: String) {
        let textualSearchText = textualSearchText(from: representations)
        let containsImageRepresentation = representations.contains {
            ClipboardPasteboardTypeClassifier.isImage($0.type) && !$0.data.isEmpty
        }

        if let value = fileValue(in: representations) {
            let display = fileDisplayText(from: value)
            if shouldClassifyFileValueAsImage(
                value,
                markerTypes: markerTypes
            ) {
                return (.image, "Image", searchText(primary: display, fallback: textualSearchText))
            }

            return (.file, display, searchText(primary: display, fallback: textualSearchText))
        }

        if containsImageRepresentation {
            return (.image, "Image", textualSearchText)
        }

        if let value = urlValue(in: representations) {
            return (.url, value, searchText(primary: value, fallback: textualSearchText))
        }

        if let value = standalonePlainTextLinkValue(in: representations) {
            return (.url, value, searchText(primary: value, fallback: textualSearchText))
        }

        if let value = stringValue(for: ClipboardPasteboardTypeClassifier.plainTextTypes, in: representations) {
            return (.text, value, searchText(primary: value, fallback: textualSearchText))
        }

        if let value = attributedStringValue(in: representations) {
            return (.text, value, searchText(primary: value, fallback: textualSearchText))
        }

        let typeSummary = representations.map(\.type).joined(separator: ", ")
        return (.data, typeSummary, searchText(primary: textualSearchText, fallback: typeSummary))
    }

    private static func textualSearchText(from representations: [ClipboardCapturedRepresentation]) -> String {
        var values: [String] = []

        if let fileValue = fileValue(in: representations) {
            values.append(fileDisplayText(from: fileValue))
        }

        values.append(contentsOf: stringValues(for: ClipboardPasteboardTypeClassifier.urlTypes, in: representations))
        values.append(contentsOf: stringValues(for: ClipboardPasteboardTypeClassifier.plainTextTypes, in: representations))
        values.append(contentsOf: attributedStringValues(in: representations))

        return uniqueJoinedText(values)
    }

    private static func searchText(primary: String, fallback: String) -> String {
        uniqueJoinedText([primary, fallback])
    }

    private static func uniqueJoinedText(_ values: [String]) -> String {
        var seen: Set<String> = []
        var uniqueValues: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else {
                continue
            }

            uniqueValues.append(trimmed)
        }

        return uniqueValues.joined(separator: "\n")
    }

    private static func stringValues(
        for acceptedTypes: Set<String>,
        in representations: [ClipboardCapturedRepresentation]
    ) -> [String] {
        representations.compactMap { representation in
            guard acceptedTypes.contains(representation.type) else {
                return nil
            }

            return decodedString(from: representation.data)
        }
    }

    private static func stringValue(
        for acceptedTypes: Set<String>,
        in representations: [ClipboardCapturedRepresentation]
    ) -> String? {
        stringValues(for: acceptedTypes, in: representations).first
    }

    private static func urlValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        stringValue(for: ClipboardPasteboardTypeClassifier.urlTypes, in: representations)
    }

    private static func attributedStringValues(in representations: [ClipboardCapturedRepresentation]) -> [String] {
        representations.compactMap { representation in
            if ClipboardPasteboardTypeClassifier.isHTML(representation.type) {
                return attributedStringValue(from: representation.data, documentType: .html)
            }

            if ClipboardPasteboardTypeClassifier.isRichText(representation.type) {
                return attributedStringValue(from: representation.data, documentType: .rtf)
            }

            return nil
        }
    }

    private static func attributedStringValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        attributedStringValues(in: representations).first
    }

    private static func attributedStringValue(
        from data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> String? {
        guard
            let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: documentType],
                documentAttributes: nil
            )
        else {
            return decodedString(from: data)
        }

        let string = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }

    private static func decodedString(from data: Data) -> String? {
        if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            return string
        }

        if let string = String(data: data, encoding: .utf16)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            return string
        }

        return nil
    }

    private static func fileValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        if let value = stringValue(for: ["public.file-url"], in: representations) {
            return value
        }

        for representation in representations where representation.type == "NSFilenamesPboardType" {
            if
                let paths = try? PropertyListSerialization.propertyList(
                    from: representation.data,
                    options: [],
                    format: nil
                ) as? [String],
                !paths.isEmpty
            {
                return paths.joined(separator: "\n")
            }
        }

        if let value = stringValue(for: ["NSFilenamesPboardType"], in: representations) {
            return value
        }

        if
            let value = urlValue(in: representations),
            let url = URL(string: value),
            url.isFileURL
        {
            return value
        }

        if let value = standalonePlainTextFileURLValue(in: representations) {
            return value
        }

        return nil
    }

    private static func standalonePlainTextFileURLValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        guard let value = plainTextValue(in: representations) else {
            return nil
        }

        return standaloneDetectedFileURLValue(value)
    }

    private static func standalonePlainTextLinkValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        guard let value = plainTextValue(in: representations) else {
            return nil
        }

        return standaloneClassifiableLinkValue(value)
    }

    private static func standaloneClassifiableLinkValue(_ value: String) -> String? {
        guard
            let detectedLink = standaloneDetectedLink(in: value),
            let scheme = detectedLink.url.scheme?.lowercased(),
            classifiableLinkSchemes.contains(scheme)
        else {
            return nil
        }

        return detectedLink.displayText
    }

    private static func standaloneDetectedFileURLValue(_ value: String) -> String? {
        guard
            let detectedLink = standaloneDetectedLink(in: value),
            detectedLink.url.isFileURL
        else {
            return nil
        }

        return detectedLink.displayText
    }

    private static func standaloneDetectedLink(in value: String) -> (displayText: String, url: URL)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let linkDetector else {
            return nil
        }

        let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matches = linkDetector.matches(in: trimmed, options: [], range: fullRange)
        guard
            matches.count == 1,
            let match = matches.first,
            match.range == fullRange,
            match.resultType == .link,
            let url = match.url
        else {
            return nil
        }

        return (trimmed, url)
    }

    private static func plainTextValue(in representations: [ClipboardCapturedRepresentation]) -> String? {
        return stringValue(
            for: ClipboardPasteboardTypeClassifier.plainTextTypes,
            in: representations.filter { !ClipboardMarkerClassifier.isMarker($0.type) }
        )
    }

    private static func storedItemHasPlainTextContent(_ item: ClipboardHistoryItem) -> Bool {
        item.representations.contains { representation in
            ClipboardPasteboardTypeClassifier.isText(representation.type)
        }
    }

    private static func fileDisplayText(from value: String) -> String {
        if let url = URL(string: value), url.isFileURL {
            return url.path
        }

        return value
    }

    private static func shouldClassifyFileValueAsImage(
        _ value: String,
        markerTypes: [String]
    ) -> Bool {
        let paths = fileDisplayPaths(from: value)
        guard !paths.isEmpty, paths.allSatisfy(ClipboardPasteboardTypeClassifier.isImageFilePath) else {
            return false
        }

        return markerTypes.contains(where: ClipboardMarkerClassifier.isRemoteClipboard)
    }

    private static func imageRepresentationFromFileValue(
        in representations: [ClipboardCapturedRepresentation],
        markerTypes: [String]
    ) -> ClipboardCapturedRepresentation? {
        guard
            markerTypes.contains(where: ClipboardMarkerClassifier.isRemoteClipboard),
            let value = fileValue(in: representations)
        else {
            return nil
        }

        return imageRepresentationFromFilePaths(fileDisplayPaths(from: value))
    }

    private static func imageRepresentationFromFilePaths(_ paths: [String]) -> ClipboardCapturedRepresentation? {
        guard
            paths.count == 1,
            let path = paths.first,
            ClipboardPasteboardTypeClassifier.isImageFilePath(path),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else {
            return nil
        }

        return ClipboardCapturedRepresentation(
            type: ClipboardPasteboardTypeClassifier.imageType(forFilePath: path),
            data: data
        )
    }

    private static func fileDisplayPaths(from value: String) -> [String] {
        value
            .components(separatedBy: .newlines)
            .compactMap { rawValue in
                let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }

                if let url = URL(string: trimmed), url.isFileURL {
                    return url.path
                }

                return trimmed
            }
    }

    private static func entryKind(for items: [ClipboardHistoryItem]) -> ClipboardContentKind {
        let kinds = Set(items.map(\.kind))
        guard kinds.count == 1, let kind = kinds.first else {
            return .mixed
        }

        return kind
    }

    private static func entrySearchableText(
        items: [ClipboardHistoryItem],
        markerTypes: [String],
        declaredSource: ClipboardApplicationSource?,
        inferredSource: ClipboardApplicationSource?
    ) -> String {
        (
            items.map(\.searchableText)
                + markerTypes
                + [
                    declaredSource?.displayName,
                    declaredSource?.bundleIdentifier,
                    declaredSource?.bundlePath,
                    inferredSource?.displayName,
                    inferredSource?.bundleIdentifier,
                    inferredSource?.bundlePath,
                ].compactMap { $0 }
        )
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private static func effectiveInferredSource(
        inferredSource: ClipboardApplicationSource?,
        markerTypes: [String]
    ) -> ClipboardApplicationSource? {
        if markerTypes.contains(where: ClipboardMarkerClassifier.isRemoteClipboard) {
            return nil
        }

        return inferredSource
    }

    private static func fallbackDisplayText(for kind: ClipboardContentKind) -> String {
        switch kind {
        case .text:
            "Text"
        case .url:
            "Link"
        case .file:
            "File"
        case .image:
            "Image"
        case .mixed:
            "Mixed content"
        case .data:
            "Clipboard data"
        }
    }

    private static func fingerprint(for items: [ClipboardCapturedItem]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037

        func append(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        for item in items {
            for marker in item.markerTypes.sorted() {
                marker.utf8.forEach(append)
            }

            for representation in item.representations.sorted(by: { $0.type < $1.type }) {
                representation.type.utf8.forEach(append)
                String(representation.data.count).utf8.forEach(append)
                representation.data.prefix(4096).forEach(append)
            }
        }

        return String(hash, radix: 16)
    }

    private static func loadRetentionLimit(from userDefaults: UserDefaults) -> Int {
        let value = userDefaults.integer(forKey: retentionLimitKey)
        return retentionLimitOptions.contains(value) ? value : unlimitedRetentionLimit
    }

    private static func loadRetentionDays(from userDefaults: UserDefaults) -> Int {
        guard userDefaults.object(forKey: retentionDaysKey) != nil else {
            return 30
        }

        let value = userDefaults.integer(forKey: retentionDaysKey)
        return retentionDayOptions.contains(value) ? value : 30
    }

    private func isRemoteClipboardMarker(_ markerType: String) -> Bool {
        ClipboardMarkerClassifier.isRemoteClipboard(markerType)
    }

    private func clearPasteCommandIssue() {
        guard case .pasteCommandDenied = accessIssue else {
            return
        }

        accessIssue = nil
    }
}
