import XCTest
@testable import pulse

final class PinnedPanelControllerTests: XCTestCase {
    @MainActor
    func testPinnedPanelReceivesUpdateControllerEnvironment() {
        let controller = PulsePinnedPanelController()
        let store = PulseStore(
            userDefaults: makeUserDefaults(),
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        let updateController = PulseUpdateController(startingUpdater: false)

        controller.present(store: store, updateController: updateController)
        defer {
            controller.dismiss()
        }

        XCTAssertTrue(controller.isPresented)
    }

    @MainActor
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "pulse.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    private func makeLoginItemService() -> PulseLoginItemService {
        PulseLoginItemService(
            currentStatus: { .enabled },
            apply: { enabled in enabled ? .enabled : .notRegistered }
        )
    }
}
