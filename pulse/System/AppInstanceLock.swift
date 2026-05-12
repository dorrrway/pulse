import Darwin
import Foundation

nonisolated final class AppInstanceLock {
    let lockURL: URL

    private var fileDescriptor: CInt = -1
    private var didAcquireLock = false

    init(identifier: String, directoryURL: URL = AppInstanceLock.defaultDirectoryURL()) {
        let lockName = identifier
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        self.lockURL = directoryURL.appendingPathComponent("\(lockName).lock", isDirectory: false)
    }

    func acquire() -> Bool {
        guard fileDescriptor < 0 else {
            return didAcquireLock
        }

        do {
            try FileManager.default.createDirectory(
                at: lockURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return false
        }

        fileDescriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

        guard fileDescriptor >= 0 else {
            return false
        }

        guard Darwin.lockf(fileDescriptor, F_TLOCK, 0) == 0 else {
            return false
        }

        didAcquireLock = true
        return true
    }

    deinit {
        guard fileDescriptor >= 0 else {
            return
        }

        if didAcquireLock {
            Darwin.lockf(fileDescriptor, F_ULOCK, 0)
        }

        Darwin.close(fileDescriptor)
    }

    private static func defaultDirectoryURL() -> URL {
        let applicationSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        return applicationSupportDirectory
            .appendingPathComponent("Pulse", isDirectory: true)
            .appendingPathComponent("InstanceLock", isDirectory: true)
    }
}
