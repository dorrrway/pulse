import AppKit
import CoreGraphics
import Foundation

enum PulseScreenshotMode: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case fullScreen
    case window
    case selection

    var id: Self {
        self
    }

    var shortcutAction: PulseShortcutAction {
        switch self {
        case .fullScreen:
            .captureFullScreen
        case .window:
            .captureWindow
        case .selection:
            .captureSelection
        }
    }

    nonisolated var iconAssetName: String {
        switch self {
        case .fullScreen:
            "ScreenshotFullScreenIcon"
        case .window:
            "ScreenshotWindowIcon"
        case .selection:
            "ScreenshotSelectionIcon"
        }
    }
}

nonisolated enum PulseScreenshotCaptureResult: Equatable, Sendable {
    case copiedToClipboard
    case permissionDenied
    case cancelled
    case failed
}

struct PulseScreenshotService: Sendable {
    var preflightAccess: @Sendable () -> Bool
    var requestAccess: @Sendable () -> Bool
    var openScreenCaptureSettings: @MainActor @Sendable () -> Void
    var capture: @Sendable (PulseScreenshotMode) async -> PulseScreenshotCaptureResult

    static let live = PulseScreenshotService(
        preflightAccess: {
            CGPreflightScreenCaptureAccess()
        },
        requestAccess: {
            CGRequestScreenCaptureAccess()
        },
        openScreenCaptureSettings: {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
                return
            }

            NSWorkspace.shared.open(url)
        },
        capture: { mode in
            await runScreencapture(arguments: arguments(for: mode))
        }
    )

    nonisolated static func arguments(for mode: PulseScreenshotMode) -> [String] {
        switch mode {
        case .fullScreen:
            ["-c", "-i", "-w", "-S", "-x"]
        case .window:
            ["-c", "-i", "-w", "-o", "-x"]
        case .selection:
            ["-c", "-i", "-s", "-x"]
        }
    }

    nonisolated static func captureResult(
        exitCode: Int32,
        standardError: String
    ) -> PulseScreenshotCaptureResult {
        guard exitCode == 0 else {
            let normalizedError = standardError.lowercased()
            if normalizedError.contains("tcc")
                || normalizedError.contains("permission")
                || normalizedError.contains("not authorized")
                || normalizedError.contains("could not create image from display") {
                return .permissionDenied
            }

            return .cancelled
        }

        return .copiedToClipboard
    }

    private nonisolated static func runScreencapture(arguments: [String]) async -> PulseScreenshotCaptureResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.standardError = standardError

            do {
                try process.run()
                process.waitUntilExit()

                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                return captureResult(exitCode: process.terminationStatus, standardError: errorMessage)
            } catch {
                return .failed
            }
        }.value
    }
}
