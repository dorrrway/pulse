import XCTest
@testable import pulse

@MainActor
final class PinnedPanelControllerTests: XCTestCase {
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

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "pulse.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeLoginItemService() -> PulseLoginItemService {
        PulseLoginItemService(
            currentStatus: { .enabled },
            apply: { enabled in enabled ? .enabled : .notRegistered }
        )
    }
}
