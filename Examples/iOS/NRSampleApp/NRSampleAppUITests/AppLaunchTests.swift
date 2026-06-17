import XCTest

final class AppLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Smoke test: app launches and the scenario menu appears.
    /// Accepts either the empty state (no scenarios bundled) OR a populated
    /// list (when scenario manifests are present in the app bundle).
    func test_appLaunches_showsMenu() {
        let app = XCUIApplication()
        app.launchEnvironment = ["NEW_RELIC_APP_TOKEN": "TEST_TOKEN_SAMPLE"]
        app.launch()

        let emptyState = app.otherElements["scenario.menu.empty"]
        let basicVODRow = app.otherElements["scenario.menu.row.basic-vod"]

        let menuVisible = emptyState.waitForExistence(timeout: 5)
            || basicVODRow.waitForExistence(timeout: 5)

        XCTAssertTrue(menuVisible, "Expected menu (empty or populated) to appear.")
    }
}
