import XCTest
@testable import pulse

final class AppInstanceLockTests: XCTestCase {
    func testSecondProcessLockForSameIdentifierCannotAcquireUntilFirstReleases() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-lock-tests-\(UUID().uuidString)", isDirectory: true)
        let identifier = "com.timelikesilver.pulse.tests.\(UUID().uuidString)"
        let lock = AppInstanceLock(identifier: identifier, directoryURL: directory)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
        process.arguments = ["-k", lock.lockURL.path, "/bin/sleep", "5"]
        try process.run()

        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            try? FileManager.default.removeItem(at: directory)
        }

        XCTAssertTrue(waitUntilLockIsHeld(identifier: identifier, directoryURL: directory))

        process.terminate()
        process.waitUntilExit()

        let lockAfterRelease = AppInstanceLock(identifier: identifier, directoryURL: directory)
        XCTAssertTrue(lockAfterRelease.acquire())
    }

    func testDefaultLockIsOutsideTemporaryDirectory() {
        let lock = AppInstanceLock(identifier: "com.timelikesilver.pulse.tests.\(UUID().uuidString)")

        XCTAssertFalse(lock.lockURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    }

    private func waitUntilLockIsHeld(identifier: String, directoryURL: URL) -> Bool {
        for _ in 0..<50 {
            let probe = AppInstanceLock(identifier: identifier, directoryURL: directoryURL)

            if !probe.acquire() {
                return true
            }

            Thread.sleep(forTimeInterval: 0.05)
        }

        return false
    }
}
