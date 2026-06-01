import Foundation
import XCTest
@testable import pulse

@MainActor
final class MemoStoreTests: XCTestCase {
    func testCreatesNotesAndTasksThenFiltersAndSearches() throws {
        let store = makeStore()

        XCTAssertTrue(store.addEntry(kind: .note, text: "Sketch memo panel"))
        XCTAssertTrue(store.addEntry(kind: .task, text: "Ship local todo support"))

        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.activeTaskCount, 1)
        XCTAssertEqual(store.completedTaskCount, 0)

        store.selectedFilter = .todo
        XCTAssertEqual(store.filteredEntries.map(\.text), ["Ship local todo support"])

        store.selectedFilter = .notes
        XCTAssertEqual(store.filteredEntries.map(\.text), ["Sketch memo panel"])

        store.selectedFilter = .all
        store.searchText = "todo"
        XCTAssertEqual(store.filteredEntries.map(\.text), ["Ship local todo support"])
    }

    func testCompletionAndClearCompletedTasks() throws {
        let store = makeStore()
        store.addEntry(kind: .task, text: "First")
        store.addEntry(kind: .task, text: "Second")
        let first = try XCTUnwrap(store.entries.first(where: { $0.text == "First" }))

        store.toggleCompletion(first)

        XCTAssertEqual(store.activeTaskCount, 1)
        XCTAssertEqual(store.completedTaskCount, 1)
        store.selectedFilter = .completed
        XCTAssertEqual(store.filteredEntries.map(\.text), ["First"])

        store.clearCompletedTasks()

        XCTAssertEqual(store.entries.map(\.text), ["Second"])
        XCTAssertEqual(store.completedTaskCount, 0)
    }

    func testPinningSortsPinnedEntriesFirst() throws {
        let store = makeStore()
        store.addEntry(kind: .note, text: "Unpinned")
        store.addEntry(kind: .task, text: "Pinned")
        let pinned = try XCTUnwrap(store.entries.first(where: { $0.text == "Pinned" }))

        store.togglePin(pinned)

        XCTAssertEqual(store.filteredEntries.first?.text, "Pinned")
        XCTAssertTrue(try XCTUnwrap(store.filteredEntries.first).isPinned)
    }

    func testUpdatesAndDeletesEntries() throws {
        let store = makeStore()
        store.addEntry(kind: .note, text: "Draft")
        let entry = try XCTUnwrap(store.entries.first)

        XCTAssertTrue(store.update(entry, text: "Final"))
        XCTAssertEqual(store.entries.first?.text, "Final")

        store.delete(try XCTUnwrap(store.entries.first))

        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.selectedFilter, .all)
        XCTAssertEqual(store.searchText, "")
    }

    func testPersistsEntriesAcrossStores() throws {
        let rootURL = temporaryRootURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let persistence = MemoPersistence(rootURL: rootURL)
        let store = MemoStore(persistence: persistence)
        store.addEntry(kind: .task, text: "Persist me")
        let entry = try XCTUnwrap(store.entries.first)
        store.toggleCompletion(entry)

        let reloadedStore = MemoStore(persistence: MemoPersistence(rootURL: rootURL))

        XCTAssertEqual(reloadedStore.entries.count, 1)
        XCTAssertEqual(reloadedStore.entries.first?.text, "Persist me")
        XCTAssertEqual(reloadedStore.entries.first?.kind, .task)
        XCTAssertEqual(reloadedStore.entries.first?.isCompleted, true)
    }

    private func makeStore() -> MemoStore {
        let rootURL = temporaryRootURL()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: rootURL)
        }
        return MemoStore(persistence: MemoPersistence(rootURL: rootURL))
    }

    private func temporaryRootURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("pulse-memo-tests-\(UUID().uuidString)", isDirectory: true)
    }
}
