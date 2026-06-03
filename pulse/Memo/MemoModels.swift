import Foundation

nonisolated enum MemoEntryKind: String, Codable, CaseIterable, Sendable {
    case note
    case task
}

nonisolated enum MemoEntryFilter: String, CaseIterable, Sendable {
    case all
    case notes
    case todo
    case completed
}

nonisolated struct MemoEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: MemoEntryKind
    var text: String
    var isCompleted: Bool
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: MemoEntryKind,
        text: String,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.isCompleted = kind == .task && isCompleted
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var isTask: Bool {
        kind == .task
    }

    func matches(searchText query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return text.localizedCaseInsensitiveContains(normalizedQuery)
    }

    func matches(filter: MemoEntryFilter) -> Bool {
        switch filter {
        case .all:
            true
        case .todo:
            kind == .task && !isCompleted
        case .notes:
            kind == .note
        case .completed:
            kind == .task && isCompleted
        }
    }
}
