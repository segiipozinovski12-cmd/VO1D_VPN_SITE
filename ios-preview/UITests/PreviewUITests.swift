import XCTest

final class PreviewUITests: XCTestCase {
    @MainActor
    func testFullDemoJourney() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-vo1d.autoconnect", "NO", "-vo1d.autoFastest", "YES", "-vo1d.reduceAnimations", "NO"]
        app.launch()
        capture("01-launch", app: app)
        let control = app.buttons["connection.control"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        XCTAssertTrue(control.isHittable)
        capture("02-home", app: app)
        control.tap()
        XCTAssertTrue(app.staticTexts["connection.status"].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.35)
        capture("03-connecting", app: app)
        let connected = NSPredicate(format: "value == %@", "CONNECTED")
        expectation(for: connected, evaluatedWith: control)
        waitForExpectations(timeout: 5)
        capture("04-connected", app: app)
        app.swipeUp()
        capture("05-dashboard", app: app)
        app.buttons["tab.locations"].tap()
        let search = app.textFields["servers.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        capture("06-locations", app: app)
        search.tap(); search.typeText("Russia")
        app.buttons["favorite.RU"].tap()
        app.buttons["server.RU"].tap()
        capture("07-switching", app: app)
        app.buttons["tab.home"].tap()
        expectation(for: connected, evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 5)
        app.buttons["connection.control"].tap()
        expectation(for: NSPredicate(format: "value == %@", "READY"), evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 4)
        let pingRefresh = app.buttons["quick.ping"]
        XCTAssertTrue(pingRefresh.waitForExistence(timeout: 3))
        XCTAssertTrue(pingRefresh.isHittable)
        pingRefresh.tap()

        // Accessibility updates can trail the 240 ms demo measurement on CI.
        let pingFinished = NSPredicate(format: "value == %@", "MEASURE")
        expectation(for: pingFinished, evaluatedWith: pingRefresh)
        waitForExpectations(timeout: 3)

        let fastest = app.buttons["quick.fastest"]
        XCTAssertTrue(fastest.waitForExistence(timeout: 3))
        XCTAssertTrue(fastest.isHittable)
        fastest.tap()

        expectation(for: connected, evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 5)
        app.buttons["tab.locations"].tap()
        app.buttons["filter.FAVORITES"].tap()
        XCTAssertTrue(app.buttons["server.RU"].exists)
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.textFields["profile.nickname"].waitForExistence(timeout: 3))
        capture("08-profile", app: app)
        app.buttons["profile.avatar"].tap()
        let avatarChoice = app.buttons["avatar.moon.stars.fill"]
        XCTAssertTrue(avatarChoice.waitForExistence(timeout: 3))
        avatarChoice.tap()
        let avatarDismissed = NSPredicate(format: "exists == false")
        expectation(for: avatarDismissed, evaluatedWith: avatarChoice)
        waitForExpectations(timeout: 3)

        let settings = app.buttons["profile.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        if !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        capture("09-settings-attempt", app: app)

        let settingsBack = app.buttons["Back"]
        XCTAssertTrue(settingsBack.waitForExistence(timeout: 5))

        let autoConnect = app.descendants(matching: .any)["settings.autoConnect"]
        XCTAssertTrue(autoConnect.waitForExistence(timeout: 3))

        capture("09-settings", app: app)

        if autoConnect.isHittable {
            autoConnect.tap()
        }
        app.swipeUp()
        let switches = app.switches
        if switches.count > 0 {
            let last = switches.element(boundBy: switches.count - 1)
            if last.isHittable { last.tap() }
        }
        capture("10-interface", app: app)
    }
    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
