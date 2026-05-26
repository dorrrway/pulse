import Foundation

@MainActor
final class ClipboardHistoryController {
    private static let defaultPollingInterval: Duration = .milliseconds(500)

    private let client: ClipboardPasteboardClient
    private let sourceProvider: @MainActor () -> ClipboardApplicationSource?
    private let pollingInterval: Duration
    private var task: Task<Void, Never>?
    private var lastChangeCount: Int?

    init(
        client: ClipboardPasteboardClient,
        pollingInterval: Duration = ClipboardHistoryController.defaultPollingInterval,
        sourceProvider: @escaping @MainActor () -> ClipboardApplicationSource? = {
            AppKitClipboardPasteboardClient.frontmostApplicationSource()
        }
    ) {
        self.client = client
        self.pollingInterval = pollingInterval
        self.sourceProvider = sourceProvider
    }

    func start(
        accessChanged: @escaping @MainActor (ClipboardPasteboardAccessBehavior) -> Void,
        captured: @escaping @MainActor (ClipboardPasteboardSnapshot) -> Void,
        failed: @escaping @MainActor (ClipboardHistoryAccessIssue) -> Void
    ) {
        guard task == nil else {
            return
        }

        lastChangeCount = client.changeCount
        accessChanged(client.accessBehavior)

        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.poll(
                    accessChanged: accessChanged,
                    captured: captured,
                    failed: failed
                )

                do {
                    try await Task.sleep(for: self?.pollingInterval ?? Self.defaultPollingInterval)
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func poll(
        accessChanged: @MainActor (ClipboardPasteboardAccessBehavior) -> Void,
        captured: @MainActor (ClipboardPasteboardSnapshot) -> Void,
        failed: @MainActor (ClipboardHistoryAccessIssue) -> Void
    ) {
        accessChanged(client.accessBehavior)

        let currentChangeCount = client.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount

        do {
            let snapshot = try client.readSnapshot(
                capturedAt: Date(),
                inferredSource: sourceProvider()
            )
            captured(snapshot)
        } catch ClipboardPasteboardError.readDenied(let behavior) {
            failed(.readDenied(behavior))
        } catch {
            failed(.readFailed(error.localizedDescription))
        }
    }
}
