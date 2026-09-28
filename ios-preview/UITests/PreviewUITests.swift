import XCTest

final class PreviewUITests: XCTestCase {
    @MainActor
    func testReferenceDemoJourney() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-vo1d.autoconnect", "NO",
            "-vo1d.autoFastest", "YES",
            "-vo1d.reduceAnimations", "YES"
        ]
        app.launch()

        capture("01-launch", app: app)

        let control = app.buttons["connection.control"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        XCTAssertTrue(control.isHittable)

        capture("02-reference-home", app: app)

        control.tap()

        let connected = NSPredicate(
            format: "value == %@",
            "CONNECTED"
        )
        expectation(
            for: connected,
            evaluatedWith: control
        )
        waitForExpectations(timeout: 6)

        capture("03-reference-connected", app: app)

        app.buttons["tab.locations"].tap()

        let search = app.textFields["servers.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))

        capture("04-reference-locations", app: app)

        search.tap()
        search.typeText("Russia")

        let favorite = app.buttons["favorite.RU"]
        if favorite.waitForExistence(timeout: 2) {
            favorite.tap()
        }

        let russia = app.buttons["server.RU"]
        XCTAssertTrue(russia.waitForExistence(timeout: 3))
        russia.tap()

        capture("05-reference-switching", app: app)

        app.buttons["tab.home"].tap()

        expectation(
            for: connected,
            evaluatedWith: app.buttons["connection.control"]
        )
        waitForExpectations(timeout: 6)

        capture("06-reference-route-connected", app: app)

        app.buttons["tab.stats"].tap()
        capture("07-reference-stats", app: app)

        app.buttons["tab.profile"].tap()

        let nickname = app.textFields["profile.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 3))

        capture("08-reference-profile", app: app)

        let settings = app.buttons["profile.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))

        if !settings.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(settings.isHittable)
        settings.tap()

        let autoConnect = app.descendants(matching: .any)["settings.autoConnect"]
        XCTAssertTrue(autoConnect.waitForExistence(timeout: 5))

        capture("09-reference-settings", app: app)
    }

    @MainActor
    private func capture(
        _ name: String,
        app: XCUIApplication
    ) {
        let image = XCTAttachment(
            screenshot: app.screenshot()
        )
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
