import Foundation
import Observation

@MainActor
@Observable
final class MemoStore {
    var entries: [MemoEntry]
    var draftText = ""
    var searchText = ""
    var selectedFilter: MemoEntryFilter = .all
    var lastChangedEntryID: UUID?
    var persistenceIssue: String?

    @ObservationIgnored private let persistence: MemoPersistence

    init(persistence: MemoPersistence = MemoPersistence()) {
        self.persistence = persistence

        do {
            self.entries = Self.sorted(try persistence.loadEntries())
            self.persistenceIssue = nil
        } catch {
            self.entries = []
            self.persistenceIssue = error.localizedDescription
        }
    }

    var filteredEntries: [MemoEntry] {
        Self.sorted(entries).filter {
            $0.matches(filter: selectedFilter)
                && $0.matches(searchText: searchText)
        }
    }

    var activeTaskCount: Int {
        entries.filter { $0.kind == .task && !$0.isCompleted }.count
    }

    var completedTaskCount: Int {
        entries.filter { $0.kind == .task && $0.isCompleted }.count
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    @discardableResult
    func addNote() -> Bool {
        addEntry(kind: .note)
    }

    @discardableResult
    func addTask() -> Bool {
        addEntry(kind: .task)
    }

    @discardableResult
    func addEntry(kind: MemoEntryKind, text explicitText: String? = nil) -> Bool {
        let text = Self.normalizedText(explicitText ?? draftText)
        guard !text.isEmpty else {
            return false
        }

        let now = Date()
        let entry = MemoEntry(kind: kind, text: text, createdAt: now, updatedAt: now)
        entries.insert(entry, at: 0)
        draftText = ""
        lastChangedEntryID = entry.id
        sortEntriesInPlace()
        persistEntries()
        return true
    }

    @discardableResult
    func update(_ entry: MemoEntry, text rawText: String) -> Bool {
        let text = Self.normalizedText(rawText)
        guard !text.isEmpty else {
            return false
        }

        mutate(entry) { updatedEntry in
            updatedEntry.text = text
            updatedEntry.updatedAt = Date()
        }

        return true
    }

    func toggleCompletion(_ entry: MemoEntry) {
        guard entry.kind == .task else {
            return
        }

        mutate(entry) { updatedEntry in
            updatedEntry.isCompleted.toggle()
            updatedEntry.updatedAt = Date()
        }
    }

    func markAsTask(_ entry: MemoEntry) {
        guard entry.kind != .task else {
            return
        }

        mutate(entry) { updatedEntry in
            updatedEntry.kind = .task
            updatedEntry.isCompleted = false
            updatedEntry.updatedAt = Date()
        }
    }

    func togglePin(_ entry: MemoEntry) {
        mutate(entry) { updatedEntry in
            updatedEntry.isPinned.toggle()
            updatedEntry.updatedAt = Date()
        }
    }

    func delete(_ entry: MemoEntry) {
        entries.removeAll { $0.id == entry.id }
        lastChangedEntryID = entry.id

        if entries.isEmpty {
            searchText = ""
            selectedFilter = .all
        }

        persistEntries()
    }

    func clearCompletedTasks() {
        let completedIDs = Set(entries.filter { $0.kind == .task && $0.isCompleted }.map(\.id))
        guard !completedIDs.isEmpty else {
            return
        }

        entries.removeAll { completedIDs.contains($0.id) }
        persistEntries()
    }

    private func mutate(_ entry: MemoEntry, transform: (inout MemoEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        transform(&entries[index])
        lastChangedEntryID = entry.id
        sortEntriesInPlace()
        persistEntries()
    }

    private func sortEntriesInPlace() {
        entries = Self.sorted(entries)
    }

    private func persistEntries() {
        do {
            try persistence.save(entries: entries)
            persistenceIssue = nil
        } catch {
            persistenceIssue = error.localizedDescription
        }
    }

    private static func sorted(_ entries: [MemoEntry]) -> [MemoEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.createdAt > rhs.createdAt
        }
    }

    private static func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
