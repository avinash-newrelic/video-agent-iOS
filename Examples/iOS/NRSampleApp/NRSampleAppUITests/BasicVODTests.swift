import XCTest

final class BasicVODTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches directly into the basic-vod scenario, opens the event log,
    /// and asserts CONTENT_REQUEST and CONTENT_START fire.
    func test_basicVOD_emitsContentRequestAndStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--scenario", "basic-vod"]
        // Token doesn't need to be valid — NRVA initializes fine; tests don't
        // assert NRQL ingestion here. CI sets a real token if it wants
        // separate ingestion-level validation as a follow-up step.
        app.launchEnvironment = ["NEW_RELIC_APP_TOKEN": "TEST_TOKEN_SAMPLE"]
        app.launch()

        // Open the event log overlay so its event labels become queryable.
        let overlay = app.otherElements["event-log-overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 10),
                      "Event log overlay never appeared.")
        app.buttons["event-log-handle"].tap()

        XCTAssertTrue(
            app.staticTexts["event.CONTENT_REQUEST"].waitForExistence(timeout: 15),
            "Expected CONTENT_REQUEST within 15s of launch."
        )
        XCTAssertTrue(
            app.staticTexts["event.CONTENT_START"].waitForExistence(timeout: 30),
            "Expected CONTENT_START within 30s of launch (after first frame)."
        )
    }
}
