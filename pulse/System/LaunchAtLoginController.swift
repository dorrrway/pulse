import Foundation
import ServiceManagement

nonisolated enum PulseLoginItemStatus: Sendable, Equatable {
    case enabled
    case notRegistered
    case notFound
    case requiresApproval
    case unknown
}

nonisolated enum PulseLoginItemError: Error, Equatable {
    case requiresInstalledApplication
    case serviceError(String)
}

struct PulseLoginItemService {
    var currentStatus: @MainActor () -> PulseLoginItemStatus
    var apply: @MainActor (_ enabled: Bool) throws -> PulseLoginItemStatus

    nonisolated static let live = PulseLoginItemService(
        currentStatus: {
            LaunchAtLoginController.status
        },
        apply: { enabled in
            try LaunchAtLoginController.apply(enabled: enabled)
        }
    )
}

@MainActor
enum LaunchAtLoginController {
    static var status: PulseLoginItemStatus {
        status(for: SMAppService.mainApp.status)
    }

    @discardableResult
    static func apply(enabled: Bool) throws -> PulseLoginItemStatus {
        guard isRunningFromStableApplicationLocation || !enabled else {
            throw PulseLoginItemError.requiresInstalledApplication
        }

        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled && service.status != .requiresApproval {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }

        return status(for: service.status)
    }

    private static func status(for status: SMAppService.Status) -> PulseLoginItemStatus {
        switch status {
        case .enabled:
            .enabled
        case .notRegistered:
            .notRegistered
        case .notFound:
            .notFound
        case .requiresApproval:
            .requiresApproval
        @unknown default:
            .unknown
        }
    }

    private static var isRunningFromStableApplicationLocation: Bool {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        let homeApplicationsPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .path

        return bundlePath.hasPrefix("/Applications/")
            || bundlePath.hasPrefix(homeApplicationsPath + "/")
    }
}
