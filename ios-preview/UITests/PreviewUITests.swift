import XCTest

final class PreviewUITests: XCTestCase {
    @MainActor
    func testReferenceDemoJourney() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-vo1d.autoconnect", "NO",
            "-vo1d.autoFastest", "YES",
            "-vo1d.reduceAnimations", "NO"
        ]
        app.launch()

        capture("01-launch", app: app)

        let control = app.buttons["connection.control"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        XCTAssertTrue(control.isHittable)

        capture("02-reference-home", app: app)

        control.tap()

        let connected = NSPredicate(format: "value == %@", "CONNECTED")
        expectation(for: connected, evaluatedWith: control)
        waitForExpectations(timeout: 6)

        XCTAssertTrue(
            app.staticTexts["connection.status"]
                .waitForExistence(timeout: 2)
        )

        capture("03-reference-connected", app: app)

        app.buttons["tab.locations"].tap()

        let search = app.textFields["servers.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 4))

        capture("04-reference-locations", app: app)

        search.tap()
        search.typeText("Russia")

        let favorite = app.buttons["favorite.RU"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 3))
        favorite.tap()

        let russia = app.buttons["server.RU"]
        XCTAssertTrue(russia.waitForExistence(timeout: 3))
        russia.tap()

        app.buttons["tab.stats"].tap()

        XCTAssertTrue(
            app.otherElements["stats.screen"]
                .waitForExistence(timeout: 4)
        )

        capture("05-reference-stats", app: app)

        app.buttons["tab.home"].tap()

        let homeControl = app.buttons["connection.control"]
        XCTAssertTrue(homeControl.waitForExistence(timeout: 4))

        expectation(for: connected, evaluatedWith: homeControl)
        waitForExpectations(timeout: 6)

        app.buttons["tab.profile"].tap()

        XCTAssertTrue(
            app.textFields["profile.nickname"]
                .waitForExistence(timeout: 4)
        )

        capture("06-reference-profile", app: app)

        let settings = app.buttons["profile.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 4))

        if !settings.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(settings.isHittable)
        settings.tap()

        let autoConnect = app.descendants(matching: .any)["settings.autoConnect"]
        XCTAssertTrue(autoConnect.waitForExistence(timeout: 5))

        capture("07-reference-settings", app: app)

        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()

        XCTAssertTrue(
            app.textFields["profile.nickname"]
                .waitForExistence(timeout: 4)
        )
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
