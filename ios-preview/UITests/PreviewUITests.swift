import XCTest

final class PreviewUITests: XCTestCase {
    @MainActor
    func testReferenceUIJourney() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-vo1d.preview.autoLogin",
            "-vo1d.autoconnect", "NO",
            "-vo1d.autoFastest", "YES",
            "-vo1d.reduceAnimations", "YES"
        ]
        app.launch()

        capture("01-launch", app: app)

        let connection = app.buttons["connection.control"]
        XCTAssertTrue(connection.waitForExistence(timeout: 8))
        capture("02-home-ready", app: app)

        connection.tap()

        let connected = NSPredicate(format: "value == %@", "CONNECTED")
        expectation(for: connected, evaluatedWith: connection)
        waitForExpectations(timeout: 5)
        capture("03-home-connected", app: app)

        app.buttons["tab.locations"].tap()
        let search = app.textFields["servers.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 4))
        capture("04-locations", app: app)

        search.tap()
        search.typeText("Russia")

        let russia = app.buttons["server.RU"]
        XCTAssertTrue(russia.waitForExistence(timeout: 3))
        russia.tap()
        Thread.sleep(forTimeInterval: 0.35)
        capture("05-route-switch", app: app)

        app.buttons["tab.stats"].tap()
        XCTAssertTrue(
            app.scrollViews["stats.screen"].waitForExistence(timeout: 4)
        )
        capture("06-stats", app: app)

        app.buttons["tab.profile"].tap()
        let nickname = app.textFields["profile.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 4))
        capture("07-profile", app: app)

        let settings = app.buttons["profile.settings"]
        if !settings.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.tap()

        XCTAssertTrue(
            app.scrollViews["settings.screen"].waitForExistence(timeout: 5)
        )
        capture("08-settings", app: app)

        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()

        let logout = app.buttons["profile.logout"]
        if !logout.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(logout.waitForExistence(timeout: 3))
        logout.tap()

        Thread.sleep(forTimeInterval: 0.25)
        let logoutButtons = app.buttons.matching(identifier: "Log Out")
        XCTAssertGreaterThan(logoutButtons.count, 0)
        logoutButtons.element(boundBy: logoutButtons.count - 1).tap()

        XCTAssertTrue(
            app.scrollViews["login.screen"].waitForExistence(timeout: 5)
        )
        capture("09-plans", app: app)

        let keyField = app.textFields["login.key"]
        if !keyField.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(keyField.waitForExistence(timeout: 4))
        keyField.tap()
        keyField.typeText("W8AUVYWVDM6A")

        let activate = app.buttons["login.activate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 3))
        XCTAssertTrue(activate.isEnabled)
        activate.tap()

        let accepted = app.otherElements["activation.success"]
        XCTAssertTrue(accepted.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.65)
        capture("10-key-accepted", app: app)

        expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: accepted
        )
        waitForExpectations(timeout: 5)

        XCTAssertTrue(connection.waitForExistence(timeout: 5))
        capture("11-home-after-activation", app: app)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
