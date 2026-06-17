import XCTest

final class AppLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Smoke test: the app launches and the menu's empty-state appears.
    /// Once scenarios are added, this test will need to be updated to look
    /// for the populated list instead of the empty state.
    func test_appLaunches_showsEmptyMenu() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.otherElements["scenario.menu.empty"].waitForExistence(timeout: 5),
            "Expected empty-state placeholder when no scenarios are bundled."
        )
    }
}
